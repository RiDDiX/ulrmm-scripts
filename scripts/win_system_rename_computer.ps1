# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Renames the computer; on a domain member the account rename needs domain credentials. The new name is active after a restart.
# Variables: NEW_NAME new computer name; RESTART (false) restart in 30 seconds; DOMAIN_USERNAME and DOMAIN_PASSWORD domain account allowed to rename the computer object (domain members only).
# Exit: 0 renamed or already named so, 1 failed, 3 bad input.
$new = ''
if ($env:NEW_NAME) { $new = $env:NEW_NAME.Trim() }
if ($new -notmatch '^[A-Za-z0-9]([A-Za-z0-9-]{0,13}[A-Za-z0-9])?$' -or $new -match '^[0-9]+$') {
    Write-Output 'NEW_NAME must be 1-15 letters, digits or dashes, not start or end with a dash and not be only digits'
    exit 3
}
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.Name -ieq $new) { Write-Output "The computer is already named $new"; exit 0 }
$pending = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ErrorAction SilentlyContinue).ComputerName
$user = $env:DOMAIN_USERNAME
$cred = $null
if ($cs.PartOfDomain -and $pending -ine $new) {
    if (-not $user -or -not $env:DOMAIN_PASSWORD) { Write-Output "The computer is a member of $($cs.Domain); DOMAIN_USERNAME and DOMAIN_PASSWORD are required"; exit 3 }
    $sec = ConvertTo-SecureString -String $env:DOMAIN_PASSWORD -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user.Trim(), $sec)
}
try {
    if ($pending -ieq $new) { Write-Output "The rename to $new is already done and waits for a restart" }
    else {
        if ($cred) { Rename-Computer -NewName $new -DomainCredential $cred -Force -ErrorAction Stop }
        else { Rename-Computer -NewName $new -Force -ErrorAction Stop }
        Write-Output "Renamed $($cs.Name) to $new, active after a restart"
    }
    if ($env:RESTART -eq 'true') {
        & (Join-Path $env:windir 'System32\shutdown.exe') /r /t 30 /c 'Restart after computer rename' 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Output 'Restart scheduled in 30 seconds' }
        else { Write-Output "Restart could not be scheduled (shutdown.exe exit code $LASTEXITCODE), restart manually" }
    }
    exit 0
} catch {
    Write-Output "Rename failed: $($_.Exception.Message)"
    exit 1
}
