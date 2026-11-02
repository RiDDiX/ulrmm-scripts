# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports the time since the last boot and warns when it is longer than the limit.
# Variables: MAX_DAYS (30) uptime limit in days.
# Exit: 0 within the limit, 2 above the limit, 3 bad input.
$max = 30
if ($env:MAX_DAYS) { if (-not [int]::TryParse($env:MAX_DAYS.Trim(), [ref]$max) -or $max -lt 1 -or $max -gt 3650) { Write-Output 'MAX_DAYS must be a number from 1 to 3650'; exit 3 } }
$boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$up = (Get-Date) - $boot
$text = '{0} days {1} h {2} min (since {3:yyyy-MM-dd HH:mm})' -f $up.Days, $up.Hours, $up.Minutes, $boot
if ($up.TotalDays -gt $max) { Write-Output "WARNING: uptime $text, limit $max days"; exit 2 }
Write-Output "OK: uptime $text"
exit 0
