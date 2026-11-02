# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Stops the print spooler, deletes the queued print jobs and starts the spooler again.
# Variables: none.
# Exit: 0 done, 1 failed, 3 no print spooler on this system.
$svc = Get-Service -Name Spooler -ErrorAction SilentlyContinue
if (-not $svc) { Write-Output 'The Print Spooler service does not exist on this system'; exit 3 }
$deps = @($svc.DependentServices | Where-Object { $_.Status -eq 'Running' } | ForEach-Object { $_.Name })
try {
    if ($svc.Status -ne 'Stopped') {
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        try { $svc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30)) }
        catch {
            Get-Process -Name spoolsv -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    }
    $dir = Join-Path $env:windir 'System32\spool\PRINTERS'
    $jobs = @(Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction SilentlyContinue)
    $removed = 0
    foreach ($j in $jobs) {
        Remove-Item -LiteralPath $j.FullName -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $j.FullName)) { $removed++ }
    }
    Start-Service -Name Spooler -ErrorAction Stop
    foreach ($d in $deps) { Start-Service -Name $d -ErrorAction SilentlyContinue }
    $svc.Refresh()
    Write-Output "Spooler restarted, $removed of $($jobs.Count) queue files removed, service is $($svc.Status)"
    if ($removed -lt $jobs.Count) { exit 1 }
    exit 0
} catch {
    Write-Output "Spooler reset failed: $($_.Exception.Message)"
    Start-Service -Name Spooler -ErrorAction SilentlyContinue
    foreach ($d in $deps) { Start-Service -Name $d -ErrorAction SilentlyContinue }
    exit 1
}
