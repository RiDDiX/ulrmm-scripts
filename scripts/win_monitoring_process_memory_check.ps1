# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks that the working set of all instances of a process stays below a limit.
# Variables: PROCESS process name, with or without .exe; MAX_MB memory limit in MB.
# Exit: 0 below the limit or not running, 1 above the limit, 3 bad input.
$name = ''
if ($env:PROCESS) { $name = $env:PROCESS.Trim() -replace '\.exe$', '' }
if ($name -notmatch '^[A-Za-z0-9_. -]{1,64}$') { Write-Output 'PROCESS is required: letters, digits, space, dot, dash and underscore only'; exit 3 }
$max = 0
if (-not $env:MAX_MB -or -not [int]::TryParse($env:MAX_MB.Trim(), [ref]$max) -or $max -lt 1) { Write-Output 'MAX_MB is required and must be a positive number'; exit 3 }
$procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
if ($procs.Count -eq 0) { Write-Output "OK: $name is not running"; exit 0 }
$total = ($procs | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB
$biggest = ($procs | Sort-Object -Property WorkingSet64 -Descending | Select-Object -First 1)
$line = '{0}: {1} instance(s) use {2:N0} MB in total, largest pid {3} with {4:N0} MB, limit {5} MB' -f $name, $procs.Count, $total, $biggest.Id, ($biggest.WorkingSet64 / 1MB), $max
if ($total -gt $max) { Write-Output "CRITICAL: $line"; exit 1 }
Write-Output "OK: $line"
exit 0
