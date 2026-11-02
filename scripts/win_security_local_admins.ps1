# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists the members of the local Administrators group (found by SID, works on any language) and flags unexpected ones.
# Variables: ALLOWED (optional, comma or line separated list of accepted accounts, with or without domain or computer name)
# Exit: 0 listed or all allowed, 1 a member is not in ALLOWED, 3 cannot read the group
$ErrorActionPreference = 'Stop'
$allowedRaw = [string]$env:ALLOWED
$allowed = @($allowedRaw -split '[,;\r\n]+' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })

try {
    $sid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $groupName = $sid.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]
    $out = & net.exe localgroup $groupName 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('net localgroup failed: ' + ($out -join ' ')) }
} catch {
    Write-Output ('Cannot read the Administrators group: ' + $_.Exception.Message)
    exit 3
}
# members follow the dashed line, the last line is the localized completion message
$lines = @($out | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
$dash = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^-{5,}$') { $dash = $i; break }
}
$members = @()
if ($dash -ge 0 -and $lines.Count - 2 -gt $dash) {
    $members = @($lines[($dash + 1)..($lines.Count - 2)])
}
$unexpected = @()
if ($allowed.Count -gt 0) {
    foreach ($m in $members) {
        $short = $m.ToLower().Split('\')[-1]
        if ($allowed -notcontains $m.ToLower() -and $allowed -notcontains $short) { $unexpected += $m }
    }
}
if ($unexpected.Count -gt 0) {
    Write-Output ('FAIL: not in the allowed list: ' + ($unexpected -join ', '))
} else {
    Write-Output ('OK: ' + $members.Count + ' member(s) in the group "' + $groupName + '"')
}
foreach ($m in $members) { Write-Output ('  ' + $m) }
if ($unexpected.Count -gt 0) { exit 1 }
exit 0
