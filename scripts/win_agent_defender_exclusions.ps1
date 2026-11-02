# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Adds Microsoft Defender exclusions for the agent: install directories, working directory and agent processes.
# Variables: none
# Exit: 0 exclusions in place, 1 Defender refused the change (for example another antivirus is active), 3 Defender cmdlets unavailable
$ErrorActionPreference = 'Stop'
if (-not (Get-Command Add-MpPreference -ErrorAction SilentlyContinue)) {
    Write-Output 'Microsoft Defender cmdlets are not available on this system'
    exit 3
}
$paths = @(
    (Join-Path $env:ProgramFiles 'ULRMM Agent'),
    (Join-Path $env:ProgramFiles 'Mesh Agent'),
    (Join-Path $env:ProgramData 'UniversalLocalRMM')
)
$procs = @('ulrmm-agent.exe', 'MeshAgent.exe')
try {
    $pref = Get-MpPreference
    $havePaths = @($pref.ExclusionPath)
    $haveProcs = @($pref.ExclusionProcess)
    foreach ($p in $paths) {
        if ($havePaths -contains $p) {
            Write-Output ('Path already excluded: ' + $p)
        } else {
            Add-MpPreference -ExclusionPath $p
            Write-Output ('Path excluded: ' + $p)
        }
    }
    foreach ($p in $procs) {
        if ($haveProcs -contains $p) {
            Write-Output ('Process already excluded: ' + $p)
        } else {
            Add-MpPreference -ExclusionProcess $p
            Write-Output ('Process excluded: ' + $p)
        }
    }
    $pref = Get-MpPreference
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
$missing = @($paths | Where-Object { @($pref.ExclusionPath) -notcontains $_ }) + @($procs | Where-Object { @($pref.ExclusionProcess) -notcontains $_ })
if ($missing.Count -gt 0) {
    Write-Output ('FAIL: not visible after the change: ' + ($missing -join ', '))
    exit 1
}
Write-Output 'OK: all agent exclusions are in place'
exit 0
