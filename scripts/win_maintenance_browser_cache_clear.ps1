# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Clears the cache folders of Chrome, Edge and Firefox for every user profile; a running browser is skipped unless FORCE.
# Variables: BROWSER (all) all, chrome, edge or firefox; FORCE (false) close the running browser first.
# Exit: 0 done, 1 a folder could not be cleared, 3 bad input.
$browser = 'all'
if ($env:BROWSER) { $browser = $env:BROWSER.Trim().ToLower() }
if ('all', 'chrome', 'edge', 'firefox' -notcontains $browser) { Write-Output 'BROWSER must be all, chrome, edge or firefox'; exit 3 }
$force = $env:FORCE -eq 'true'

$defs = @(
    @{ Key = 'chrome'; Proc = 'chrome'; Root = 'AppData\Local\Google\Chrome\User Data'; Chromium = $true }
    @{ Key = 'edge'; Proc = 'msedge'; Root = 'AppData\Local\Microsoft\Edge\User Data'; Chromium = $true }
    @{ Key = 'firefox'; Proc = 'firefox'; Root = 'AppData\Local\Mozilla\Firefox\Profiles'; Chromium = $false }
)

function Get-TreeFile([string]$Path) {
    foreach ($i in @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)) {
        if ($i.PSIsContainer) {
            if (-not ($i.Attributes -band [IO.FileAttributes]::ReparsePoint)) { Get-TreeFile $i.FullName }
        } else { $i }
    }
}

$total = [int64]0
$bad = 0
$profiles = @(Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special -and $_.LocalPath })
foreach ($d in $defs) {
    if ($browser -ne 'all' -and $browser -ne $d.Key) { continue }
    $running = @(Get-Process -Name $d.Proc -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        if (-not $force) { Write-Output "$($d.Key): running, skipped (set FORCE to close it)"; continue }
        $running | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    $bytes = [int64]0
    foreach ($p in $profiles) {
        $root = Join-Path $p.LocalPath $d.Root
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $targets = @()
        if ($d.Chromium) {
            foreach ($pd in Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' -or $_.Name -eq 'Guest Profile' }) {
                foreach ($c in 'Cache', 'Code Cache', 'GPUCache', 'Service Worker\CacheStorage') { $targets += Join-Path $pd.FullName $c }
            }
        } else {
            foreach ($pd in Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue) {
                foreach ($c in 'cache2', 'startupCache') { $targets += Join-Path $pd.FullName $c }
            }
        }
        foreach ($t in $targets) {
            if (-not (Test-Path -LiteralPath $t)) { continue }
            foreach ($f in @(Get-TreeFile $t)) {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                if (Test-Path -LiteralPath $f.FullName) { $bad++ } else { $bytes += $f.Length }
            }
        }
    }
    Write-Output ("{0}: freed {1:N1} MB" -f $d.Key, ($bytes / 1MB))
    $total += $bytes
}
Write-Output ("Total freed: {0:N1} MB" -f ($total / 1MB))
if ($bad -gt 0) { Write-Output "$bad files could not be removed"; exit 1 }
exit 0
