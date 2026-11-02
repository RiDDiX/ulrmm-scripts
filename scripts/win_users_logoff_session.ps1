# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Logs off the sessions of one user or all user sessions. Unsaved work in those sessions is lost.
# Variables: TARGET_USER (an account name or ALL)
# Exit: 0 sessions logged off or none found, 1 a logoff failed, 3 bad input or session API unavailable
$ErrorActionPreference = 'Stop'
$target = ([string]$env:TARGET_USER).Trim()
if (-not $target -or $target -match '["/\[\]:;|=,+*?<>@]' -or $target -match '\$$') {
    Write-Output 'Bad or missing TARGET_USER (an account name or ALL)'
    exit 3
}
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class UlSession {
    public int Id; public string Station; public int State; public string User; public string Domain;
    public long LastInput; public long Current; public long Logon; public long Disconnect;
}
public static class UlWts {
    [StructLayout(LayoutKind.Sequential)]
    struct SessionInfo { public int SessionId; public IntPtr Station; public int State; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct WtsInfo {
        public int State; public int SessionId; public int InB; public int OutB; public int InF; public int OutF; public int InC; public int OutC;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string Station;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 17)] public string Domain;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 21)] public string User;
        public long Connect; public long Disconnect; public long LastInput; public long Logon; public long Current;
    }
    [DllImport("wtsapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool WTSEnumerateSessions(IntPtr h, int reserved, int version, out IntPtr p, out int count);
    [DllImport("wtsapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool WTSQuerySessionInformation(IntPtr h, int id, int cls, out IntPtr buf, out int len);
    [DllImport("wtsapi32.dll")]
    static extern void WTSFreeMemory(IntPtr p);
    [DllImport("wtsapi32.dll", SetLastError = true)]
    public static extern bool WTSLogoffSession(IntPtr h, int id, bool wait);
    public static List<UlSession> List() {
        List<UlSession> res = new List<UlSession>();
        IntPtr p; int count;
        if (!WTSEnumerateSessions(IntPtr.Zero, 0, 1, out p, out count)) { return res; }
        int size = Marshal.SizeOf(typeof(SessionInfo));
        for (int i = 0; i < count; i++) {
            SessionInfo si = (SessionInfo)Marshal.PtrToStructure(new IntPtr(p.ToInt64() + (long)i * size), typeof(SessionInfo));
            UlSession s = new UlSession();
            s.Id = si.SessionId; s.State = si.State; s.Station = Marshal.PtrToStringUni(si.Station);
            IntPtr buf; int len;
            if (WTSQuerySessionInformation(IntPtr.Zero, si.SessionId, 24, out buf, out len)) {
                WtsInfo wi = (WtsInfo)Marshal.PtrToStructure(buf, typeof(WtsInfo));
                s.User = wi.User; s.Domain = wi.Domain; s.LastInput = wi.LastInput; s.Current = wi.Current;
                s.Logon = wi.Logon; s.Disconnect = wi.Disconnect;
                WTSFreeMemory(buf);
            }
            res.Add(s);
        }
        WTSFreeMemory(p);
        return res;
    }
}
'@
try {
    $sessions = @([UlWts]::List() | Where-Object { $_.User })
} catch {
    Write-Output ('Cannot enumerate sessions: ' + $_.Exception.Message)
    exit 3
}
$all = $target -eq 'ALL'
$short = $target.Split('\')[-1]
$domain = if ($target.Contains('\')) { $target.Split('\')[0] } else { '' }
$hits = @($sessions | Where-Object { $all -or ($_.User -eq $short -and (-not $domain -or $_.Domain -eq $domain)) })
if ($hits.Count -eq 0) {
    Write-Output ('No matching session for ' + $target)
    exit 0
}
$failed = 0
foreach ($s in $hits) {
    if ([UlWts]::WTSLogoffSession([IntPtr]::Zero, $s.Id, $true)) {
        Write-Output ('Logged off session ' + $s.Id + ' (' + $s.Domain + '\' + $s.User + ')')
    } else {
        Write-Output ('FAIL: could not log off session ' + $s.Id + ' (' + $s.Domain + '\' + $s.User + ')')
        $failed++
    }
}
if ($failed -gt 0) { exit 1 }
exit 0
