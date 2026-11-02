# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists services set to start automatically that are not running; trigger-start services and delayed services that are not due yet are ignored.
# Variables: EXCLUDE (edgeupdate,gupdate,MapsBroker) services to ignore, comma or line separated, name or display name, wildcards allowed.
# Exit: 0 all running, 1 at least one service is stopped.
$list = 'edgeupdate,gupdate,MapsBroker'
if ($env:EXCLUDE) { $list = $env:EXCLUDE }
$exclude = @($list -split '[,\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$os = Get-CimInstance Win32_OperatingSystem
$upMin = ((Get-Date) - $os.LastBootUpTime).TotalMinutes
$bad = @()
$services = Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'"
foreach ($s in $services) {
    $reg = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $s.Name
    if (Test-Path -LiteralPath (Join-Path $reg 'TriggerInfo')) { continue }
    $delayed = (Get-ItemProperty -LiteralPath $reg -Name DelayedAutostart -ErrorAction SilentlyContinue).DelayedAutostart
    if ($delayed -eq 1 -and $upMin -lt 15) { continue }
    $skip = $false
    foreach ($e in $exclude) { if ($s.Name -like $e -or $s.DisplayName -like $e) { $skip = $true } }
    if (-not $skip) { $bad += $s }
}
if ($bad.Count -eq 0) { Write-Output 'OK: all automatic services are running'; exit 0 }
Write-Output "$($bad.Count) automatic service(s) not running"
foreach ($s in ($bad | Sort-Object -Property Name)) {
    Write-Output ("{0} ({1}): {2}, exit code {3}" -f $s.Name, $s.DisplayName, $s.State, $s.ExitCode)
}
exit 1
