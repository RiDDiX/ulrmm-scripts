# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Prints the last lines of the agent log found in the agent install directory.
# Variables: LINES (optional, default 100, 1-2000)
# Exit: 0 printed, 1 no log file found, 3 bad input or agent not installed
$ErrorActionPreference = 'Stop'
$raw = ([string]$env:LINES).Trim()
$lines = 100
if ($raw) {
    if (-not [int]::TryParse($raw, [ref]$lines) -or $lines -lt 1 -or $lines -gt 2000) {
        Write-Output ('Bad LINES value: ' + $raw + ' (allowed 1-2000)')
        exit 3
    }
}
$dir = Join-Path $env:ProgramFiles 'ULRMM Agent'
if (-not (Test-Path -LiteralPath $dir)) {
    Write-Output ('Agent install directory not found: ' + $dir)
    exit 3
}
$log = Join-Path $dir 'agent.log'
if (-not (Test-Path -LiteralPath $log)) {
    $found = Get-ChildItem -LiteralPath $dir -Filter '*.log' -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $found) {
        Write-Output ('No log file found under ' + $dir)
        exit 1
    }
    $log = $found.FullName
}
$info = Get-Item -LiteralPath $log
Write-Output ('{0} ({1:N0} KB, modified {2:yyyy-MM-dd HH:mm})' -f $log, ($info.Length / 1KB), $info.LastWriteTime)
try {
    $tail = @(Get-Content -LiteralPath $log -Tail $lines -Encoding UTF8)
} catch {
    Write-Output ('Cannot read the log: ' + $_.Exception.Message)
    exit 1
}
foreach ($l in $tail) {
    if ($l.Length -gt 1500) { $l = $l.Substring(0, 1500) + ' ...' }
    Write-Output $l
}
exit 0
