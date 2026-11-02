# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists Windows Installer (MSI) installs, removals and reconfigurations of the last hours from the Application log; programs with their own installer are not recorded there.
# Variables: HOURS (24) look back in hours.
# Exit: 0 report printed, 3 bad input.
$hours = 24
if ($env:HOURS) { if (-not [int]::TryParse($env:HOURS.Trim(), [ref]$hours) -or $hours -lt 1 -or $hours -gt 8760) { Write-Output 'HOURS must be a number from 1 to 8760'; exit 3 } }
$kinds = @{ 1033 = 'installed'; 1034 = 'removed'; 1035 = 'reconfigured' }
$events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'MsiInstaller'; Id = 1033, 1034, 1035; StartTime = (Get-Date).AddHours(-$hours) } -ErrorAction SilentlyContinue)
if ($events.Count -eq 0) { Write-Output "No MSI install, removal or change in the last $hours hours"; exit 0 }
Write-Output "$($events.Count) MSI change(s) in the last $hours hours"
foreach ($e in ($events | Sort-Object -Property TimeCreated)) {
    $p = $e.Properties
    $product = ''
    $version = ''
    $status = ''
    if ($p.Count -ge 4) { $product = [string]$p[0].Value; $version = [string]$p[1].Value; $status = [string]$p[3].Value }
    Write-Output ("{0:yyyy-MM-dd HH:mm} {1}: {2} {3} (status {4})" -f $e.TimeCreated, $kinds[[int]$e.Id], $product, $version, $status)
}
exit 0
