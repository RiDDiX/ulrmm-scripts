# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks whether a restart is pending (servicing stack, Windows Update, file renames, computer rename).
# Variables: none
# Exit: 0 no restart pending, 2 restart pending
$ErrorActionPreference = 'Stop'
$reasons = @()
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
    $reasons += 'component servicing'
}
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
    $reasons += 'Windows Update'
}
$sm = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
if ($sm -and $sm.PendingFileRenameOperations) {
    $reasons += 'pending file rename operations'
}
$names = 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName'
$active = (Get-ItemProperty -Path ($names + '\ActiveComputerName') -ErrorAction SilentlyContinue).ComputerName
$new = (Get-ItemProperty -Path ($names + '\ComputerName') -ErrorAction SilentlyContinue).ComputerName
if ($active -and $new -and $active -ne $new) {
    $reasons += 'computer rename'
}
if ($reasons.Count -gt 0) {
    Write-Output ('WARNING: restart pending: ' + ($reasons -join ', '))
    exit 2
}
Write-Output 'OK: no restart pending'
exit 0
