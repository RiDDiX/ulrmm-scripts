# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows, enables or disables hibernation (hiberfil.sys). Disabling it also turns off fast startup.
# Variables: STATE (status) status, on or off.
# Exit: 0 done, 1 powercfg failed, 3 bad input.
$state = 'status'
if ($env:STATE) { $state = $env:STATE.Trim().ToLower() }
if ('status', 'on', 'off' -notcontains $state) { Write-Output 'STATE must be status, on or off'; exit 3 }
$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'

function Get-Hibernate {
    $p = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
    if ($null -ne $p.HibernateEnabled) { return [bool]$p.HibernateEnabled }
    [bool]$p.HibernateEnabledDefault
}

$cur = Get-Hibernate
if ($state -eq 'status') {
    Write-Output "Hibernation enabled: $cur"
    exit 0
}
if (($state -eq 'on') -eq $cur) { Write-Output "Hibernation is already $state"; exit 0 }
$out = (& (Join-Path $env:windir 'System32\powercfg.exe') /hibernate $state 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { Write-Output "powercfg failed (exit $LASTEXITCODE): $out"; exit 1 }
$now = Get-Hibernate
Write-Output "Hibernation turned $state, now enabled: $now"
if ($now -ne ($state -eq 'on')) { exit 1 }
exit 0
