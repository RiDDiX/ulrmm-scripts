# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists local user accounts with state, last logon, password expiry and administrator membership.
# Variables: none
# Exit: 0 listed, 3 local accounts not available (domain controller or missing cmdlets)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command Get-LocalUser -ErrorAction SilentlyContinue)) {
    Write-Output 'The LocalAccounts cmdlets are not available on this system'
    exit 3
}
try {
    $users = @(Get-LocalUser)
} catch {
    Write-Output ('Cannot list local users (domain controller?): ' + $_.Exception.Message)
    exit 3
}
# administrators group found by SID, read with net.exe because Get-LocalGroupMember fails on orphaned members
$admins = @()
try {
    $sid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $group = $sid.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]
    $out = @(& net.exe localgroup $group 2>&1 | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
    $dash = -1
    for ($i = 0; $i -lt $out.Count; $i++) {
        if ($out[$i] -match '^-{5,}$') { $dash = $i; break }
    }
    if ($dash -ge 0 -and $out.Count - 2 -gt $dash) {
        $admins = @($out[($dash + 1)..($out.Count - 2)] | ForEach-Object { $_.ToLower() })
    }
} catch {
    Write-Output 'Warning: could not read the Administrators group'
}
$prefix = $env:COMPUTERNAME.ToLower() + '\'
Write-Output ('{0} local account(s)' -f $users.Count)
foreach ($u in ($users | Sort-Object Name)) {
    $isAdmin = ($admins -contains $u.Name.ToLower()) -or ($admins -contains ($prefix + $u.Name.ToLower()))
    $last = if ($u.LastLogon) { '{0:yyyy-MM-dd HH:mm}' -f $u.LastLogon } else { 'never' }
    $exp = if ($u.PasswordExpires) { '{0:yyyy-MM-dd}' -f $u.PasswordExpires } else { 'never' }
    Write-Output ('{0,-24} enabled={1,-5} admin={2,-5} lastlogon={3,-16} pwexpires={4}' -f $u.Name, $u.Enabled, $isAdmin, $last, $exp)
}
exit 0
