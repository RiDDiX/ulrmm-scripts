# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows, enables or disables a Windows optional feature or server role/feature. Client Windows uses the DISM cmdlets (example: NetFx3 for .NET 3.5), Windows Server uses ServerManager (example: NET-Framework-Core).
# Variables: FEATURE feature name; STATE (status) status, enable or disable.
# Exit: 0 done, 1 failed, 3 bad input, unknown feature or tooling missing.
$feature = ''
if ($env:FEATURE) { $feature = $env:FEATURE.Trim() }
if ($feature -notmatch '^[A-Za-z0-9._-]{2,100}$') { Write-Output 'FEATURE is required: letters, digits, dot, dash and underscore only'; exit 3 }
$state = 'status'
if ($env:STATE) { $state = $env:STATE.Trim().ToLower() }
if ('status', 'enable', 'disable' -notcontains $state) { Write-Output 'STATE must be status, enable or disable'; exit 3 }
$server = (Get-CimInstance Win32_OperatingSystem).ProductType -ne 1

try {
    if ($server) {
        $getF = Get-Command -Name Get-WindowsFeature -ErrorAction SilentlyContinue
        if (-not $getF) { Write-Output 'The ServerManager module is not available on this system'; exit 3 }
        try { $f = & $getF -Name $feature -ErrorAction Stop } catch { $f = $null }
        if (-not $f) { Write-Output "Unknown feature '$feature'; list names with Get-WindowsFeature"; exit 3 }
        $on = [bool]$f.Installed
        Write-Output "$($f.Name) ($($f.DisplayName)): installed=$on"
        if ($state -eq 'enable' -and -not $on) {
            $r = & (Get-Command -Name Install-WindowsFeature) -Name $feature -ErrorAction Stop
        } elseif ($state -eq 'disable' -and $on) {
            $r = & (Get-Command -Name Uninstall-WindowsFeature) -Name $feature -ErrorAction Stop
        } else { exit 0 }
        Write-Output "Success=$($r.Success), restart needed=$($r.RestartNeeded), exit code=$($r.ExitCode)"
        if ($r.Success) { exit 0 }
        exit 1
    }
    if (-not (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue)) { Write-Output 'The DISM PowerShell module is not available on this system'; exit 3 }
    try { $f = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction Stop }
    catch { Write-Output "Unknown feature '$feature'; list names with Get-WindowsOptionalFeature -Online"; exit 3 }
    $cur = $f.State.ToString()
    Write-Output "$($f.FeatureName): $cur"
    $r = $null
    if ($state -eq 'enable' -and $cur -notlike 'Enable*') {
        $r = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction Stop
    } elseif ($state -eq 'disable' -and $cur -notlike 'Disable*') {
        $r = Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction Stop
    }
    if ($r) {
        $now = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
        Write-Output "Now: $now, restart needed: $($r.RestartNeeded)"
    }
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
