# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Summarises failed logons (event 4625) by account and source address within a time window.
# Variables: HOURS (default 24, 1-720), THRESHOLD (default 20, failures above which the check warns)
# Exit: 0 at or below the threshold, 2 above the threshold, 3 bad input or Security log unreadable
$ErrorActionPreference = 'Stop'
function Get-IntInput([string]$Name, [string]$Value, [int]$Default, [int]$Min, [int]$Max) {
    $raw = $Value.Trim()
    if (-not $raw) { return $Default }
    $n = 0
    if (-not [int]::TryParse($raw, [ref]$n) -or $n -lt $Min -or $n -gt $Max) {
        [Console]::Out.WriteLine('Bad ' + $Name + ' value: ' + $raw + ' (allowed ' + $Min + '-' + $Max + ')')
        exit 3
    }
    return $n
}
$hours = Get-IntInput 'HOURS' $env:HOURS 24 1 720
$threshold = Get-IntInput 'THRESHOLD' $env:THRESHOLD 20 0 1000000
$since = (Get-Date).AddHours(-$hours)

try {
    $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625; StartTime = $since } -MaxEvents 20000 -ErrorAction Stop)
} catch {
    if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
        $events = @()
    } else {
        Write-Output ('Cannot read the Security log: ' + $_.Exception.Message)
        exit 3
    }
}
$rows = foreach ($e in $events) {
    $d = @{}
    foreach ($n in ([xml]$e.ToXml()).Event.EventData.Data) { $d[[string]$n.Name] = [string]$n.'#text' }
    $ip = $d['IpAddress']
    if (-not $ip -or $ip -eq '-') { $ip = $d['WorkstationName'] }
    if (-not $ip -or $ip -eq '-') { $ip = 'local' }
    [pscustomobject]@{ Account = ($d['TargetDomainName'] + '\' + $d['TargetUserName']); Source = $ip }
}
$rows = @($rows)
$count = $rows.Count
if ($count -gt $threshold) {
    Write-Output ('WARNING: ' + $count + ' failed logons in the last ' + $hours + ' h (threshold ' + $threshold + ')')
} else {
    Write-Output ('OK: ' + $count + ' failed logons in the last ' + $hours + ' h (threshold ' + $threshold + ')')
}
$rows | Group-Object Account, Source | Sort-Object Count -Descending | Select-Object -First 25 | ForEach-Object {
    Write-Output ('{0,5}  {1}' -f $_.Count, $_.Name)
}
if ($count -gt $threshold) { exit 2 }
exit 0
