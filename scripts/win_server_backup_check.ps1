# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks the last Windows Server Backup run: result of the last backup and age of the last successful one.
# Variables: MAX_HOURS (26) maximum age of the last successful backup in hours.
# Exit: 0 backup ok, 1 backup too old, never run or last run failed, 3 bad input or Windows Server Backup not installed.
$max = 26
if ($env:MAX_HOURS) { if (-not [int]::TryParse($env:MAX_HOURS.Trim(), [ref]$max) -or $max -lt 1 -or $max -gt 8760) { Write-Output 'MAX_HOURS must be a number from 1 to 8760'; exit 3 } }
if (-not (Get-Command Get-WBSummary -ErrorAction SilentlyContinue)) { Write-Output 'Windows Server Backup is not installed (feature Windows-Server-Backup)'; exit 3 }
try {
    $s = Get-WBSummary -ErrorAction Stop
} catch {
    Write-Output "Cannot read the backup summary: $($_.Exception.Message)"
    exit 1
}
if (-not $s -or -not $s.LastSuccessfulBackupTime -or $s.LastSuccessfulBackupTime.Year -lt 2000) { Write-Output 'CRITICAL: no successful backup found'; exit 1 }
$age = ((Get-Date) - $s.LastSuccessfulBackupTime).TotalHours
$lastHr = [int64]$s.LastBackupResultHR
$problem = $false
if ($lastHr -ne 0) { $problem = $true }
if ($age -gt $max) { $problem = $true }
$verdict = 'OK'
if ($problem) { $verdict = 'CRITICAL' }
Write-Output ("{0}: last success {1:yyyy-MM-dd HH:mm} ({2:N1} h ago, limit {3} h), last run {4:yyyy-MM-dd HH:mm} result 0x{5:X8}" -f $verdict, $s.LastSuccessfulBackupTime, $age, $max, $s.LastBackupTime, ($lastHr -band 0xFFFFFFFFL))
if ($s.NextBackupTime) { Write-Output ("Next backup: {0:yyyy-MM-dd HH:mm}" -f $s.NextBackupTime) }
if ($problem) { exit 1 }
exit 0
