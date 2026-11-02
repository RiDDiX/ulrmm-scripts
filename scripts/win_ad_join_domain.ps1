# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Joins this computer to an Active Directory domain. The password is never printed.
# Variables: DOMAIN, DOMAIN_USER (account with join rights), PASSWORD, OU (optional distinguished name), RESTART (checkbox, default false)
# Exit: 0 joined or already a member, 1 join failed, 3 bad input or unsupported system
$ErrorActionPreference = 'Stop'
$domain = ([string]$env:DOMAIN).Trim()
$user = ([string]$env:DOMAIN_USER).Trim()
$password = [string]$env:PASSWORD
$ou = ([string]$env:OU).Trim()
$restart = ([string]$env:RESTART).Trim().ToLower() -eq 'true'
if ($domain -notmatch '^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$') {
    Write-Output 'Bad or missing DOMAIN'
    exit 3
}
if (-not $user -or $user -match '\$$') {
    Write-Output 'Bad or missing DOMAIN_USER'
    exit 3
}
if (-not $password) {
    Write-Output 'PASSWORD is required'
    exit 3
}
if ($ou -and $ou -notmatch '^(OU|CN)=.+') {
    Write-Output 'Bad OU: expected a distinguished name such as OU=Servers,DC=corp,DC=example,DC=com'
    exit 3
}
$cs = Get-CimInstance -ClassName Win32_ComputerSystem
if ($cs.DomainRole -ge 4) {
    Write-Output 'This computer is a domain controller, not joining'
    exit 3
}
if ($cs.PartOfDomain) {
    if ($cs.Domain -ieq $domain -or $cs.Domain.Split('.')[0] -ieq $domain.Split('.')[0]) {
        Write-Output ('Already a member of ' + $cs.Domain + ', nothing changed')
        exit 0
    }
    Write-Output ('Already a member of a different domain: ' + $cs.Domain)
    exit 3
}
try {
    $secure = ConvertTo-SecureString -String $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($user, $secure)
    $params = @{ DomainName = $domain; Credential = $cred; Force = $true }
    if ($ou) { $params['OUPath'] = $ou }
    Add-Computer @params
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
if ($restart) {
    Write-Output ('Joined ' + $domain + ', restarting in 30 seconds')
    & shutdown.exe /r /t 30 /c 'Domain join completed'
} else {
    Write-Output ('Joined ' + $domain + ', a restart is required to finish')
}
exit 0
