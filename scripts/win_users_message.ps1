# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows a message box to all logged-on users with msg.exe.
# Variables: MESSAGE, DISPLAY_SECONDS (optional, default 60, how long the box stays, 5-3600)
# Exit: 0 sent, 1 msg.exe reported an error (for example no session), 3 bad input or msg.exe missing
$ErrorActionPreference = 'Stop'
$message = ([string]$env:MESSAGE).Trim() -replace '"', "'"
$raw = ([string]$env:DISPLAY_SECONDS).Trim()
$seconds = 60
if ($raw) {
    if (-not [int]::TryParse($raw, [ref]$seconds) -or $seconds -lt 5 -or $seconds -gt 3600) {
        Write-Output ('Bad DISPLAY_SECONDS value: ' + $raw + ' (allowed 5-3600)')
        exit 3
    }
}
if (-not $message -or $message.Length -gt 500) {
    Write-Output 'MESSAGE is required and limited to 500 characters'
    exit 3
}
# a leading space keeps msg.exe from reading the text as a switch
if ($message -match '^[/-]') { $message = ' ' + $message }
$msg = Join-Path $env:SystemRoot 'System32\msg.exe'
if (-not (Test-Path $msg)) {
    Write-Output 'msg.exe is not available (Windows Home editions do not include it)'
    exit 3
}
$ErrorActionPreference = 'Continue'
$out = & $msg '*' "/TIME:$seconds" $message 2>&1
$rc = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($rc -ne 0) {
    Write-Output ('msg.exe failed with exit code ' + $rc + ': ' + (($out | ForEach-Object { [string]$_ }) -join ' '))
    exit 1
}
Write-Output ('Message sent to all sessions, shown for ' + $seconds + ' s')
exit 0
