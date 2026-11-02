# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks whether the Active Directory Recycle Bin is enabled in the forest.
# Variables: none
# Exit: 0 enabled, 1 not enabled, 3 not a domain controller or ActiveDirectory module missing
$ErrorActionPreference = 'Stop'
$cs = Get-CimInstance -ClassName Win32_ComputerSystem
if ($cs.DomainRole -lt 4) {
    Write-Output 'This computer is not a domain controller'
    exit 3
}
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Output 'The ActiveDirectory PowerShell module is not installed'
    exit 3
}
try {
    Import-Module ActiveDirectory
    $f = Get-ADOptionalFeature -Filter "Name -eq 'Recycle Bin Feature'"
} catch {
    Write-Output ('Cannot query the forest: ' + $_.Exception.Message)
    exit 3
}
if ($f -and @($f.EnabledScopes).Count -gt 0) {
    Write-Output 'OK: AD Recycle Bin is enabled'
    exit 0
}
Write-Output 'FAIL: AD Recycle Bin is not enabled (enabling is irreversible, do it deliberately)'
exit 1
