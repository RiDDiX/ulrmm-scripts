# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Creates a local user account, optionally as administrator. The password is never printed.
# Variables: TARGET_USER, PASSWORD, FULL_NAME (optional), ADMINISTRATOR (checkbox, default false), PASSWORD_NEVER_EXPIRES (checkbox, default false)
# Exit: 0 created, 1 creation failed or account exists, 3 bad input or local accounts not available
$ErrorActionPreference = 'Stop'
$name = ([string]$env:TARGET_USER).Trim()
$password = [string]$env:PASSWORD
$fullName = ([string]$env:FULL_NAME).Trim()
$admin = ([string]$env:ADMINISTRATOR).Trim().ToLower() -eq 'true'
$neverExpires = ([string]$env:PASSWORD_NEVER_EXPIRES).Trim().ToLower() -eq 'true'
if (-not $name -or $name.Length -gt 20 -or $name -match '["/\\\[\]:;|=,+*?<>@]|\$$' -or $name -match '^[. ]+$' -or $name -match '[. ]$') {
    Write-Output 'Bad TARGET_USER: 1-20 characters, none of " / \ [ ] : ; | = , + * ? < > @ and no trailing $, not ending in a dot or space'
    exit 3
}
if (-not $password) {
    Write-Output 'PASSWORD is required'
    exit 3
}
if ($fullName.Length -gt 100) {
    Write-Output 'FULL_NAME is longer than 100 characters'
    exit 3
}
if (-not (Get-Command New-LocalUser -ErrorAction SilentlyContinue)) {
    Write-Output 'The LocalAccounts cmdlets are not available on this system'
    exit 3
}
try {
    if (Get-LocalUser -Name $name -ErrorAction SilentlyContinue) {
        Write-Output ('Account ' + $name + ' already exists, nothing changed')
        exit 1
    }
    $secure = ConvertTo-SecureString -String $password -AsPlainText -Force
    $params = @{ Name = $name; Password = $secure; AccountNeverExpires = $true; PasswordNeverExpires = $neverExpires }
    if ($fullName) { $params['FullName'] = $fullName }
    [void](New-LocalUser @params)
    $users = Get-LocalGroup -SID 'S-1-5-32-545'
    Add-LocalGroupMember -Group $users -Member $name
    if ($admin) {
        $admins = Get-LocalGroup -SID 'S-1-5-32-544'
        Add-LocalGroupMember -Group $admins -Member $name
    }
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
Write-Output ('Created local account ' + $name + ', administrator=' + $admin + ', password never expires=' + $neverExpires)
exit 0
