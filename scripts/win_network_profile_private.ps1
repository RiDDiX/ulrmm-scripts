# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Sets connected networks of category Public to Private; domain networks are left alone.
# Variables: INTERFACE adapter name, empty = every connection.
# Exit: 0 done, 1 failed, 3 bad input or no matching connection.
$if = ''
if ($env:INTERFACE) { $if = $env:INTERFACE.Trim() }
if ($if -match '[\*\?\[\]]') { Write-Output 'INTERFACE must not contain wildcards'; exit 3 }
try {
    $profiles = @(Get-NetConnectionProfile -ErrorAction Stop)
    if ($if) { $profiles = @($profiles | Where-Object { $_.InterfaceAlias -ieq $if }) }
    if ($profiles.Count -eq 0) { Write-Output 'No matching network connection found'; exit 3 }
    foreach ($p in $profiles) {
        if ($p.NetworkCategory -eq 'Public') {
            Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
            Write-Output "$($p.InterfaceAlias) ($($p.Name)): Public -> Private"
        } else {
            Write-Output "$($p.InterfaceAlias) ($($p.Name)): already $($p.NetworkCategory)"
        }
    }
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
