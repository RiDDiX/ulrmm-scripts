# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Updates the Microsoft Defender signatures now.
# Variables: none.
# Exit: 0 updated or already current, 1 update failed, 3 Defender not available.

try {
    $before = (Get-MpComputerStatus -ErrorAction Stop).AntivirusSignatureVersion
} catch {
    Write-Output "Microsoft Defender is not available: $($_.Exception.Message)"
    exit 3
}

$ok = $true
try {
    Update-MpSignature -ErrorAction Stop
} catch {
    Write-Output "Update-MpSignature failed: $($_.Exception.Message); trying MpCmdRun"
    $mpcmd = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
    $out = & cmd.exe /c "`"$mpcmd`" -SignatureUpdate 2>&1"
    $ok = $LASTEXITCODE -eq 0
    $out | Select-Object -Last 3 | ForEach-Object { Write-Output $_ }
}

$s = Get-MpComputerStatus
if (-not $ok) {
    Write-Output "Signature update failed, still at $($s.AntivirusSignatureVersion)"
    exit 1
}
if ($s.AntivirusSignatureVersion -ne $before) {
    Write-Output "Signatures updated: $before -> $($s.AntivirusSignatureVersion)"
} else {
    Write-Output "Signatures already current: $before"
}
Write-Output "Last updated $($s.AntivirusSignatureLastUpdated), engine $($s.AMEngineVersion)"
exit 0
