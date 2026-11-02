# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Runs winget as SYSTEM: list packages with an update, upgrade all, or install, upgrade or uninstall one package (machine scope, agreements accepted).
# Variables: ACTION (list) list, upgrade all, install, upgrade or uninstall; PACKAGE_ID exact winget id, for example Mozilla.Firefox (not needed for list and upgrade all).
# Exit: 0 done or nothing to do, 1 winget failed, 3 bad input or winget not available.
$action = 'list'
if ($env:ACTION) { $action = $env:ACTION.Trim().ToLower() }
if ('list', 'upgrade all', 'install', 'upgrade', 'uninstall' -notcontains $action) { Write-Output 'ACTION must be list, upgrade all, install, upgrade or uninstall'; exit 3 }
$id = ''
if ($env:PACKAGE_ID) { $id = $env:PACKAGE_ID.Trim() }
if ($action -in 'install', 'upgrade', 'uninstall') {
    if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{1,127}$') { Write-Output 'PACKAGE_ID is required, for example Mozilla.Firefox'; exit 3 }
}

$exe = $null
$apps = Join-Path $env:ProgramFiles 'WindowsApps'
$dirs = @(Get-ChildItem -Path (Join-Path $apps 'Microsoft.DesktopAppInstaller_*__8wekyb3d8bbwe') -Directory -ErrorAction SilentlyContinue)
$best = $null
foreach ($d in $dirs) {
    if ($d.Name -notmatch '_(x64|arm64)__') { continue }
    $ver = $null
    if ($d.Name -match '_([0-9.]+)_') { $ver = [version]$Matches[1] }
    if (-not (Test-Path -LiteralPath (Join-Path $d.FullName 'winget.exe'))) { continue }
    if (-not $best -or $ver -gt $best.Ver) { $best = @{ Ver = $ver; Path = (Join-Path $d.FullName 'winget.exe') } }
}
if ($best) { $exe = $best.Path }
if (-not $exe) { Write-Output 'winget is not available on this system (needs Windows 10 1809+ or 11 with App Installer; not on Server 2016/2019 or LTSC without it)'; exit 3 }

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { Write-Verbose 'no console to set the encoding on' }
$common = @('--accept-source-agreements', '--disable-interactivity')
$pkg = @('--id', $id, '--exact', '--silent', '--scope', 'machine', '--accept-package-agreements')
switch ($action) {
    'list' { $arguments = @('upgrade') + $common }
    'upgrade all' { $arguments = @('upgrade', '--all', '--silent', '--scope', 'machine', '--accept-package-agreements') + $common }
    'install' { $arguments = @('install') + $pkg + $common }
    'upgrade' { $arguments = @('upgrade') + $pkg + $common }
    'uninstall' { $arguments = @('uninstall', '--id', $id, '--exact', '--silent', '--scope', 'machine') + $common }
}
$old = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$out = & $exe @arguments 2>&1 | ForEach-Object { [string]$_ }
$rc = $LASTEXITCODE
$ErrorActionPreference = $old
$blocks = '[' + [char]0x2580 + '-' + [char]0x259F + ']'
foreach ($l in $out) {
    if ($l -match '^\s*[-\\|/]?\s*$' -or $l -match $blocks) { continue }
    Write-Output $l.TrimEnd()
}
if ($rc -eq 0) { Write-Output 'winget finished successfully'; exit 0 }
if ($rc -eq -1978335189) { Write-Output "winget: no applicable update (code $rc)"; exit 0 }
if ($rc -eq -1978335135 -and $action -eq 'install') { Write-Output "$id is already installed"; exit 0 }
if ($rc -eq -1978335212 -and $action -eq 'uninstall') { Write-Output "No installed package $id found in machine scope, nothing to remove"; exit 0 }
if ($rc -eq -1073741515) { Write-Output 'winget could not start as SYSTEM: install the Microsoft Visual C++ 2015-2022 Redistributable'; exit 1 }
Write-Output "winget exit code $rc"
exit 1
