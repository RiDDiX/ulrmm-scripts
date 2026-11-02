# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Prints the BitLocker numerical recovery password of a drive on the last line, to store it in an RMM custom field.
# Variables: DRIVE (optional, default the system drive, e.g. C:)
# Exit: 0 key printed, 1 volume has no recovery password, 3 bad input or BitLocker unavailable
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
$keys = @($v.KeyProtector | Where-Object { [string]$_.KeyProtectorType -eq 'RecoveryPassword' -and $_.RecoveryPassword })
if ($keys.Count -eq 0) {
    Write-Output ('No recovery password protector on ' + $drive)
    exit 1
}
Write-Output ('Recovery password for ' + $drive + ' (last line):')
Write-Output $keys[0].RecoveryPassword
exit 0
