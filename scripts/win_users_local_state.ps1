# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Enables or disables a local user account.
# Variables: TARGET_USER, STATE (enable or disable)
# Exit: 0 done or already in that state, 1 change failed, 3 bad input or account not found
$ErrorActionPreference = 'Stop'
$name = ([string]$env:TARGET_USER).Trim()
$state = ([string]$env:STATE).Trim().ToLower()
if (-not $name -or $name -match '["/\\\[\]:;|=,+*?<>@]|\$$') {
    Write-Output 'Bad or missing TARGET_USER'
    exit 3
}
if ($state -notin 'enable', 'disable') {
    Write-Output ('Bad STATE value: ' + $state + ' (enable or disable)')
    exit 3
}
if (-not (Get-Command Get-LocalUser -ErrorAction SilentlyContinue)) {
    Write-Output 'The LocalAccounts cmdlets are not available on this system'
    exit 3
}
try {
    $u = Get-LocalUser -Name $name -ErrorAction Stop
} catch {
    Write-Output ('Local account not found: ' + $name)
    exit 3
}
$want = $state -eq 'enable'
if ($u.Enabled -eq $want) {
    Write-Output ('Account ' + $name + ' is already ' + $state + 'd, nothing changed')
    exit 0
}
try {
    if ($want) { Enable-LocalUser -Name $name } else { Disable-LocalUser -Name $name }
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
Write-Output ('Account ' + $name + ' ' + $state + 'd')
exit 0
