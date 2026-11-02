# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Resets the Windows Update components: stops the services, renames the SoftwareDistribution and catroot2 folders, clears the BITS queue and starts the services again.
# Variables: none.
# Exit: 0 done, 1 failed.
$ErrorActionPreference = 'Stop'
$names = 'wuauserv', 'bits', 'cryptsvc', 'msiserver'
$running = @()
try {
    foreach ($n in $names) {
        $s = Get-Service -Name $n -ErrorAction SilentlyContinue
        if ($s -and $s.Status -ne 'Stopped') {
            $running += $n
            $running += @($s.DependentServices | Where-Object { $_.Status -eq 'Running' } | ForEach-Object { $_.Name })
            Stop-Service -Name $n -Force -ErrorAction SilentlyContinue
            $s.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(60))
        }
    }
    $targets = @(
        (Join-Path $env:windir 'SoftwareDistribution'),
        (Join-Path $env:windir 'System32\catroot2')
    )
    foreach ($t in $targets) {
        if (-not (Test-Path -LiteralPath $t)) { Write-Output "$t does not exist, skipped"; continue }
        $old = $t + '.bak'
        if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Recurse -Force }
        Rename-Item -LiteralPath $t -NewName ((Split-Path -Leaf $t) + '.bak')
        Write-Output "Renamed $t to $old"
    }
    $q = Join-Path $env:ALLUSERSPROFILE 'Microsoft\Network\Downloader'
    $files = @(Get-ChildItem -LiteralPath $q -Filter 'qmgr*.dat' -Force -ErrorAction SilentlyContinue)
    $files | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Output "BITS queue files removed: $($files.Count)"
    $failed = @()
    foreach ($n in $running) {
        try { Start-Service -Name $n -ErrorAction Stop } catch { $failed += $n }
    }
    if ($failed.Count -gt 0) { Write-Output "Could not start: $($failed -join ', ')"; exit 1 }
    Write-Output 'Windows Update components reset, services restarted'
    exit 0
} catch {
    Write-Output "Reset failed: $($_.Exception.Message)"
    foreach ($n in $running) { Start-Service -Name $n -ErrorAction SilentlyContinue }
    exit 1
}
