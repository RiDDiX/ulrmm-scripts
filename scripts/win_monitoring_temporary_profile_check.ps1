# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks for users that are logged on with a temporary profile and for broken profile registrations (ProfileList keys ending in .bak).
# Variables: none.
# Exit: 0 healthy, 1 temporary or broken profile found.
$problems = @()
foreach ($p in @(Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special -and $_.LocalPath })) {
    if ($p.LocalPath -match '\\TEMP(\.[^\\]*)?$') { $problems += "Temporary profile folder $($p.LocalPath), SID $($p.SID), loaded: $($p.Loaded)" }
}
$list = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
foreach ($k in @(Get-ChildItem -LiteralPath $list -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like '*.bak' })) {
    $path = (Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
    $problems += "ProfileList key $($k.PSChildName) ends in .bak (profile $path is registered twice)"
}
$ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'Microsoft-Windows-User Profiles Service'; Id = 1511; StartTime = (Get-Date).AddDays(-7) } -ErrorAction SilentlyContinue)
if ($problems.Count -eq 0) {
    Write-Output "OK: no temporary profile; $($ev.Count) temporary-profile logon event(s) in the last 7 days"
    exit 0
}
Write-Output "CRITICAL: $($problems.Count) profile problem(s); $($ev.Count) temporary-profile logon event(s) in the last 7 days"
$problems | ForEach-Object { Write-Output $_ }
exit 1
