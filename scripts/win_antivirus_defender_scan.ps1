# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Runs a Microsoft Defender scan and lists what it detected; Defender's own remediation settings apply.
# Variables: SCAN_TYPE (quick) quick, full or custom; SCAN_PATH ("") folder or file for a custom scan.
# Exit: 0 nothing found, 1 threats detected or scan failed, 3 bad input or Defender not available.

$type = "$env:SCAN_TYPE".Trim().ToLower()
$path = "$env:SCAN_PATH".Trim()
if (-not $type) { $type = 'quick' }
$types = @{ quick = 'QuickScan'; full = 'FullScan'; custom = 'CustomScan' }
if (-not $types.ContainsKey($type)) { Write-Output 'SCAN_TYPE must be quick, full or custom'; exit 3 }
if ($type -eq 'custom') {
    if ($path -notmatch '^[A-Za-z]:\\' -or $path -match '["*?<>|]') { Write-Output 'SCAN_PATH must be an absolute local path'; exit 3 }
    if (-not (Test-Path -LiteralPath $path)) { Write-Output "SCAN_PATH does not exist: $path"; exit 3 }
}

try {
    $null = Get-MpComputerStatus -ErrorAction Stop
} catch {
    Write-Output "Microsoft Defender is not available: $($_.Exception.Message)"
    exit 3
}

$start = Get-Date
try {
    if ($type -eq 'custom') {
        Start-MpScan -ScanType CustomScan -ScanPath $path -ErrorAction Stop
    } else {
        Start-MpScan -ScanType $types[$type] -ErrorAction Stop
    }
} catch {
    Write-Output "FAIL: scan did not run: $($_.Exception.Message)"
    exit 1
}
$minutes = [math]::Round(((Get-Date) - $start).TotalMinutes, 1)

$found = @(Get-MpThreatDetection -ErrorAction SilentlyContinue | Where-Object { $_.InitialDetectionTime -ge $start })
if ($found.Count -eq 0) {
    Write-Output "CLEAN: $type scan finished in $minutes min, nothing detected"
    exit 0
}
$names = @{}
Get-MpThreat -ErrorAction SilentlyContinue | ForEach-Object { $names[[string]$_.ThreatID] = $_.ThreatName }
Write-Output "THREATS: $($found.Count) detection(s) in a $type scan ($minutes min)"
foreach ($d in $found | Select-Object -First 20) {
    $res = ($d.Resources | Select-Object -First 1) -replace '^\w+:_', ''
    Write-Output "$($names[[string]$d.ThreatID]): $res (action $($d.ThreatStatusID))"
}
exit 1
