# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Pins a Windows 10 or 11 PC to a feature update version with the TargetReleaseVersion policy.
# Variables: ACTION (status) status, set or clear; PRODUCT (Windows 11) Windows 10 or Windows 11; VERSION release such as 24H2.
# Exit: 0 done, 1 failed, 3 bad input or not a client Windows.
$action = 'status'
if ($env:ACTION) { $action = $env:ACTION.Trim().ToLower() }
if ('status', 'set', 'clear' -notcontains $action) { Write-Output 'ACTION must be status, set or clear'; exit 3 }
$product = 'Windows 11'
if ($env:PRODUCT) { $product = $env:PRODUCT.Trim() }
if ('Windows 10', 'Windows 11' -notcontains $product) { Write-Output 'PRODUCT must be Windows 10 or Windows 11'; exit 3 }
$version = ''
if ($env:VERSION) { $version = $env:VERSION.Trim().ToUpper() }
if ($action -eq 'set' -and $version -notmatch '^[0-9]{2}H[12]$') { Write-Output 'VERSION must look like 24H2'; exit 3 }
if ((Get-CimInstance Win32_OperatingSystem).ProductType -ne 1) { Write-Output 'The policy only applies to client Windows, not to Windows Server'; exit 3 }

$key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$values = 'TargetReleaseVersion', 'ProductVersion', 'TargetReleaseVersionInfo'
try {
    if ($action -eq 'set') {
        if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
        New-ItemProperty -LiteralPath $key -Name TargetReleaseVersion -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -LiteralPath $key -Name ProductVersion -Value $product -PropertyType String -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -LiteralPath $key -Name TargetReleaseVersionInfo -Value $version -PropertyType String -Force -ErrorAction Stop | Out-Null
        Write-Output "Feature update target set to $product $version"
    } elseif ($action -eq 'clear') {
        $removed = 0
        foreach ($v in $values) {
            if (Get-ItemProperty -LiteralPath $key -Name $v -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -LiteralPath $key -Name $v -ErrorAction Stop
                $removed++
            }
        }
        Write-Output "Feature update target cleared ($removed policy values removed)"
    }
    $p = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
    if ($p -and $p.TargetReleaseVersion -eq 1) {
        Write-Output "Current target: $($p.ProductVersion) $($p.TargetReleaseVersionInfo)"
    } else {
        Write-Output 'Current target: none, feature updates follow the normal offer'
    }
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
