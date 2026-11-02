# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports Secure Boot state, firmware type and TPM presence and readiness.
# Variables: none
# Exit: 0 Secure Boot on and TPM ready, 2 Secure Boot off or unsupported or no usable TPM
$ErrorActionPreference = 'Stop'
$problems = @()

$boot = 'unknown'
try {
    if (Confirm-SecureBootUEFI) { $boot = 'enabled' } else { $boot = 'disabled' }
} catch {
    $boot = 'not supported (legacy BIOS boot or no UEFI)'
}
if ($boot -ne 'enabled') { $problems += 'Secure Boot ' + $boot }
Write-Output ('Secure Boot: ' + $boot)

$tpmText = 'not present'
$ready = $false
try {
    $t = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm
    if ($t) {
        $ver = ([string]$t.SpecVersion).Split(',')[0]
        $ready = [bool]$t.IsEnabled_InitialValue -and [bool]$t.IsActivated_InitialValue
        $tpmText = 'spec ' + $ver + ', enabled=' + $t.IsEnabled_InitialValue + ', activated=' + $t.IsActivated_InitialValue + ', manufacturer=' + $t.ManufacturerIdTxt
    }
} catch {
    $tpmText = 'not present or not readable'
}
if (-not $ready) { $problems += 'TPM ' + $tpmText }
Write-Output ('TPM: ' + $tpmText)

if ($problems.Count -gt 0) {
    Write-Output ('WARNING: ' + ($problems -join '; '))
    exit 2
}
Write-Output 'OK: Secure Boot is on and the TPM is ready'
exit 0
