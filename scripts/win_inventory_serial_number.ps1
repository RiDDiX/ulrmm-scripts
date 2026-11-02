# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Prints the hardware serial number alone on the last line, for storing in an RMM custom field.
# Variables: none
# Exit: 0 serial found, 1 the firmware has no usable serial, 3 CIM data unavailable
$ErrorActionPreference = 'Stop'
$junk = '^(0+|none|n/a|default string|system serial number|to be filled by o\.e\.m\.|not specified|not applicable|chassis serial number|base board serial number|123456789.*)$'
try {
    $candidates = @(
        (Get-CimInstance -ClassName Win32_BIOS).SerialNumber,
        (Get-CimInstance -ClassName Win32_BaseBoard).SerialNumber,
        (Get-CimInstance -ClassName Win32_SystemEnclosure).SerialNumber
    )
} catch {
    Write-Output ('Cannot read the serial number: ' + $_.Exception.Message)
    exit 3
}
foreach ($c in $candidates) {
    $s = ([string]$c).Trim()
    if ($s -and $s -notmatch $junk) {
        Write-Output 'Serial number:'
        Write-Output $s
        exit 0
    }
}
Write-Output 'The firmware reports no usable serial number (virtual machine or unbranded board)'
exit 1
