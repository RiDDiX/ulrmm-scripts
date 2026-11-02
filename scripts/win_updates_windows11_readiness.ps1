# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks the Windows 11 hardware requirements: 64-bit, 2+ cores, 1 GHz, 4 GB RAM, 64 GB system disk, UEFI, Secure Boot capable, TPM 2.0. The CPU model list is NOT checked.
# Variables: none.
# Exit: 0 all checks pass, 1 at least one check fails, 3 not a client Windows.
$ErrorActionPreference = 'Stop'
if ((Get-CimInstance Win32_OperatingSystem).ProductType -ne 1) { Write-Output 'Windows 11 readiness only applies to client Windows, not to Windows Server'; exit 3 }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class FwType {
    [DllImport("kernel32.dll")]
    public static extern bool GetFirmwareType(ref uint type);
}
'@
$fail = 0
$lines = @()
function Write-Check([string]$Label, [bool]$Ok, [string]$Detail) {
    $tag = 'FAIL'
    if ($Ok) { $tag = 'ok  ' } else { $script:fail++ }
    $script:lines += ("{0} {1}: {2}" -f $tag, $Label, $Detail)
}
try {
    $cpu = @(Get-CimInstance Win32_Processor)
    $cs = Get-CimInstance Win32_ComputerSystem
    $arch = ($cpu | Select-Object -First 1).AddressWidth
    Write-Check '64-bit CPU' ($arch -eq 64) "address width $arch"
    $cores = ($cpu | Measure-Object -Property NumberOfCores -Sum).Sum
    Write-Check 'Cores' ($cores -ge 2) "$cores"
    $mhz = ($cpu | Measure-Object -Property MaxClockSpeed -Minimum).Minimum
    Write-Check 'Clock' ($mhz -ge 1000) "$mhz MHz"
    $ram = [double](@(Get-CimInstance Win32_PhysicalMemory) | Measure-Object -Property Capacity -Sum).Sum
    if ($ram -le 0) { $ram = $cs.TotalPhysicalMemory }
    $ramGb = [math]::Round($ram / 1GB, 1)
    Write-Check 'RAM' ($ramGb -ge 3.8) "$ramGb GB (4 GB needed)"
    $disk = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $env:SystemDrive)
    $diskGb = [math]::Round($disk.Size / 1GB, 0)
    Write-Check 'System disk' ($diskGb -ge 60) "$diskGb GB (64 GB needed)"

    $fw = [uint32]0
    $uefi = $false
    if ([FwType]::GetFirmwareType([ref]$fw)) { $uefi = ($fw -eq 2) }
    Write-Check 'UEFI firmware' $uefi $(if ($uefi) { 'UEFI' } else { 'legacy BIOS' })
    $sb = $false
    $sbDetail = 'not supported'
    if ($uefi) {
        try {
            $on = Confirm-SecureBootUEFI
            $sb = $true
            $sbDetail = if ($on) { 'capable, enabled' } else { 'capable, currently off' }
        } catch { $sbDetail = 'not supported by the firmware' }
    }
    Write-Check 'Secure Boot' $sb $sbDetail

    $tpm = $null
    try { $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm } catch { $tpm = $null }
    if (-not $tpm) {
        Write-Check 'TPM 2.0' $false 'no TPM found or it is disabled in the firmware'
    } else {
        $spec = [string]$tpm.SpecVersion
        Write-Check 'TPM 2.0' ($spec -like '2.0*') "spec $spec, enabled $($tpm.IsEnabled_InitialValue), activated $($tpm.IsActivated_InitialValue)"
    }
    $lines += "Not checked: CPU model on the supported list ($(($cpu | Select-Object -First 1).Name.Trim()))"
    if ($fail -eq 0) { Write-Output 'RESULT: ready for Windows 11 (CPU list not checked)'; Write-Output $lines; exit 0 }
    Write-Output "RESULT: not ready, $fail check(s) failed"
    Write-Output $lines
    exit 1
} catch {
    Write-Output "Check failed: $($_.Exception.Message)"
    exit 1
}
