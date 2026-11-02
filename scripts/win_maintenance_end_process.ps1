# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Ends every process with the given name.
# Variables: NAME process name, with or without .exe.
# Exit: 0 ended or not running, 1 a process could not be ended, 3 bad input or protected process.
$name = ''
if ($env:NAME) { $name = $env:NAME.Trim() -replace '\.exe$', '' }
if ($name -notmatch '^[A-Za-z0-9_. -]{1,64}$') { Write-Output 'NAME is required: letters, digits, space, dot, dash and underscore only'; exit 3 }
$protected = 'system', 'idle', 'registry', 'smss', 'csrss', 'wininit', 'winlogon', 'services', 'lsass', 'lsaiso', 'fontdrvhost', 'svchost', 'dwm','ulrmm-agent', 'meshagent', 'rustdesk'
if ($protected -contains $name.ToLower()) { Write-Output "'$name' is protected and not ended"; exit 3 }

$procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID })
if ($procs.Count -eq 0) { Write-Output "No process named '$name' is running"; exit 0 }
$ids = @($procs | ForEach-Object { $_.Id })
$procs | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
$left = @(Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object { $ids -contains $_.Id })
Write-Output ("Ended {0} of {1} process(es) named '{2}'" -f ($ids.Count - $left.Count), $ids.Count, $name)
if ($left.Count -gt 0) { exit 1 }
exit 0
