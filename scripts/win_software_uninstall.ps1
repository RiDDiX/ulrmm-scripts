# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Uninstalls one program by its exact display name: MSI packages with msiexec /x /qn, other programs only when they provide a QuietUninstallString. Refuses when several entries match.
# Variables: NAME exact display name (see the find installed software script); DRY_RUN (false) only show what would run.
# Exit: 0 uninstalled or not installed, 1 failed or several matches, 3 bad input or no silent uninstall available.
$name = ''
if ($env:NAME) { $name = $env:NAME.Trim() }
if (-not $name) { Write-Output 'NAME is required'; exit 3 }
$dry = $false
if ($env:DRY_RUN) {
    if ('true', 'false' -notcontains $env:DRY_RUN.Trim()) { Write-Output 'DRY_RUN must be true or false'; exit 3 }
    $dry = $env:DRY_RUN.Trim() -eq 'true'
}
$roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
$hits = @()
foreach ($r in $roots) {
    foreach ($k in @(Get-ChildItem -LiteralPath $r -ErrorAction SilentlyContinue)) {
        $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
        if ($p.DisplayName -and $p.DisplayName -ieq $name) { $hits += [pscustomobject]@{ Key = $k.PSChildName; Path = $k.PSPath; Props = $p } }
    }
}
if ($hits.Count -eq 0) { Write-Output "'$name' is not installed"; exit 0 }
if ($hits.Count -gt 1) {
    Write-Output "$($hits.Count) entries match '$name', refusing to guess:"
    $hits | ForEach-Object { Write-Output ("  {0} {1} ({2})" -f $_.Props.DisplayName, $_.Props.DisplayVersion, $_.Key) }
    exit 1
}
$h = $hits[0]
$cmd = $null
$file = $null
if ($h.Props.WindowsInstaller -eq 1 -and $h.Key -match '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$') {
    $file = Join-Path $env:windir 'System32\msiexec.exe'
    $cmd = "/x $($h.Key) /qn /norestart"
} elseif ($h.Props.QuietUninstallString) {
    $file = Join-Path $env:windir 'System32\cmd.exe'
    $cmd = '/c "' + $h.Props.QuietUninstallString + '"'
} else {
    Write-Output "'$name' is not an MSI package and has no QuietUninstallString, it cannot be removed silently"
    exit 3
}
Write-Output "Found $($h.Props.DisplayName) $($h.Props.DisplayVersion): $file $cmd"
if ($dry) { Write-Output 'Dry run, nothing removed'; exit 0 }
try {
    $p = Start-Process -FilePath $file -ArgumentList $cmd -Wait -PassThru -WindowStyle Hidden
    $gone = -not (Test-Path -LiteralPath $h.Path)
    Write-Output "Uninstaller exit code $($p.ExitCode), registry entry removed: $gone"
    if ($p.ExitCode -eq 3010) { Write-Output 'A restart is needed to finish'; exit 0 }
    if ($p.ExitCode -eq 0 -or $gone) { exit 0 }
    exit 1
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
