# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows, enables or disables USB mass storage through the USBSTOR driver start value.
# Variables: STATE (status, enable or disable; default status)
# Exit: 0 ok, 1 change failed, 3 bad input
# Devices that are already plugged in keep working until they are removed or the machine restarts.
$ErrorActionPreference = 'Stop'
$state = ([string]$env:STATE).Trim().ToLower()
if (-not $state) { $state = 'status' }
if ($state -notin 'status', 'enable', 'disable') {
    Write-Output ('Bad STATE value: ' + $state)
    exit 3
}
$key = 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR'
if (-not (Test-Path $key)) {
    Write-Output 'USBSTOR driver key not found'
    exit 3
}
try {
    $current = [int](Get-ItemProperty -Path $key -Name Start).Start
    if ($state -eq 'enable' -or $state -eq 'disable') {
        $want = if ($state -eq 'enable') { 3 } else { 4 }
        if ($current -eq $want) {
            Write-Output ('USB storage already ' + $state + 'd, nothing changed')
        } else {
            [void](New-ItemProperty -Path $key -Name Start -Value $want -PropertyType DWord -Force)
            Write-Output ('USB storage ' + $state + 'd')
        }
        $current = [int](Get-ItemProperty -Path $key -Name Start).Start
    }
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
$label = if ($current -eq 4) { 'disabled' } elseif ($current -eq 3) { 'enabled' } else { 'start value ' + $current }
Write-Output ('USB storage is ' + $label)
exit 0
