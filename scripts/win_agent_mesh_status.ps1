# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports the state of the MeshCentral agent service and optionally restarts it.
# Variables: RESTART (checkbox, default false)
# Exit: 0 service running, 1 service not running, 3 bad input or Mesh Agent not installed
$ErrorActionPreference = 'Stop'
$restartRaw = ([string]$env:RESTART).Trim().ToLower()
if ($restartRaw -and $restartRaw -notin 'true', 'false') {
    Write-Output ('Bad RESTART value: ' + $restartRaw)
    exit 3
}
$svc = Get-Service -Name 'Mesh Agent' -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Output 'Service "Mesh Agent" is not installed'
    exit 3
}
if ($restartRaw -eq 'true') {
    try {
        Restart-Service -Name 'Mesh Agent' -Force
        Write-Output 'Mesh Agent restarted'
    } catch {
        Write-Output ('FAIL: restart failed: ' + $_.Exception.Message)
    }
    $svc = Get-Service -Name 'Mesh Agent'
}
$wmi = Get-CimInstance -ClassName Win32_Service -Filter "Name='Mesh Agent'" -ErrorAction SilentlyContinue
$proc = @(Get-Process -Name 'MeshAgent' -ErrorAction SilentlyContinue)
if ($svc.Status -eq 'Running') {
    Write-Output 'OK: Mesh Agent is running'
} else {
    Write-Output ('FAIL: Mesh Agent is ' + $svc.Status)
}
Write-Output ('Start type: ' + $svc.StartType)
if ($wmi) {
    Write-Output ('Path: ' + $wmi.PathName)
    $exe = ([string]$wmi.PathName).Trim().Trim('"')
    if ($exe -match '^"?([^"]+?\.exe)') { $exe = $Matches[1] }
    if (Test-Path -LiteralPath $exe) {
        Write-Output ('File version: ' + (Get-Item -LiteralPath $exe).VersionInfo.FileVersion)
    }
}
if ($proc.Count -gt 0) {
    Write-Output ('Process started: {0:yyyy-MM-dd HH:mm}' -f $proc[0].StartTime)
}
if ($svc.Status -ne 'Running') { exit 1 }
exit 0
