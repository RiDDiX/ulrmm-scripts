# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists installed programs from the 64-bit and 32-bit uninstall registry views, optionally filtered by name.
# Variables: NAME part of the display name, case-insensitive; empty lists everything.
# Exit: 0 found or listed, 1 nothing matches.
$filter = ''
if ($env:NAME) { $filter = $env:NAME.Trim() }
$roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
$rows = @()
foreach ($r in $roots) {
    foreach ($k in @(Get-ChildItem -LiteralPath $r -ErrorAction SilentlyContinue)) {
        $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
        if (-not $p.DisplayName -or $p.SystemComponent -eq 1 -or $p.ParentKeyName) { continue }
        if ($filter -and $p.DisplayName.IndexOf($filter, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        $arch = 'x64'
        if ($r -like '*WOW6432Node*') { $arch = 'x86' }
        $rows += [pscustomobject]@{ Name = $p.DisplayName; Version = $p.DisplayVersion; Publisher = $p.Publisher; Date = $p.InstallDate; Arch = $arch }
    }
}
if ($rows.Count -eq 0) { Write-Output "No installed program matches '$filter'"; exit 1 }
Write-Output "$($rows.Count) installed program(s) (machine-wide entries only)"
foreach ($x in ($rows | Sort-Object -Property Name, Arch)) {
    Write-Output ("{0} | {1} | {2} | {3} | {4}" -f $x.Name, $x.Version, $x.Publisher, $x.Date, $x.Arch)
}
exit 0
