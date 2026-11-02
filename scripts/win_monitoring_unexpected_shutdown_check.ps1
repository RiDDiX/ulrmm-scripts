# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Looks for unexpected shutdowns and restarts in the last days: Kernel-Power event 41 and EventLog event 6008.
# Variables: DAYS (7) look back in days.
# Exit: 0 none found, 1 an unexpected shutdown was recorded, 3 bad input.
$days = 7
if ($env:DAYS) { if (-not [int]::TryParse($env:DAYS.Trim(), [ref]$days) -or $days -lt 1 -or $days -gt 365) { Write-Output 'DAYS must be a number from 1 to 365'; exit 3 } }
$since = (Get-Date).AddDays(-$days)
$kp = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $since } -ErrorAction SilentlyContinue)
$el = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'EventLog'; Id = 6008; StartTime = $since } -ErrorAction SilentlyContinue)
if ($kp.Count -eq 0 -and $el.Count -eq 0) { Write-Output "OK: no unexpected shutdown in the last $days days"; exit 0 }
Write-Output "CRITICAL: $($kp.Count) Kernel-Power 41 and $($el.Count) EventLog 6008 event(s) in the last $days days"
foreach ($e in ($kp + $el | Sort-Object -Property TimeCreated)) {
    $extra = ''
    if ($e.Id -eq 41 -and $e.Properties.Count -gt 0 -and [int64]$e.Properties[0].Value -ne 0) { $extra = ' bugcheck 0x{0:X}' -f [int64]$e.Properties[0].Value }
    Write-Output ("{0:yyyy-MM-dd HH:mm:ss} {1} event {2}{3}" -f $e.TimeCreated, $e.ProviderName, $e.Id, $extra)
}
exit 1
