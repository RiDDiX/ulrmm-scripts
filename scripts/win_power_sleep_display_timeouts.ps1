# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Sets the sleep and display timeouts of the active power plan; empty values stay unchanged, 0 means never.
# Variables: AC_SLEEP_MINUTES, DC_SLEEP_MINUTES, AC_DISPLAY_MINUTES, DC_DISPLAY_MINUTES (all empty), 0 to 1440.
# Exit: 0 done, 1 powercfg failed, 3 bad input or nothing to change.
$pc = Join-Path $env:windir 'System32\powercfg.exe'
$items = @(
    @{ Var = 'AC_SLEEP_MINUTES'; Value = $env:AC_SLEEP_MINUTES; Setting = 'standby-timeout-ac' }
    @{ Var = 'DC_SLEEP_MINUTES'; Value = $env:DC_SLEEP_MINUTES; Setting = 'standby-timeout-dc' }
    @{ Var = 'AC_DISPLAY_MINUTES'; Value = $env:AC_DISPLAY_MINUTES; Setting = 'monitor-timeout-ac' }
    @{ Var = 'DC_DISPLAY_MINUTES'; Value = $env:DC_DISPLAY_MINUTES; Setting = 'monitor-timeout-dc' }
)
$todo = @()
foreach ($i in $items) {
    $raw = $i.Value
    if (-not $raw -or -not $raw.Trim()) { continue }
    $n = 0
    if (-not [int]::TryParse($raw.Trim(), [ref]$n) -or $n -lt 0 -or $n -gt 1440) { Write-Output "$($i.Var) must be a number from 0 to 1440"; exit 3 }
    $todo += @{ Setting = $i.Setting; Value = $n; Var = $i.Var }
}
if ($todo.Count -eq 0) { Write-Output 'No timeout given, nothing to change'; exit 3 }
$rc = 0
foreach ($t in $todo) {
    $out = (& $pc /change $t.Setting ([string]$t.Value) 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -eq 0) { Write-Output "$($t.Var) set to $($t.Value)" }
    else { Write-Output "$($t.Var) failed: $out"; $rc = 1 }
}
Write-Output (& $pc /getactivescheme 2>&1 | Out-String).Trim()
exit $rc
