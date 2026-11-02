# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows the time zone or sets it by Windows time zone id (for example W. Europe Standard Time).
# Variables: TIMEZONE time zone id; empty reports the current zone and the clock.
# Exit: 0 done, 1 failed, 3 unknown time zone id.
$id = ''
if ($env:TIMEZONE) { $id = $env:TIMEZONE.Trim() }
try {
    $cur = Get-TimeZone
    if (-not $id) {
        Write-Output "Time zone: $($cur.Id) ($($cur.DisplayName))"
        Write-Output "Local time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        exit 0
    }
    $zone = Get-TimeZone -ListAvailable | Where-Object { $_.Id -ieq $id }
    if (-not $zone) { Write-Output "Unknown time zone id '$id'; list them with Get-TimeZone -ListAvailable"; exit 3 }
    if ($cur.Id -eq $zone.Id) { Write-Output "Time zone is already $($zone.Id)"; exit 0 }
    Set-TimeZone -Id $zone.Id -ErrorAction Stop
    Write-Output "Time zone changed from $($cur.Id) to $($zone.Id)"
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
