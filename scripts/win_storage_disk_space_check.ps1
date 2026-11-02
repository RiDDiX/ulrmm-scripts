# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks the used space of the fixed drives against a warning and an error threshold.
# Variables: WARN_PERCENT (85) used space for a warning; ERROR_PERCENT (95) used space for an error; DRIVES drive letters like C,D (empty = all fixed drives).
# Exit: 0 ok, 1 a drive is above the error threshold, 2 a drive is above the warning threshold, 3 bad input.
$warn = 85
$err = 95
if ($env:WARN_PERCENT) { if (-not [int]::TryParse($env:WARN_PERCENT.Trim(), [ref]$warn) -or $warn -lt 1 -or $warn -gt 100) { Write-Output 'WARN_PERCENT must be a number from 1 to 100'; exit 3 } }
if ($env:ERROR_PERCENT) { if (-not [int]::TryParse($env:ERROR_PERCENT.Trim(), [ref]$err) -or $err -lt 1 -or $err -gt 100) { Write-Output 'ERROR_PERCENT must be a number from 1 to 100'; exit 3 } }
if ($warn -gt $err) { Write-Output 'WARN_PERCENT must not be above ERROR_PERCENT'; exit 3 }
$only = @()
if ($env:DRIVES) {
    foreach ($d in ($env:DRIVES -split '[,\s;]+' | Where-Object { $_ })) {
        if ($d -notmatch '^[A-Za-z]:?\\?$') { Write-Output "'$d' is not a drive letter"; exit 3 }
        $only += ($d.Substring(0, 1).ToUpper() + ':')
    }
}
$disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.Size -gt 0 })
if ($only.Count -gt 0) {
    foreach ($o in $only) { if (-not ($disks | Where-Object { $_.DeviceID -eq $o })) { Write-Output "Drive $o not found"; exit 3 } }
    $disks = @($disks | Where-Object { $only -contains $_.DeviceID })
}
$level = 0
$lines = @()
foreach ($d in $disks) {
    $pct = [math]::Round(100 - 100 * $d.FreeSpace / $d.Size, 1)
    $tag = 'ok'
    if ($pct -ge $err) { $tag = 'ERROR'; $level = 2 } elseif ($pct -ge $warn) { $tag = 'WARN'; if ($level -lt 1) { $level = 1 } }
    $lines += ('{0} {1} {2}% used, {3:N1} GB free of {4:N0} GB' -f $tag, $d.DeviceID, $pct, ($d.FreeSpace / 1GB), ($d.Size / 1GB))
}
if ($disks.Count -eq 0) { Write-Output 'No fixed drives found'; exit 0 }
switch ($level) {
    0 { Write-Output "OK: $($disks.Count) drive(s) below $warn% used"; $rc = 0 }
    1 { Write-Output "WARNING: a drive is above $warn% used"; $rc = 2 }
    2 { Write-Output "CRITICAL: a drive is above $err% used"; $rc = 1 }
}
$lines | ForEach-Object { Write-Output $_ }
exit $rc
