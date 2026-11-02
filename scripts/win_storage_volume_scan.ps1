# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Scans a volume for file system errors with Repair-Volume (online scan) or runs a spot fix.
# Variables: DRIVE drive letter; SPOT_FIX (false) run -SpotFix, which repairs offline and may schedule the work for the next restart on the system drive.
# Exit: 0 no errors or errors fixed, 1 errors remain or the scan failed, 3 bad input or not a fixed NTFS volume.
$drive = ''
if ($env:DRIVE) { $drive = $env:DRIVE.Trim() }
if ($drive -notmatch '^[A-Za-z]:?\\?$') { Write-Output 'DRIVE must be a drive letter like C'; exit 3 }
$letter = $drive.Substring(0, 1).ToUpper()
if ($env:SPOT_FIX -and 'true', 'false' -notcontains $env:SPOT_FIX.Trim()) { Write-Output 'SPOT_FIX must be true or false'; exit 3 }
if (-not (Get-Command Repair-Volume -ErrorAction SilentlyContinue)) { Write-Output 'Repair-Volume is not available on this system'; exit 3 }
$vol = Get-Volume -DriveLetter $letter -ErrorAction SilentlyContinue
if (-not $vol) { Write-Output "Drive ${letter}: not found"; exit 3 }
if ($vol.DriveType -ne 'Fixed') { Write-Output "Drive ${letter}: is not a fixed disk"; exit 3 }
if ($vol.FileSystem -ne 'NTFS') { Write-Output "Drive ${letter}: has file system '$($vol.FileSystem)', scan and spot fix work on NTFS only"; exit 3 }
try {
    if ("$env:SPOT_FIX".Trim() -eq 'true') { $res = Repair-Volume -DriveLetter $letter -SpotFix -ErrorAction Stop; $mode = 'spot fix' }
    else { $res = Repair-Volume -DriveLetter $letter -Scan -ErrorAction Stop; $mode = 'scan' }
    $text = (@($res) | ForEach-Object { $_.ToString() }) -join ' '
    Write-Output "Drive ${letter}: $mode result: $text"
    if ($text -match 'NoErrorsFound|ErrorsFixed') { exit 0 }
    exit 1
} catch {
    Write-Output "Drive ${letter}: $($_.Exception.Message)"
    exit 1
}
