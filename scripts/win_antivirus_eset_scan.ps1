# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Scans with the ESET command-line scanner (ecls.exe) of an installed ESET product and lists the detections.
# Variables: SCAN_PATH ("" = all local drives) folder or file to scan.
# Exit: 0 clean, 1 threat found or scanner error, 2 some files could not be scanned, 3 bad input or ESET not installed.

$path = "$env:SCAN_PATH".Trim()
if ($path -and ($path -notmatch '^[A-Za-z]:\\' -or $path -match '["*?<>|]')) { Write-Output 'SCAN_PATH must be an absolute local path'; exit 3 }
if ($path -and -not (Test-Path -LiteralPath $path)) { Write-Output "SCAN_PATH does not exist: $path"; exit 3 }

$dir = Join-Path $env:ProgramFiles 'ESET\ESET Security'
$ecls = Join-Path $dir 'ecls.exe'
if (-not (Test-Path -LiteralPath $ecls)) { Write-Output "ESET command-line scanner not found at $ecls"; exit 3 }

$log = Join-Path $env:SystemRoot ('Temp\ecls-' + [Guid]::NewGuid().ToString('N') + '.log')
# Double a trailing backslash, otherwise it escapes the closing quote.
$target = if ($path) { "`"$($path -replace '\\$', '\\')`"" } else { '/auto' }
$argText = "/base-dir=`"$dir\Modules`" /log-file=`"$log`" $target"
$start = Get-Date
$proc = Start-Process -FilePath $ecls -ArgumentList $argText -WindowStyle Hidden -Wait -PassThru
$code = $proc.ExitCode
$minutes = [math]::Round(((Get-Date) - $start).TotalMinutes, 1)

$lines = @()
if (Test-Path -LiteralPath $log) {
    $lines = @(Get-Content -LiteralPath $log -ErrorAction SilentlyContinue)
    Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
}
switch ($code) {
    0 { Write-Output "CLEAN: no threat found ($minutes min)"; $rc = 0 }
    1 { Write-Output "THREATS: found and cleaned ($minutes min)"; $rc = 1 }
    10 { Write-Output "WARNING: some files could not be scanned ($minutes min)"; $rc = 2 }
    50 { Write-Output "THREATS: found ($minutes min)"; $rc = 1 }
    default { Write-Output "FAIL: ecls.exe exit code $code"; $rc = 1 }
}
$lines | Where-Object { $_ -match 'threat=|result=' -and $_ -notmatch 'threat="(is OK)?"' } | Select-Object -First 30 |
    ForEach-Object { Write-Output $_.Substring(0, [math]::Min(200, $_.Length)) }
$lines | Where-Object { $_ -match '^(Scanned|Infected|Cleaned|Total)' } | ForEach-Object { Write-Output $_ }
exit $rc
