# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports the IP configuration of every adapter that has an address: status, MAC, addresses, gateway, DNS servers and DHCP.
# Variables: none.
# Exit: 0 report printed, 1 failed.
try {
    $configs = @(Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.IPv4Address -or $_.IPv6Address })
    if ($configs.Count -eq 0) { Write-Output 'No adapter with an IP address'; exit 0 }
    Write-Output "$($configs.Count) adapter(s) with an address, host $($env:COMPUTERNAME)"
    foreach ($c in $configs) {
        $a = $c.NetAdapter
        $dhcp = (Get-NetIPInterface -InterfaceIndex $c.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).Dhcp
        Write-Output "[$($c.InterfaceAlias)] $($a.InterfaceDescription), $($a.Status), $($a.LinkSpeed), MAC $($a.MacAddress)"
        Write-Output ("  IPv4: {0}" -f ((@($c.IPv4Address) | Where-Object { $_ } | ForEach-Object { '{0}/{1}' -f $_.IPAddress, $_.PrefixLength }) -join ', '))
        $v6 = @($c.IPv6Address | Where-Object { $_ } | ForEach-Object { $_.IPAddress })
        if ($v6.Count -gt 0) { Write-Output "  IPv6: $($v6 -join ', ')" }
        Write-Output ("  Gateway: {0}" -f ((@($c.IPv4DefaultGateway) | ForEach-Object { $_.NextHop }) -join ', '))
        Write-Output ("  DNS: {0}; DHCP: {1}" -f (@($c.DNSServer | ForEach-Object { $_.ServerAddresses }) -join ', '), $dhcp)
    }
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
