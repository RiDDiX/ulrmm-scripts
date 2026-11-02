# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows, enables or disables Remote Desktop, including Network Level Authentication and the firewall rule group.
# Variables: STATE (status, enable or disable; default status), NLA (checkbox, default true, applied when enabling)
# Exit: 0 done or reported, 1 change failed, 3 bad input or Remote Desktop not available (Home edition)
$ErrorActionPreference = 'Stop'
$state = ([string]$env:STATE).Trim().ToLower()
if (-not $state) { $state = 'status' }
if ($state -notin 'status', 'enable', 'disable') {
    Write-Output ('Bad STATE value: ' + $state)
    exit 3
}
$nlaRaw = ([string]$env:NLA).Trim().ToLower()
if ($nlaRaw -and $nlaRaw -notin 'true', 'false') {
    Write-Output ('Bad NLA value: ' + $nlaRaw)
    exit 3
}
$nla = $nlaRaw -ne 'false'
$ts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$rdp = $ts + '\WinStations\RDP-Tcp'
$sku = [int](Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU
if (($sku -in 98, 99, 100, 101) -or -not (Test-Path $rdp)) {
    Write-Output 'Remote Desktop hosting is not available on this edition (Windows Home)'
    exit 3
}
# language-neutral identifier of the "Remote Desktop" firewall group
$group = '@FirewallAPI.dll,-28752'
try {
    if ($state -eq 'enable') {
        [void](New-ItemProperty -Path $ts -Name fDenyTSConnections -Value 0 -PropertyType DWord -Force)
        [void](New-ItemProperty -Path $rdp -Name UserAuthentication -Value ([int]$nla) -PropertyType DWord -Force)
        Enable-NetFirewallRule -Group $group
        Write-Output ('Remote Desktop enabled, NLA=' + $nla + ', firewall group enabled')
    } elseif ($state -eq 'disable') {
        [void](New-ItemProperty -Path $ts -Name fDenyTSConnections -Value 1 -PropertyType DWord -Force)
        Disable-NetFirewallRule -Group $group
        Write-Output 'Remote Desktop disabled, firewall group disabled'
    }
    $deny = (Get-ItemProperty -Path $ts -Name fDenyTSConnections).fDenyTSConnections
    $auth = (Get-ItemProperty -Path $rdp -Name UserAuthentication).UserAuthentication
    $rules = @(Get-NetFirewallRule -Group $group -ErrorAction SilentlyContinue)
    $on = @($rules | Where-Object { [string]$_.Enabled -eq 'True' }).Count
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
$policy = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -ErrorAction SilentlyContinue
if ($policy -and $null -ne $policy.fDenyTSConnections) {
    $deny = $policy.fDenyTSConnections
    Write-Output 'Remote Desktop is set by group policy, the policy value applies'
}
$enabled = $deny -eq 0
Write-Output ('Remote Desktop: ' + $(if ($enabled) { 'enabled' } else { 'disabled' }))
Write-Output ('Network Level Authentication: ' + $(if ($auth -eq 1) { 'required' } else { 'not required' }))
Write-Output ('Firewall rules enabled in the group: ' + $on + ' of ' + $rules.Count)
if (($state -eq 'enable' -and -not $enabled) -or ($state -eq 'disable' -and $enabled)) { exit 1 }
exit 0
