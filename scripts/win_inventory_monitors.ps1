# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists connected monitors with manufacturer, model, serial number, manufacture date and size.
# Variables: none
# Exit: 0 reported (also when no monitor data exists), 3 monitor information unavailable
$ErrorActionPreference = 'Stop'
function ConvertFrom-EdidText($Value) {
    if (-not $Value) { return '' }
    return (-join ($Value | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ })).Trim()
}
try {
    $ids = @(Get-CimInstance -Namespace 'root\wmi' -ClassName WmiMonitorID)
    $sizes = @(Get-CimInstance -Namespace 'root\wmi' -ClassName WmiMonitorBasicDisplayParams)
} catch {
    # the monitor classes report NotSupported when no display driver exposes EDID data
    if ([string]$_.Exception.NativeErrorCode -ne 'NotSupported') {
        Write-Output ('Monitor information is not available: ' + $_.Exception.Message)
        exit 3
    }
    $ids = @()
}
if ($ids.Count -eq 0) {
    Write-Output 'No monitor reported (virtual machine, remote session or headless)'
    exit 0
}
Write-Output ('{0} monitor(s)' -f $ids.Count)
foreach ($m in $ids) {
    $size = $sizes | Where-Object { $_.InstanceName -eq $m.InstanceName } | Select-Object -First 1
    $dim = 'n/a'
    if ($size -and $size.MaxHorizontalImageSize -gt 0) {
        $inch = [math]::Sqrt([math]::Pow($size.MaxHorizontalImageSize, 2) + [math]::Pow($size.MaxVerticalImageSize, 2)) / 2.54
        $dim = '{0}x{1} cm (~{2:N1} in)' -f $size.MaxHorizontalImageSize, $size.MaxVerticalImageSize, $inch
    }
    Write-Output ('{0} {1} | serial {2} | made {3} week {4} | {5}' -f (ConvertFrom-EdidText $m.ManufacturerName), (ConvertFrom-EdidText $m.UserFriendlyName), (ConvertFrom-EdidText $m.SerialNumberID), $m.YearOfManufacture, $m.WeekOfManufacture, $dim)
}
exit 0
