# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Tests the secure channel between this computer and its domain and optionally repairs it. The password is never printed.
# Variables: REPAIR (checkbox, default false), DOMAIN_USER and PASSWORD (domain account allowed to reset the computer account, needed for REPAIR)
# Exit: 0 channel healthy or repaired, 1 channel broken, 3 bad input or not domain joined
$ErrorActionPreference = 'Stop'
$repair = ([string]$env:REPAIR).Trim().ToLower() -eq 'true'
$cs = Get-CimInstance -ClassName Win32_ComputerSystem
if (-not $cs.PartOfDomain) {
    Write-Output 'This computer is not joined to a domain'
    exit 3
}
$cred = $null
if ($repair) {
    $user = ([string]$env:DOMAIN_USER).Trim()
    $password = [string]$env:PASSWORD
    if (-not $user -or $user -match '\$$' -or -not $password) {
        Write-Output 'REPAIR needs DOMAIN_USER and PASSWORD of a domain account'
        exit 3
    }
    $cred = New-Object System.Management.Automation.PSCredential($user, (ConvertTo-SecureString -String $password -AsPlainText -Force))
}
try {
    $ok = Test-ComputerSecureChannel
} catch {
    Write-Output ('FAIL: secure channel test failed: ' + $_.Exception.Message)
    $ok = $false
}
if ($ok) {
    Write-Output ('OK: secure channel to ' + $cs.Domain + ' is healthy')
    exit 0
}
if (-not $repair) {
    Write-Output ('FAIL: secure channel to ' + $cs.Domain + ' is broken')
    exit 1
}
try {
    $fixed = Test-ComputerSecureChannel -Repair -Credential $cred
} catch {
    Write-Output ('FAIL: repair failed: ' + $_.Exception.Message)
    exit 1
}
if ($fixed) {
    Write-Output ('Secure channel to ' + $cs.Domain + ' was repaired')
    exit 0
}
Write-Output 'FAIL: repair did not restore the secure channel'
exit 1
