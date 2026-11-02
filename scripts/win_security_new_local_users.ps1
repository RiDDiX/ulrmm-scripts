# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists user accounts created in a time window (event 4720), to spot unexpected new accounts.
# Variables: HOURS (default 24, 1-8760)
# Exit: 0 no account created, 2 at least one account created, 3 bad input or Security log unreadable
$ErrorActionPreference = 'Stop'
$raw = ([string]$env:HOURS).Trim()
$hours = 24
if ($raw) {
    if (-not [int]::TryParse($raw, [ref]$hours) -or $hours -lt 1 -or $hours -gt 8760) {
        Write-Output ('Bad HOURS value: ' + $raw + ' (allowed 1-8760)')
        exit 3
    }
}
$since = (Get-Date).AddHours(-$hours)
try {
    $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4720; StartTime = $since } -ErrorAction Stop)
} catch {
    if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
        $events = @()
    } else {
        Write-Output ('Cannot read the Security log: ' + $_.Exception.Message)
        exit 3
    }
}
if ($events.Count -eq 0) {
    Write-Output ('OK: no account created in the last ' + $hours + ' h')
    exit 0
}
Write-Output ('WARNING: ' + $events.Count + ' account(s) created in the last ' + $hours + ' h')
foreach ($e in $events) {
    $d = @{}
    foreach ($n in ([xml]$e.ToXml()).Event.EventData.Data) { $d[[string]$n.Name] = [string]$n.'#text' }
    Write-Output ('{0:yyyy-MM-dd HH:mm}  {1}\{2} created by {3}\{4}' -f $e.TimeCreated, $d['TargetDomainName'], $d['TargetUserName'], $d['SubjectDomainName'], $d['SubjectUserName'])
}
exit 2
