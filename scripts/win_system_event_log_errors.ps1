# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists critical and error events of an event log, grouped by provider and event id.
# Variables: LOG (System) log name; HOURS (24) look back; MAX (20) number of groups shown.
# Exit: 0 report printed, 3 bad input or unknown log.
$log = 'System'
if ($env:LOG) { $log = $env:LOG.Trim() }
if ($log -notmatch '^[A-Za-z0-9 /_.\-]{1,100}$') { Write-Output 'LOG contains characters that are not allowed'; exit 3 }
$hours = 24
if ($env:HOURS) { if (-not [int]::TryParse($env:HOURS.Trim(), [ref]$hours) -or $hours -lt 1 -or $hours -gt 8760) { Write-Output 'HOURS must be a number from 1 to 8760'; exit 3 } }
$maxRows = 20
if ($env:MAX) { if (-not [int]::TryParse($env:MAX.Trim(), [ref]$maxRows) -or $maxRows -lt 1 -or $maxRows -gt 200) { Write-Output 'MAX must be a number from 1 to 200'; exit 3 } }

$info = Get-WinEvent -ListLog $log -ErrorAction SilentlyContinue
if (-not $info) { Write-Output "Event log '$log' does not exist"; exit 3 }
try {
    $events = @(Get-WinEvent -FilterHashtable @{ LogName = $log; Level = 1, 2; StartTime = (Get-Date).AddHours(-$hours) } -ErrorAction SilentlyContinue)
} catch { $events = @() }
if ($events.Count -eq 0) { Write-Output "No critical or error events in '$log' during the last $hours hours"; exit 0 }
$groups = $events | Group-Object -Property ProviderName, Id | Sort-Object -Property Count -Descending
Write-Output ("{0} critical/error events in '{1}' during the last {2} hours, {3} distinct provider/id pairs" -f $events.Count, $log, $hours, @($groups).Count)
foreach ($g in ($groups | Select-Object -First $maxRows)) {
    $first = $g.Group | Select-Object -First 1
    $line = ([string]$first.Message -split "`r?`n")[0]
    if ($line.Length -gt 60) { $line = $line.Substring(0, 60) }
    Write-Output ("{0,5}x {1} id {2} last {3:MM-dd HH:mm}: {4}" -f $g.Count, $first.ProviderName, $first.Id, $first.TimeCreated, $line)
}
exit 0
