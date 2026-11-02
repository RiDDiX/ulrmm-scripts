# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Sets a new password on a local user account, optionally forcing a change at next logon. The password is never printed.
# Variables: TARGET_USER, PASSWORD, MUST_CHANGE (checkbox, default false)
# Exit: 0 password set, 1 change failed, 3 bad input or account not found
$ErrorActionPreference = 'Stop'
$name = ([string]$env:TARGET_USER).Trim()
$password = [string]$env:PASSWORD
$mustChange = ([string]$env:MUST_CHANGE).Trim().ToLower() -eq 'true'
if (-not $name -or $name -match '["/\\\[\]:;|=,+*?<>@]|\$$') {
    Write-Output 'Bad or missing TARGET_USER'
    exit 3
}
if (-not $password) {
    Write-Output 'PASSWORD is required'
    exit 3
}
if (-not (Get-Command Set-LocalUser -ErrorAction SilentlyContinue)) {
    Write-Output 'The LocalAccounts cmdlets are not available on this system'
    exit 3
}
try {
    $u = Get-LocalUser -Name $name -ErrorAction Stop
} catch {
    Write-Output ('Local account not found: ' + $name)
    exit 3
}
try {
    $secure = ConvertTo-SecureString -String $password -AsPlainText -Force
    Set-LocalUser -Name $name -Password $secure
    if ($mustChange) {
        $adsi = [ADSI]('WinNT://' + $env:COMPUTERNAME + '/' + $u.Name + ',user')
        $adsi.Put('PasswordExpired', 1)
        $adsi.SetInfo()
    }
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
Write-Output ('Password of ' + $name + ' was reset, change at next logon=' + $mustChange)
exit 0
