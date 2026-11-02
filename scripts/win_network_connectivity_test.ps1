# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Tests ping (host) or a TCP connection (host:port) for every target and optionally a DNS lookup.
# Variables: TARGETS one host or host:port per line (comma also works); DNS_NAME name that has to resolve.
# Exit: 0 everything works, 1 at least one test failed, 3 bad input.
$targets = @()
if ($env:TARGETS) { $targets = @($env:TARGETS -split '[,\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$dns = ''
if ($env:DNS_NAME) { $dns = $env:DNS_NAME.Trim() }
if ($targets.Count -eq 0 -and -not $dns) { Write-Output 'Give TARGETS or DNS_NAME'; exit 3 }
if ($dns -and $dns -notmatch '^[A-Za-z0-9._-]{1,253}$') { Write-Output 'DNS_NAME is not a valid host name'; exit 3 }
$failed = 0

function Test-TcpPort([string]$HostName, [int]$Port) {
    $family = [System.Net.Sockets.AddressFamily]::InterNetwork
    if ($HostName.Contains(':')) { $family = [System.Net.Sockets.AddressFamily]::InterNetworkV6 }
    $c = New-Object System.Net.Sockets.TcpClient($family)
    try {
        $iar = $c.BeginConnect($HostName, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne(5000)) { return 'timeout' }
        $c.EndConnect($iar)
        return 'ok'
    } catch { return 'refused or unreachable' }
    finally { $c.Close() }
}

if ($dns) {
    try {
        $r = @(Resolve-DnsName -Name $dns -DnsOnly -ErrorAction Stop | Where-Object { $_.IPAddress } | ForEach-Object { $_.IPAddress })
        if ($r.Count -eq 0) { throw 'no address records' }
        Write-Output "ok   DNS $dns -> $($r -join ', ')"
    } catch { Write-Output "FAIL DNS ${dns}: $($_.Exception.Message)"; $failed++ }
}
foreach ($t in $targets) {
    $h = $t
    $port = 0
    if ($t -match '^\[([0-9a-fA-F:.]+)\]:([0-9]{1,5})$' -or $t -match '^([A-Za-z0-9._-]+):([0-9]{1,5})$') { $h = $Matches[1]; $port = [int]$Matches[2] }
    if ($h -notmatch '^[A-Za-z0-9._:-]{1,253}$' -or $port -lt 0 -or $port -gt 65535) { Write-Output "FAIL ${t}: not a valid target"; $failed++; continue }
    if ($port -gt 0) {
        $res = Test-TcpPort $h $port
        if ($res -eq 'ok') { Write-Output "ok   TCP ${h}:$port" } else { Write-Output "FAIL TCP ${h}:$port $res"; $failed++ }
    } else {
        $ok = Test-Connection -ComputerName $h -Count 2 -Quiet -ErrorAction SilentlyContinue
        if ($ok) { Write-Output "ok   ping $h" } else { Write-Output "FAIL ping $h"; $failed++ }
    }
}
if ($failed -gt 0) { Write-Output "$failed test(s) failed"; exit 1 }
Write-Output 'All tests passed'
exit 0
