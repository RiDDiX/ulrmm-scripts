# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Looks for bluescreens (bugchecks) in the last days: event 1001 of the system error reporting provider and new dump files.
# Variables: DAYS (7) look back in days.
# Exit: 0 none found, 1 a bluescreen was recorded, 3 bad input.
$days = 7
if ($env:DAYS) { if (-not [int]::TryParse($env:DAYS.Trim(), [ref]$days) -or $days -lt 1 -or $days -gt 365) { Write-Output 'DAYS must be a number from 1 to 365'; exit 3 } }
$since = (Get-Date).AddDays(-$days)
$events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $since } -ErrorAction SilentlyContinue)
$dumps = @()
$mini = Join-Path $env:windir 'Minidump'
if (Test-Path -LiteralPath $mini) { $dumps += @(Get-ChildItem -LiteralPath $mini -Filter '*.dmp' -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $since }) }
$full = Join-Path $env:windir 'MEMORY.DMP'
if (Test-Path -LiteralPath $full) { $dumps += @(Get-Item -LiteralPath $full | Where-Object { $_.LastWriteTime -ge $since }) }
if ($events.Count -eq 0 -and $dumps.Count -eq 0) { Write-Output "OK: no bluescreen in the last $days days"; exit 0 }
Write-Output "CRITICAL: $($events.Count) bugcheck event(s) and $($dumps.Count) dump file(s) in the last $days days"
foreach ($e in $events) {
    $code = ''
    if ($e.Properties.Count -gt 0) { $code = [string]$e.Properties[0].Value }
    Write-Output ("{0:yyyy-MM-dd HH:mm} bugcheck {1}" -f $e.TimeCreated, $code)
}
foreach ($d in $dumps) { Write-Output ("Dump {0}, {1:yyyy-MM-dd HH:mm}, {2:N1} MB" -f $d.FullName, $d.LastWriteTime, ($d.Length / 1MB)) }
exit 1
