# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Optimizes a volume by media type: TRIM for SSDs and thin disks, defragmentation for hard disks.
# Variables: DRIVE drive letter (default: the system drive).
# Exit: 0 done, 1 failed, 3 bad input or unsupported volume.
$drive = $env:SystemDrive
if ($env:DRIVE) { $drive = $env:DRIVE.Trim() }
if ($drive -notmatch '^[A-Za-z]:?\\?$') { Write-Output 'DRIVE must be a drive letter like C'; exit 3 }
$letter = $drive.Substring(0, 1).ToUpper()
if (-not (Get-Command Optimize-Volume -ErrorAction SilentlyContinue)) { Write-Output 'Optimize-Volume is not available on this system'; exit 3 }
$vol = Get-Volume -DriveLetter $letter -ErrorAction SilentlyContinue
if (-not $vol -or $vol.DriveType -ne 'Fixed') { Write-Output "Drive ${letter}: is not a fixed volume"; exit 3 }
if ($vol.FileSystem -notin 'NTFS', 'ReFS') { Write-Output "Drive ${letter}: has file system '$($vol.FileSystem)', only NTFS and ReFS are optimized"; exit 3 }
try {
    $media = 'Unspecified'
    $disk = Get-Partition -DriveLetter $letter -ErrorAction Stop | Get-Disk -ErrorAction Stop | Select-Object -First 1
    $pd = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { [string]$_.DeviceId -eq [string]$disk.Number } | Select-Object -First 1
    if ($pd) { $media = [string]$pd.MediaType }
    if ($media -eq 'HDD') {
        Optimize-Volume -DriveLetter $letter -Defrag -ErrorAction Stop
        Write-Output "Drive ${letter}: defragmented (hard disk)"
    } elseif ($media -eq 'SSD') {
        Optimize-Volume -DriveLetter $letter -ReTrim -ErrorAction Stop
        Write-Output "Drive ${letter}: retrim done (SSD)"
    } else {
        Optimize-Volume -DriveLetter $letter -ErrorAction Stop
        Write-Output "Drive ${letter}: default optimization for the drive type done (media type $media)"
    }
    exit 0
} catch {
    Write-Output "Drive ${letter}: $($_.Exception.Message)"
    exit 1
}
