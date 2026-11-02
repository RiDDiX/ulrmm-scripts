# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks that Windows is activated and reports the license channel and remaining grace period.
# Variables: none
# Exit: 0 licensed, 1 not licensed, 3 licensing information unavailable
$ErrorActionPreference = 'Stop'
$windowsAppId = '55c92734-d682-4d71-983e-d6ec3f16059f'
try {
    $p = @(Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationId='$windowsAppId' AND PartialProductKey IS NOT NULL" | Where-Object { -not $_.LicenseIsAddon })
} catch {
    Write-Output ('Cannot read the licensing status: ' + $_.Exception.Message)
    exit 3
}
if ($p.Count -eq 0) {
    Write-Output 'FAIL: no installed product key found'
    exit 1
}
$states = @{
    0 = 'Unlicensed'; 1 = 'Licensed'; 2 = 'Initial grace period'; 3 = 'Additional grace period'
    4 = 'Non-genuine grace period'; 5 = 'Notification'; 6 = 'Extended grace period'
}
$licensed = @($p | Where-Object { $_.LicenseStatus -eq 1 })
$main = if ($licensed.Count -gt 0) { $licensed[0] } else { $p[0] }
$text = $states[[int]$main.LicenseStatus]
if ($licensed.Count -gt 0) {
    Write-Output 'OK: Windows is activated'
    $rc = 0
} else {
    Write-Output ('FAIL: Windows is not activated (' + $text + ')')
    $rc = 1
}
Write-Output ('Product: ' + $main.Name)
Write-Output ('Channel: ' + $main.ProductKeyChannel + ', partial key ' + $main.PartialProductKey)
if ($main.GracePeriodRemaining -gt 0) {
    Write-Output ('Grace period remaining: ' + [math]::Round($main.GracePeriodRemaining / 1440, 1) + ' days')
}
exit $rc
