# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Turns the Windows Firewall on for the domain, private and public profile.
# Variables: none
# Exit: 0 all profiles on, 1 a profile could not be enabled, 3 firewall cmdlets unavailable
$ErrorActionPreference = 'Stop'
if (-not (Get-Command Set-NetFirewallProfile -ErrorAction SilentlyContinue)) {
    Write-Output 'Set-NetFirewallProfile is not available on this system'
    exit 3
}
try {
    $before = @(Get-NetFirewallProfile -PolicyStore ActiveStore | Where-Object { [string]$_.Enabled -ne 'True' } | ForEach-Object { $_.Name })
    if ($before.Count -eq 0) {
        Write-Output 'Firewall was already on for all profiles, nothing changed'
        exit 0
    }
    Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True
    $after = @(Get-NetFirewallProfile -PolicyStore ActiveStore | Where-Object { [string]$_.Enabled -ne 'True' } | ForEach-Object { $_.Name })
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
if ($after.Count -gt 0) {
    Write-Output ('FAIL: still off for: ' + ($after -join ', '))
    exit 1
}
Write-Output ('Firewall enabled for: ' + ($before -join ', '))
exit 0
