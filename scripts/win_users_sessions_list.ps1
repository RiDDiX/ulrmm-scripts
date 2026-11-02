# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists logon sessions (console, remote desktop, disconnected) with user, state and idle time.
# Variables: none
# Exit: 0 listed (also when nobody is logged on), 3 session API unavailable
$ErrorActionPreference = 'Stop'
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
$states = @('Active', 'Connected', 'ConnectQuery', 'Shadow', 'Disconnected', 'Idle', 'Listen', 'Reset', 'Down', 'Init')
try {
    $sessions = @([UlWts]::List() | Where-Object { $_.User })
} catch {
    Write-Output ('Cannot enumerate sessions: ' + $_.Exception.Message)
    exit 3
}
if ($sessions.Count -eq 0) {
    Write-Output 'No user is logged on'
    exit 0
}
Write-Output ('{0} session(s)' -f $sessions.Count)
foreach ($s in $sessions) {
    $idle = 'n/a'
    $since = if ($s.LastInput -gt 0) { $s.LastInput } elseif ($s.Disconnect -gt 0) { $s.Disconnect } else { 0 }
    if ($since -gt 0 -and $s.Current -ge $since) {
        $span = [TimeSpan]::FromTicks($s.Current - $since)
        $idle = '{0}d {1:00}:{2:00}' -f $span.Days, $span.Hours, $span.Minutes
    }
    $logon = if ($s.Logon -gt 0) { '{0:yyyy-MM-dd HH:mm}' -f [DateTime]::FromFileTime($s.Logon) } else { 'n/a' }
    $state = if ($s.State -ge 0 -and $s.State -lt $states.Count) { $states[$s.State] } else { [string]$s.State }
    Write-Output ('id={0,-3} {1}\{2} state={3} idle={4} logon={5} station={6}' -f $s.Id, $s.Domain, $s.User, $state, $idle, $logon, $s.Station)
}
exit 0
