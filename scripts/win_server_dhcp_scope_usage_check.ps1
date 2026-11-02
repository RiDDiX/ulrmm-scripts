# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks the address usage of every IPv4 DHCP scope on this server.
# Variables: WARN_PERCENT (85) usage that counts as a warning.
# Exit: 0 ok, 1 a scope has no free address left, 2 a scope is above the warning level, 3 bad input or no DHCP server role.
$warn = 85
if ($env:WARN_PERCENT) { if (-not [int]::TryParse($env:WARN_PERCENT.Trim(), [ref]$warn) -or $warn -lt 1 -or $warn -gt 100) { Write-Output 'WARN_PERCENT must be a number from 1 to 100'; exit 3 } }
if (-not (Get-Command Get-DhcpServerv4ScopeStatistics -ErrorAction SilentlyContinue)) { Write-Output 'The DHCP Server role or its PowerShell module is not installed'; exit 3 }
if (-not (Get-Service -Name DHCPServer -ErrorAction SilentlyContinue)) { Write-Output 'The DHCP Server role is not installed on this machine (only the management tools)'; exit 3 }
try {
    $stats = @(Get-DhcpServerv4ScopeStatistics -ErrorAction Stop)
} catch {
    Write-Output "Cannot read the DHCP scopes: $($_.Exception.Message)"
    exit 1
}
if ($stats.Count -eq 0) { Write-Output 'No IPv4 DHCP scopes configured'; exit 0 }
$names = @{}
foreach ($sc in @(Get-DhcpServerv4Scope -ErrorAction SilentlyContinue)) { $names[[string]$sc.ScopeId] = $sc.Name }
$level = 0
$lines = @()
foreach ($s in ($stats | Sort-Object -Property PercentageInUse -Descending)) {
    $pct = [math]::Round([double]$s.PercentageInUse, 1)
    $tag = 'ok'
    if ($s.Free -le 0) { $tag = 'FULL'; $level = 2 } elseif ($pct -ge $warn) { $tag = 'WARN'; if ($level -lt 1) { $level = 1 } }
    $lines += ("{0} {1} ({2}): {3}% in use, {4} in use, {5} free" -f $tag, $s.ScopeId, $names[[string]$s.ScopeId], $pct, $s.InUse, $s.Free)
}
switch ($level) {
    0 { Write-Output "OK: $($stats.Count) scope(s) below $warn% in use"; $rc = 0 }
    1 { Write-Output "WARNING: a scope is above $warn% in use"; $rc = 2 }
    default { Write-Output 'CRITICAL: a scope has no free address'; $rc = 1 }
}
$lines | ForEach-Object { Write-Output $_ }
exit $rc
