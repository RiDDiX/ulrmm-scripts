# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Prints the Windows product key embedded in the firmware (OA3), or the word none, alone on the last line.
# Variables: none
# Exit: 0 reported (none is a valid answer), 3 licensing information unavailable
$ErrorActionPreference = 'Stop'
try {
    $key = ([string](Get-CimInstance -ClassName SoftwareLicensingService).OA3xOriginalProductKey).Trim()
} catch {
    Write-Output ('Cannot read the licensing service: ' + $_.Exception.Message)
    exit 3
}
if (-not $key) {
    Write-Output 'No product key embedded in the firmware:'
    Write-Output 'none'
    exit 0
}
Write-Output 'Firmware product key:'
Write-Output $key
exit 0
