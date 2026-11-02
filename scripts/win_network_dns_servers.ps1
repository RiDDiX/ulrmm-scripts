# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Sets the DNS servers of an adapter (default: the adapters with a default gateway) or returns them to DHCP. Without SERVERS and RESET_TO_DHCP it only reports.
# Variables: SERVERS IP addresses separated by comma, space or line; INTERFACE adapter name; RESET_TO_DHCP (false) use the DHCP-provided servers.
# Exit: 0 done, 1 failed, 3 bad input or no matching adapter.
if ($env:RESET_TO_DHCP -and 'true', 'false' -notcontains $env:RESET_TO_DHCP.Trim()) { Write-Output 'RESET_TO_DHCP must be true or false'; exit 3 }
$reset = $env:RESET_TO_DHCP -and $env:RESET_TO_DHCP.Trim() -eq 'true'
$servers = @()
if ($env:SERVERS -and -not $reset) {
    foreach ($s in ($env:SERVERS -split '[,\s;]+' | Where-Object { $_ })) {
        $ip = $null
        if ($s -notmatch '^(\d{1,3}\.){3}\d{1,3}$|:' -or -not [System.Net.IPAddress]::TryParse($s, [ref]$ip)) { Write-Output "'$s' is not an IP address"; exit 3 }
        $servers += $ip.ToString()
    }
}
$if = ''
if ($env:INTERFACE) { $if = $env:INTERFACE.Trim() }
if ($if -match '[\*\?\[\]]') { Write-Output 'INTERFACE must not contain wildcards'; exit 3 }
try {
    if ($if) {
        $adapters = @(Get-NetAdapter -Name $if -ErrorAction SilentlyContinue)
    } else {
        $adapters = @(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | ForEach-Object { $_.NetAdapter })
    }
    if ($adapters.Count -eq 0) { Write-Output 'No matching network adapter found'; exit 3 }
    foreach ($a in $adapters) {
        if ($reset) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop }
        elseif ($servers.Count -gt 0) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $servers -ErrorAction Stop }
        $now = @(Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 | ForEach-Object { $_.ServerAddresses })
        Write-Output "$($a.Name): $($now -join ', ')"
    }
    if ($reset -or $servers.Count -gt 0) { Clear-DnsClientCache; Write-Output 'DNS cache flushed' }
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
