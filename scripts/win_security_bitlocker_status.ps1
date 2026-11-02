# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks that BitLocker protection is on and the volume is fully encrypted.
# Variables: DRIVE (optional, default the system drive, e.g. C:)
# Exit: 0 protected and encrypted, 1 not protected or not fully encrypted, 3 bad input or BitLocker unavailable
$ErrorActionPreference = 'Stop'
$drive = ([string]$env:DRIVE).Trim()
if (-not $drive) { $drive = $env:SystemDrive }
if ($drive -notmatch '^[A-Za-z]:?\\?$') {
    Write-Output ('Bad DRIVE value: ' + $drive)
    exit 3
}
$drive = $drive.Substring(0, 1).ToUpper() + ':'
if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
    Write-Output 'BitLocker is not available on this edition or installation'
    exit 3
}
try {
    $v = Get-BitLockerVolume -MountPoint $drive
} catch {
    Write-Output ('Cannot query BitLocker for ' + $drive + ': ' + $_.Exception.Message)
    exit 3
}
$protection = [string]$v.ProtectionStatus
$status = [string]$v.VolumeStatus
if ($protection -eq 'On' -and $status -eq 'FullyEncrypted') {
    Write-Output ('OK: ' + $drive + ' is protected and fully encrypted')
    $rc = 0
} else {
    Write-Output ('FAIL: ' + $drive + ' protection=' + $protection + ' status=' + $status)
    $rc = 1
}
Write-Output ('Encryption: {0}% method={1}' -f $v.EncryptionPercentage, $v.EncryptionMethod)
$protectors = @($v.KeyProtector | ForEach-Object { [string]$_.KeyProtectorType })
Write-Output ('Key protectors: ' + $(if ($protectors.Count) { $protectors -join ', ' } else { 'none' }))
exit $rc
