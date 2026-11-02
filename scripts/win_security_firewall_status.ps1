# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks that the Windows Firewall is enabled on the domain, private and public profile.
# Variables: none
# Exit: 0 all profiles on, 1 at least one profile off, 3 firewall cmdlets unavailable
$ErrorActionPreference = 'Stop'
if (-not (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue)) {
    Write-Output 'Get-NetFirewallProfile is not available on this system'
    exit 3
}
try {
    $profiles = @(Get-NetFirewallProfile -PolicyStore ActiveStore)
} catch {
    Write-Output ('Cannot read the firewall profiles: ' + $_.Exception.Message)
    exit 3
}
$off = @($profiles | Where-Object { [string]$_.Enabled -ne 'True' })
if ($off.Count -gt 0) {
    Write-Output ('FAIL: firewall is off for: ' + (($off | ForEach-Object { $_.Name }) -join ', '))
} else {
    Write-Output 'OK: firewall is on for all profiles'
}
foreach ($p in $profiles) {
    Write-Output ('{0,-8} enabled={1} inbound={2} outbound={3}' -f $p.Name, $p.Enabled, $p.DefaultInboundAction, $p.DefaultOutboundAction)
}
if ($off.Count -gt 0) { exit 1 }
exit 0
