# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists the top processes by CPU use (measured over 3 seconds) or by memory (working set).
# Variables: TOP (10) number of processes; SORT (cpu) cpu or memory.
# Exit: 0 report printed, 3 bad input.
$top = 10
if ($env:TOP) { if (-not [int]::TryParse($env:TOP.Trim(), [ref]$top) -or $top -lt 1 -or $top -gt 100) { Write-Output 'TOP must be a number from 1 to 100'; exit 3 } }
$sort = 'cpu'
if ($env:SORT) { $sort = $env:SORT.Trim().ToLower() }
if ('cpu', 'memory' -notcontains $sort) { Write-Output 'SORT must be cpu or memory'; exit 3 }
$cores = [int](Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$first = @{}
foreach ($p in Get-Process) { if ($null -ne $p.CPU) { $first[$p.Id] = $p.CPU } }
$sec = 3
Start-Sleep -Seconds $sec
$rows = foreach ($p in Get-Process) {
    $pct = 0.0
    if ($first.ContainsKey($p.Id) -and $null -ne $p.CPU) { $pct = [math]::Round(($p.CPU - $first[$p.Id]) / $sec / $cores * 100, 1) }
    [pscustomobject]@{ Name = $p.ProcessName; Id = $p.Id; Cpu = $pct; MemMB = [math]::Round($p.WorkingSet64 / 1MB, 0) }
}
if ($sort -eq 'cpu') { $rows = $rows | Sort-Object -Property Cpu, MemMB -Descending } else { $rows = $rows | Sort-Object -Property MemMB -Descending }
Write-Output "Top $top processes by $sort ($cores logical CPUs, CPU is share of the whole machine)"
foreach ($r in ($rows | Select-Object -First $top)) {
    Write-Output ('{0,-30} pid {1,6}  cpu {2,5}%  mem {3,6} MB' -f $r.Name, $r.Id, $r.Cpu, $r.MemMB)
}
exit 0
