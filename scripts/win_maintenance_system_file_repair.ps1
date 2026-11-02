# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks the component store with DISM and the system files with sfc; in repair mode restores both. Results come from exit codes and DISM health states, not from text.
# Variables: MODE (scan) scan or repair.
# Exit: 0 healthy or repaired, 1 corruption remains or a step failed, 3 bad input.
$mode = 'scan'
if ($env:MODE) { $mode = $env:MODE.Trim().ToLower() }
if ($mode -ne 'scan' -and $mode -ne 'repair') { Write-Output 'MODE must be scan or repair'; exit 3 }
if (-not (Get-Command Repair-WindowsImage -ErrorAction SilentlyContinue)) { Write-Output 'The DISM PowerShell module is not available'; exit 3 }

function Test-SystemFile {
    $tmp = Join-Path $env:windir 'Temp\sfc-verify.txt'
    $p = Start-Process -FilePath (Join-Path $env:windir 'System32\sfc.exe') -ArgumentList '/verifyonly' -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tmp
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    return $p.ExitCode
}

try {
    $restart = $false
    $lines = @()
    $scan = Repair-WindowsImage -Online -ScanHealth -ErrorAction Stop
    $state = $scan.ImageHealthState.ToString()
    $lines += "Component store: $state"
    if ($mode -eq 'repair' -and $state -ne 'Healthy') {
        $fix = Repair-WindowsImage -Online -RestoreHealth -ErrorAction Stop
        if ($fix.RestartNeeded) { $restart = $true }
        $state = (Repair-WindowsImage -Online -ScanHealth -ErrorAction Stop).ImageHealthState.ToString()
        $lines += "Component store after repair: $state"
    }
    if ($mode -eq 'repair') {
        $tmp = Join-Path $env:windir 'Temp\sfc-scan.txt'
        $p = Start-Process -FilePath (Join-Path $env:windir 'System32\sfc.exe') -ArgumentList '/scannow' -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tmp
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        $lines += "sfc /scannow finished, exit code $($p.ExitCode)"
    }
    $rc = Test-SystemFile
    if ($rc -eq 0) { $lines += 'System files: no integrity violations' }
    else { $lines += "System files: sfc /verifyonly exit code $rc (not 0, violations remain or sfc could not finish)" }
    if ($restart) { $lines += 'A restart is needed to finish the repair' }
    if ($state -eq 'Healthy' -and $rc -eq 0) { Write-Output 'RESULT: healthy'; Write-Output $lines; exit 0 }
    Write-Output 'RESULT: corruption found'
    Write-Output $lines
    exit 1
} catch {
    Write-Output "Check failed: $($_.Exception.Message)"
    Write-Output $lines
    exit 1
}
