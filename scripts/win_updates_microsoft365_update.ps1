# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Starts an update of Microsoft 365 Apps (Click-to-Run) through OfficeC2RClient.exe; the update then continues in the background.
# Variables: FORCE_CLOSE (false) close open Office apps so the update does not wait.
# Exit: 0 update started, 1 failed, 3 Click-to-Run Office is not installed.
$client = Join-Path $env:CommonProgramFiles 'microsoft shared\ClickToRun\OfficeC2RClient.exe'
if (-not (Test-Path -LiteralPath $client)) {
    $x86 = ${env:CommonProgramFiles(x86)}
    if ($x86) { $client = Join-Path $x86 'microsoft shared\ClickToRun\OfficeC2RClient.exe' }
}
if (-not (Test-Path -LiteralPath $client)) { Write-Output 'Click-to-Run Office is not installed (OfficeC2RClient.exe not found)'; exit 3 }
$cfg = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction SilentlyContinue
if ($cfg) { Write-Output "Version before: $($cfg.VersionToReport), channel: $($cfg.CDNBaseUrl)" }
$force = 'false'
if ($env:FORCE_CLOSE -eq 'true') { $force = 'true' }
try {
    $p = Start-Process -FilePath $client -ArgumentList @('/update', 'user', 'displaylevel=false', "forceappshutdown=$force") -Wait -PassThru
    Write-Output "OfficeC2RClient exit code $($p.ExitCode); the update continues in the background (force close: $force)"
    if ($p.ExitCode -eq 0) { exit 0 }
    exit 1
} catch {
    Write-Output "Failed to start the update: $($_.Exception.Message)"
    exit 1
}
