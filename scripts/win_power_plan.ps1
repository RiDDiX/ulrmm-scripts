# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows the active power plan or activates one; a missing built-in plan is recreated from its template.
# Variables: PLAN (status) status, balanced, high performance, power saver or ultimate.
# Exit: 0 done, 1 failed, 3 bad input.
$plan = 'status'
if ($env:PLAN) { $plan = $env:PLAN.Trim().ToLower() }
$guids = @{
    'balanced'         = '381b4222-f694-41f0-9685-ff5bb260df2e'
    'high performance' = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    'power saver'      = 'a1841308-3541-4fab-bc81-f71556f20b4a'
    'ultimate'         = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
}
if ($plan -ne 'status' -and -not $guids.ContainsKey($plan)) { Write-Output 'PLAN must be status, balanced, high performance, power saver or ultimate'; exit 3 }
$pc = Join-Path $env:windir 'System32\powercfg.exe'
$guidRe = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

function Get-Active {
    $line = (& $pc /getactivescheme 2>&1 | Out-String).Trim()
    $m = [regex]::Match($line, $guidRe)
    return @{ Guid = $m.Value.ToLower(); Text = $line }
}

$active = Get-Active
if ($plan -eq 'status') { Write-Output $active.Text; exit 0 }
$want = $guids[$plan]
if ($active.Guid -eq $want) { Write-Output "Already active: $($active.Text)"; exit 0 }

$list = (& $pc /list 2>&1 | Out-String).ToLower()
$target = $want
if ($list -notmatch [regex]::Escape($want)) {
    $dup = (& $pc /duplicatescheme $want $want 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { $dup = (& $pc /duplicatescheme $want 2>&1 | Out-String) }
    $m = [regex]::Match($dup, $guidRe)
    if ($LASTEXITCODE -ne 0 -or -not $m.Success) { Write-Output "The plan '$plan' does not exist and could not be created: $($dup.Trim())"; exit 1 }
    $target = $m.Value
    Write-Output "Created the '$plan' plan"
}
$out = (& $pc /setactive $target 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { Write-Output "Could not activate the plan: $out"; exit 1 }
Write-Output "Activated: $((Get-Active).Text)"
exit 0
