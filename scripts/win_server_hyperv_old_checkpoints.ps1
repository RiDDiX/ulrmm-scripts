# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists Hyper-V checkpoints older than the limit; old checkpoints slow VMs down and fill the disk.
# Variables: MAX_DAYS (7) age limit in days.
# Exit: 0 none too old, 2 old checkpoints found, 3 bad input or Hyper-V not available.
$max = 7
if ($env:MAX_DAYS) { if (-not [int]::TryParse($env:MAX_DAYS.Trim(), [ref]$max) -or $max -lt 1 -or $max -gt 3650) { Write-Output 'MAX_DAYS must be a number from 1 to 3650'; exit 3 } }
if (-not (Get-Command Get-VMSnapshot -ErrorAction SilentlyContinue)) { Write-Output 'The Hyper-V PowerShell module is not available on this system'; exit 3 }
try {
    $snaps = @(Get-VM -ErrorAction Stop | Get-VMSnapshot -ErrorAction Stop)
} catch {
    Write-Output "Cannot read the checkpoints (is this a Hyper-V host?): $($_.Exception.Message)"
    exit 3
}
$cut = (Get-Date).AddDays(-$max)
$old = @($snaps | Where-Object { $_.CreationTime -lt $cut })
if ($old.Count -eq 0) { Write-Output "OK: $($snaps.Count) checkpoint(s), none older than $max days"; exit 0 }
Write-Output "WARNING: $($old.Count) of $($snaps.Count) checkpoint(s) older than $max days"
foreach ($s in ($old | Sort-Object -Property CreationTime)) {
    Write-Output ("{0}: '{1}' created {2:yyyy-MM-dd} ({3} days old)" -f $s.VMName, $s.Name, $s.CreationTime, [int]((Get-Date) - $s.CreationTime).TotalDays)
}
exit 2
