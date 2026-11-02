# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports the shadow copies (restore points) per volume with count, oldest and newest copy, and the shadow storage use.
# Variables: none.
# Exit: 0 report printed, 1 failed.
try {
    $vols = @{}
    foreach ($v in Get-CimInstance Win32_Volume) { $vols[$v.DeviceID] = if ($v.DriveLetter) { $v.DriveLetter } else { $v.DeviceID } }
    $copies = @(Get-CimInstance Win32_ShadowCopy -ErrorAction SilentlyContinue)
    if ($copies.Count -eq 0) { Write-Output 'No shadow copies exist'; exit 0 }
    Write-Output "$($copies.Count) shadow copies"
    foreach ($g in ($copies | Group-Object -Property VolumeName)) {
        $label = $g.Name
        if ($vols.ContainsKey($g.Name)) { $label = $vols[$g.Name] }
        $dates = @($g.Group | ForEach-Object { $_.InstallDate } | Sort-Object)
        Write-Output ("{0}: {1} copies, oldest {2:yyyy-MM-dd HH:mm}, newest {3:yyyy-MM-dd HH:mm}" -f $label, $g.Count, $dates[0], $dates[-1])
    }
    foreach ($s in @(Get-CimInstance Win32_ShadowStorage -ErrorAction SilentlyContinue)) {
        $label = $s.Volume.DeviceID
        if ($vols.ContainsKey($label)) { $label = $vols[$label] }
        $max = 'unbounded'
        if ($s.MaxSpace -gt 0 -and $s.MaxSpace -lt 9e18) { $max = '{0:N1} GB' -f ($s.MaxSpace / 1GB) }
        Write-Output ("Storage on {0}: used {1:N1} GB, allocated {2:N1} GB, limit {3}" -f $label, ($s.UsedSpace / 1GB), ($s.AllocatedSpace / 1GB), $max)
    }
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
