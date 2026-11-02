# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Undoes the automatic update policy of the RMM agent: removes the AUOptions value it writes under the Windows Update policy key, so Windows manages updates again.
# Variables: none.
# Exit: 0 done or already in place, 1 failed.
$key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
try {
    if (-not (Test-Path -LiteralPath $key)) { Write-Output 'No automatic update policy key, nothing to restore'; exit 0 }
    $p = Get-ItemProperty -LiteralPath $key
    if ($null -ne $p.AUOptions) {
        Remove-ItemProperty -LiteralPath $key -Name AUOptions -ErrorAction Stop
        Write-Output "Removed AUOptions ($($p.AUOptions)) from the Windows Update policy"
    } else {
        Write-Output 'AUOptions is not set, already in place'
    }
    $left = @((Get-Item -LiteralPath $key).Property)
    $sub = @(Get-ChildItem -LiteralPath $key -ErrorAction SilentlyContinue)
    if ($left.Count -eq 0 -and $sub.Count -eq 0) {
        Remove-Item -LiteralPath $key -ErrorAction Stop
        Write-Output 'Removed the empty policy key'
    } elseif ($left.Count -gt 0) {
        Write-Output "Other policy values remain and were not touched: $($left -join ', ')"
    }
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
