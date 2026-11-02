# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks Microsoft Defender Antivirus: engine running, real-time protection and signature age.
# Variables: WARN_DAYS (2), FAIL_DAYS (7) signature age thresholds in days.
# Exit: 0 ok or another antivirus is active, 1 failing, 2 warning, 3 bad input or Defender not available.

$warnText = "$env:WARN_DAYS".Trim()
$failText = "$env:FAIL_DAYS".Trim()
if (-not $warnText) { $warnText = '2' }
if (-not $failText) { $failText = '7' }
if ($warnText -notmatch '^\d{1,3}$' -or $failText -notmatch '^\d{1,3}$' -or [int]$warnText -gt [int]$failText) {
    Write-Output 'WARN_DAYS and FAIL_DAYS must be whole numbers with WARN_DAYS <= FAIL_DAYS'
    exit 3
}

try {
    $s = Get-MpComputerStatus -ErrorAction Stop
} catch {
    Write-Output "Microsoft Defender is not available: $($_.Exception.Message)"
    exit 3
}

$mode = "$($s.AMRunningMode)"
$age = [int64]$s.AntivirusSignatureAge
$detail = "mode '$mode', real-time $($s.RealTimeProtectionEnabled), signatures $age day(s) old ($($s.AntivirusSignatureVersion)), tamper protection $($s.IsTamperProtected)"

if (-not $s.AntivirusEnabled -or $mode -match 'Passive|Not running') {
    $other = @()
    try {
        $other = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop |
                Where-Object { $_.displayName -notmatch '^(Windows|Microsoft) Defender' -and ($_.productState -band 0x1000) } |
                ForEach-Object { $_.displayName })
    } catch {
        $other = @()
    }
    if ($other.Count -gt 0) {
        Write-Output "OK: Defender is not the active antivirus, $($other -join ', ') is"
        Write-Output $detail
        exit 0
    }
    Write-Output 'FAIL: Defender antivirus is off and no other antivirus is active'
    $rc = 1
} elseif (-not $s.RealTimeProtectionEnabled) {
    Write-Output 'FAIL: real-time protection is off'
    $rc = 1
} elseif ($age -ge [int]$failText) {
    Write-Output "FAIL: signatures are $age day(s) old"
    $rc = 1
} elseif ($age -ge [int]$warnText) {
    Write-Output "WARNING: signatures are $age day(s) old"
    $rc = 2
} else {
    Write-Output 'OK: Defender antivirus active and current'
    $rc = 0
}
Write-Output $detail
Write-Output "Engine $($s.AMEngineVersion), platform $($s.AMProductVersion), last quick scan $($s.QuickScanAge) day(s) ago"
exit $rc
