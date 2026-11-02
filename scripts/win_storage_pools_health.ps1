# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks the health of Storage Spaces: storage pools, virtual disks and the physical disks in the pools.
# Variables: none.
# Exit: 0 healthy or no pools, 1 something is unhealthy, 2 something is degraded or has a warning, 3 Storage module missing.
if (-not (Get-Command Get-StoragePool -ErrorAction SilentlyContinue)) { Write-Output 'The Storage module is not available on this system'; exit 3 }
try {
    $pools = @(Get-StoragePool -IsPrimordial $false -ErrorAction Stop)
    if ($pools.Count -eq 0) { Write-Output 'No storage pools configured'; exit 0 }
    $level = 0
    $lines = @()
    function Add-Line([string]$Kind, [string]$Name, $Health, $Op) {
        $h = [string]$Health
        if ($h -ne 'Healthy') { $script:level = [math]::Max($script:level, $(if ($h -eq 'Warning') { 1 } else { 2 })) }
        $script:lines += "$Kind ${Name}: health $h, status $(@($Op) -join '/')"
    }
    foreach ($p in $pools) {
        Add-Line 'Pool' $p.FriendlyName $p.HealthStatus $p.OperationalStatus
        foreach ($v in @(Get-VirtualDisk -StoragePool $p -ErrorAction SilentlyContinue)) { Add-Line 'Virtual disk' $v.FriendlyName $v.HealthStatus $v.OperationalStatus }
        foreach ($d in @(Get-PhysicalDisk -StoragePool $p -ErrorAction SilentlyContinue)) { Add-Line 'Physical disk' $d.FriendlyName $d.HealthStatus $d.OperationalStatus }
    }
    switch ($level) {
        0 { Write-Output "OK: $($pools.Count) pool(s) healthy"; $rc = 0 }
        1 { Write-Output 'WARNING: a storage object has a warning'; $rc = 2 }
        default { Write-Output 'CRITICAL: a storage object is unhealthy'; $rc = 1 }
    }
    $lines | ForEach-Object { Write-Output $_ }
    exit $rc
} catch {
    Write-Output "Check failed: $($_.Exception.Message)"
    exit 1
}
