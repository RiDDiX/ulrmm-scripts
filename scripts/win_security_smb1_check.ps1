# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports whether the SMBv1 server protocol is enabled and optionally disables it (server protocol and optional feature).
# Variables: DISABLE (checkbox, default false)
# Exit: 0 SMBv1 is off, 1 SMBv1 is on or could not be disabled, 3 bad input or SMB cmdlets unavailable
$ErrorActionPreference = 'Stop'
$disable = ([string]$env:DISABLE).Trim().ToLower()
if ($disable -and $disable -notin 'true', 'false') {
    Write-Output ('Bad DISABLE value: ' + $disable)
    exit 3
}
if (-not (Get-Command Get-SmbServerConfiguration -ErrorAction SilentlyContinue)) {
    Write-Output 'SMB cmdlets are not available on this system'
    exit 3
}

function Get-FeatureState {
    if (-not (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue)) { return 'unknown' }
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
        return [string]$f.State
    } catch {
        return 'unknown'
    }
}

try {
    $before = [bool](Get-SmbServerConfiguration).EnableSMB1Protocol
    $featureBefore = Get-FeatureState
    if ($disable -eq 'true') {
        if ($before) {
            Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
            Write-Output 'SMBv1 server protocol disabled'
        }
        if ($featureBefore -eq 'Enabled') {
            [void](Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart)
            Write-Output 'SMB1Protocol feature removed, takes full effect after a restart'
        }
    }
    $after = [bool](Get-SmbServerConfiguration).EnableSMB1Protocol
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
if ($after) {
    Write-Output 'FAIL: SMBv1 server protocol is enabled'
    exit 1
}
Write-Output 'OK: SMBv1 server protocol is disabled'
Write-Output ('Optional feature SMB1Protocol: ' + (Get-FeatureState))
exit 0
