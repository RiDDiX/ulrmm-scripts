# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Frees disk space: Windows temp, user temp folders (files older than a day), update download cache, optional recycle bin and component store cleanup.
# Variables: DRY_RUN (false) only report what would be removed, RECYCLE_BIN (false) empty the recycle bins, COMPONENT_CLEANUP (false) run DISM StartComponentCleanup.
# Exit: 0 done, 1 a step failed.
$ErrorActionPreference = 'Stop'
$dry = $env:DRY_RUN -eq 'true'
$recycle = $env:RECYCLE_BIN -eq 'true'
$component = $env:COMPONENT_CLEANUP -eq 'true'
$failed = $false

function Get-TreeFile([string]$Path) {
    $items = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        if ($i.PSIsContainer) {
            if (-not ($i.Attributes -band [IO.FileAttributes]::ReparsePoint)) { Get-TreeFile $i.FullName }
        } else { $i }
    }
}

function Remove-EmptyDir([string]$Path) {
    foreach ($d in @(Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        Remove-EmptyDir $d.FullName
        try { [IO.Directory]::Delete($d.FullName) } catch { $null = $_ }
    }
}

function Clear-Tree([string]$Path, [int]$MinAgeDays) {
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $cut = (Get-Date).AddDays(-$MinAgeDays)
    $bytes = [int64]0
    foreach ($f in @(Get-TreeFile $Path)) {
        if ($f.LastWriteTime -ge $cut) { continue }
        if ($dry) { $bytes += $f.Length; continue }
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $f.FullName)) { $bytes += $f.Length }
    }
    if (-not $dry) { Remove-EmptyDir $Path }
    return $bytes
}

function Format-Size([int64]$Bytes) { '{0:N1} MB' -f ($Bytes / 1MB) }

try {
    $sys = $env:SystemDrive
    $freeBefore = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sys'").FreeSpace
    $total = [int64]0
    $verb = 'Freed'
    if ($dry) { $verb = 'Would free' }

    $b = Clear-Tree (Join-Path $env:windir 'Temp') 1
    Write-Output ("Windows temp: {0} {1}" -f $verb.ToLower(), (Format-Size $b)); $total += $b

    $profiles = Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special -and $_.LocalPath }
    foreach ($p in $profiles) {
        $t = Join-Path $p.LocalPath 'AppData\Local\Temp'
        $b = Clear-Tree $t 1
        if ($b -gt 0) { Write-Output ("User temp {0}: {1}" -f (Split-Path -Leaf $p.LocalPath), (Format-Size $b)) }
        $total += $b
    }

    $wu = Join-Path $env:windir 'SoftwareDistribution\Download'
    if (Test-Path -LiteralPath $wu) {
        $stopped = @()
        if (-not $dry) {
            foreach ($n in 'wuauserv', 'bits') {
                $s = Get-Service -Name $n -ErrorAction SilentlyContinue
                if ($s -and $s.Status -eq 'Running') {
                    Stop-Service -Name $n -Force -ErrorAction SilentlyContinue
                    $stopped += $n
                    try { $s.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(60)) }
                    catch { Write-Output "$n did not stop in time, its files may stay" }
                }
            }
        }
        try { $b = Clear-Tree $wu 0 }
        finally {
            foreach ($n in $stopped) { Start-Service -Name $n -ErrorAction SilentlyContinue }
        }
        Write-Output ("Update download cache: {0}" -f (Format-Size $b)); $total += $b
    }

    if ($recycle) {
        $rb = [int64]0
        foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') {
            $bin = Join-Path ($d.DeviceID + '\') '$Recycle.Bin'
            if (-not (Test-Path -LiteralPath $bin)) { continue }
            foreach ($f in @(Get-TreeFile $bin)) {
                if ($dry) { $rb += $f.Length; continue }
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                if (-not (Test-Path -LiteralPath $f.FullName)) { $rb += $f.Length }
            }
        }
        Write-Output ("Recycle bins: {0}" -f (Format-Size $rb)); $total += $rb
    }

    if ($component) {
        if ($dry) {
            Write-Output 'Component cleanup: skipped (dry run)'
        } else {
            $ErrorActionPreference = 'Continue'
            $null = & dism.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1
            $rc = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
            if ($rc -eq 0) { Write-Output 'Component cleanup: done' }
            else { Write-Output "Component cleanup: DISM exit code $rc"; $failed = $true }
        }
    }

    $freeAfter = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sys'").FreeSpace
    Write-Output ("{0} in total: {1}; free on {2} {3} -> {4}" -f $verb, (Format-Size $total), $sys, (Format-Size $freeBefore), (Format-Size $freeAfter))
} catch {
    Write-Output "Cleanup failed: $($_.Exception.Message)"
    exit 1
}
if ($failed) { exit 1 }
exit 0
