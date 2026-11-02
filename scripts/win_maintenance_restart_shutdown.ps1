# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Restarts or shuts down the computer after an optional delay, or cancels a pending shutdown.
# Variables: MODE (restart) restart, shutdown or cancel; DELAY_MINUTES (0) wait time, 0 to 1440; MESSAGE message shown to users; FORCE (false) close applications without asking (Windows always does so with a delay above 0).
# Exit: 0 done, 1 shutdown.exe failed, 3 bad input.
$mode = 'restart'
if ($env:MODE) { $mode = $env:MODE.Trim().ToLower() }
if ('restart', 'shutdown', 'cancel' -notcontains $mode) { Write-Output 'MODE must be restart, shutdown or cancel'; exit 3 }
$delay = 0
if ($env:DELAY_MINUTES) {
    if (-not [int]::TryParse($env:DELAY_MINUTES.Trim(), [ref]$delay) -or $delay -lt 0 -or $delay -gt 1440) { Write-Output 'DELAY_MINUTES must be a number from 0 to 1440'; exit 3 }
}
$msg = ''
if ($env:MESSAGE) { $msg = $env:MESSAGE.Trim() -replace '["\r\n]', ' ' }
if ($msg.Length -gt 400) { Write-Output 'MESSAGE is longer than 400 characters'; exit 3 }
if ($msg -match '^[/-]') { Write-Output 'MESSAGE must not start with / or -'; exit 3 }

$sd = Join-Path $env:windir 'System32\shutdown.exe'
$arguments = @()
switch ($mode) {
    'cancel' { $arguments = @('/a') }
    'restart' { $arguments = @('/r', '/t', [string]($delay * 60)) }
    'shutdown' { $arguments = @('/s', '/t', [string]($delay * 60)) }
}
if ($mode -ne 'cancel') {
    if ($env:FORCE -eq 'true') { $arguments += '/f' }
    if ($msg) { $arguments += '/c'; $arguments += $msg }
}
$out = & $sd @arguments 2>&1
$rc = $LASTEXITCODE
if ($mode -eq 'cancel') {
    if ($rc -eq 0) { Write-Output 'Pending shutdown cancelled'; exit 0 }
    if ($rc -eq 1116) { Write-Output 'No shutdown was pending'; exit 0 }
} elseif ($rc -eq 0) {
    Write-Output "$mode scheduled in $delay minute(s)"
    exit 0
}
Write-Output "shutdown.exe exit code ${rc}: $($out -join ' ')"
exit 1
