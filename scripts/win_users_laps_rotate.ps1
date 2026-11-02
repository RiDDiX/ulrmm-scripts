# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Rotates the password of a local administrator account, creating it when missing. The password is never printed.
# Variables: TARGET_USER, NEW_PASSWORD, CREATE_IF_MISSING (checkbox, default true)
# Exit: 0 password set, 1 change failed, 3 bad input or account not found
$ErrorActionPreference = 'Stop'
function Finish([string]$msg, [int]$code) {
    [Console]::Out.WriteLine($msg)
    exit $code
}
$name = ([string]$env:TARGET_USER).Trim()
$password = [string]$env:NEW_PASSWORD
$createRaw = ([string]$env:CREATE_IF_MISSING).Trim().ToLower()
if (-not $createRaw) { $createRaw = 'true' }
if ($createRaw -ne 'true' -and $createRaw -ne 'false') { Finish 'CREATE_IF_MISSING must be true or false' 3 }
$create = $createRaw -eq 'true'
if ($name -cnotmatch '^[a-z][a-z0-9_-]{0,19}$') {
    Finish 'Bad or missing TARGET_USER' 3
}
if ($password.Length -lt 8 -or $password.Length -gt 128) { Finish 'NEW_PASSWORD must be 8-128 characters' 3 }
if (-not (Get-Command New-LocalUser -ErrorAction SilentlyContinue)) {
    Finish 'The LocalAccounts cmdlets are not available on this system' 3
}
$created = $false
try {
    $secure = ConvertTo-SecureString -String $password -AsPlainText -Force
    $u = Get-LocalUser -Name $name -ErrorAction SilentlyContinue
    if (-not $u) {
        if (-not $create) { Finish ('Local account not found: ' + $name) 3 }
        $u = New-LocalUser -Name $name -Password $secure -PasswordNeverExpires -AccountNeverExpires
        $created = $true
        try {
            Add-LocalGroupMember -SID 'S-1-5-32-544' -Member $name
        } catch {
            Remove-LocalUser -Name $name -ErrorAction SilentlyContinue
            throw
        }
    } else {
        if ($u.SID.Value -match '-500$' -eq $false -and -not $u.Enabled) {
            Finish ('Refusing to rotate ' + $name + ': the account is disabled') 3
        }
        Set-LocalUser -Name $name -Password $secure -PasswordNeverExpires $true
    }
} catch {
    Finish ('FAIL: ' + $_.Exception.Message) 1
}
Finish ('Password of ' + $name + ' rotated, created=' + $created) 0
