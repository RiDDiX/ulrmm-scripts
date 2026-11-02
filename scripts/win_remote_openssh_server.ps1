# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Installs the OpenSSH server Windows capability, sets the sshd service to automatic and ensures the firewall rule for port 22.
# Variables: none
# Exit: 0 sshd installed and running, 1 install or start failed, 3 Windows version without the capability
$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Version.Build -lt 17763) {
    Write-Output 'OpenSSH server as a Windows capability needs Windows 10 1809 or Server 2019 or newer'
    exit 3
}
try {
    if (-not (Get-Service -Name sshd -ErrorAction SilentlyContinue)) {
        $cap = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' } | Select-Object -First 1
        if (-not $cap) {
            Write-Output 'The OpenSSH.Server capability is not offered on this system'
            exit 3
        }
        if ([string]$cap.State -ne 'Installed') {
            Write-Output ('Installing ' + $cap.Name + ' (needs Windows Update or a reachable feature source)')
            [void](Add-WindowsCapability -Online -Name $cap.Name)
        }
    } else {
        Write-Output 'sshd service already present'
    }
    Set-Service -Name sshd -StartupType Automatic
    if ((Get-Service -Name sshd).Status -ne 'Running') {
        Start-Service -Name sshd
        Write-Output 'sshd started'
    }
    $rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
    if (-not $rule) {
        [void](New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22)
        Write-Output 'Firewall rule created for TCP 22'
    } elseif ([string]$rule.Enabled -ne 'True') {
        Enable-NetFirewallRule -Name 'OpenSSH-Server-In-TCP'
        Write-Output 'Firewall rule enabled'
    }
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
$svc = Get-Service -Name sshd
Write-Output ('OK: sshd is ' + $svc.Status + ', start type ' + $svc.StartType + ', firewall rule in place')
exit 0
