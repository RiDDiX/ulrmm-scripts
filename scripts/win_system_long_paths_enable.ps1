# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Enables Win32 long path support (paths over 260 characters) for applications that declare it.
# Variables: none.
# Exit: 0 enabled or already enabled, 1 failed, 3 Windows too old.
$build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
if ($build -lt 14393) { Write-Output "Long paths need Windows 10 1607 or Server 2016 (build 14393), this is build $build"; exit 3 }
$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
try {
    $cur = (Get-ItemProperty -LiteralPath $key -Name LongPathsEnabled -ErrorAction SilentlyContinue).LongPathsEnabled
    if ($cur -eq 1) { Write-Output 'LongPathsEnabled is already 1'; exit 0 }
    New-ItemProperty -LiteralPath $key -Name LongPathsEnabled -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Output 'LongPathsEnabled set to 1; running applications pick it up after a restart'
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
