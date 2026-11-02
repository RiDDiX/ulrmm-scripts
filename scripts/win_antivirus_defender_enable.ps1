# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Turns Microsoft Defender real-time protection back on and restores the default protection settings
#   (behavior monitoring, download and script scanning, cloud protection, sample submission). Exclusions are kept.
# Variables: none.
# Exit: 0 real-time protection on, 1 still off afterwards, 3 Defender not available or another antivirus is active.

try {
    $s = Get-MpComputerStatus -ErrorAction Stop
    $pref = Get-MpPreference -ErrorAction Stop
} catch {
    Write-Output "Microsoft Defender is not available: $($_.Exception.Message)"
    exit 3
}

$other = @()
try {
    $other = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop |
            Where-Object { $_.displayName -notmatch '^(Windows|Microsoft) Defender' -and ($_.productState -band 0x1000) } |
            ForEach-Object { $_.displayName })
} catch {
    $other = @()
}
if ($other.Count -gt 0) {
    Write-Output "Not changed: $($other -join ', ') is the active antivirus, Defender stays off while it is installed"
    exit 3
}

# Group Policy wins over Set-MpPreference; report it instead of fighting it.
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
$checks = @(
    @($pol, 'DisableAntiSpyware'), @($pol, 'DisableAntiVirus'),
    @("$pol\Real-Time Protection", 'DisableRealtimeMonitoring'), @("$pol\Real-Time Protection", 'DisableBehaviorMonitoring'),
    @("$pol\Real-Time Protection", 'DisableIOAVProtection'), @("$pol\Real-Time Protection", 'DisableScriptScanning'),
    @("$pol\Real-Time Protection", 'DisableOnAccessProtection'))
foreach ($c in $checks) {
    $v = (Get-ItemProperty -Path $c[0] -Name $c[1] -ErrorAction SilentlyContinue).($c[1])
    if ($v -eq 1) { Write-Output "Policy sets $($c[1])=1 ($($c[0])); change the GPO or local policy" }
}

$wanted = [ordered]@{
    DisableRealtimeMonitoring = $false
    DisableBehaviorMonitoring = $false
    DisableIOAVProtection     = $false
    DisableScriptScanning     = $false
    DisableBlockAtFirstSeen   = $false
    MAPSReporting             = 2
    SubmitSamplesConsent      = 1
}
$set = @{}
foreach ($k in $wanted.Keys) {
    if ($pref.$k -ne $wanted[$k]) {
        $set[$k] = $wanted[$k]
        Write-Output "Changing $k from $($pref.$k) to $($wanted[$k])"
    }
}
if ($set.Count -gt 0) {
    try {
        Set-MpPreference @set -ErrorAction Stop
    } catch {
        Write-Output "Set-MpPreference failed: $($_.Exception.Message)"
    }
} else {
    Write-Output 'Protection settings already at their defaults'
}
Write-Output "Exclusions kept: $(@($pref.ExclusionPath).Count) path(s), $(@($pref.ExclusionProcess).Count) process(es), $(@($pref.ExclusionExtension).Count) extension(s)"

Start-Sleep -Seconds 3
$s = Get-MpComputerStatus
if ($s.RealTimeProtectionEnabled -and $s.AntivirusEnabled) {
    Write-Output "Real-time protection is on (tamper protection $($s.IsTamperProtected))"
    exit 0
}
Write-Output "Real-time protection is still off (antivirus enabled $($s.AntivirusEnabled), mode '$($s.AMRunningMode)')"
exit 1
