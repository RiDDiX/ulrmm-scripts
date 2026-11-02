# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows, enables or disables fast startup (hybrid boot). It only has an effect while hibernation is enabled.
# Variables: STATE (status) status, on or off.
# Exit: 0 done, 1 failed, 3 bad input.
$state = 'status'
if ($env:STATE) { $state = $env:STATE.Trim().ToLower() }
if ('status', 'on', 'off' -notcontains $state) { Write-Output 'STATE must be status, on or off'; exit 3 }
$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
$policy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
try {
    $cur = (Get-ItemProperty -LiteralPath $key -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
    if ($state -ne 'status') {
        $val = 0
        if ($state -eq 'on') { $val = 1 }
        if ($cur -eq $val) { Write-Output "Fast startup is already $state" }
        else {
            New-ItemProperty -LiteralPath $key -Name HiberbootEnabled -Value $val -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            Write-Output "Fast startup turned $state"
        }
        $cur = $val
    }
    $text = 'off'
    if ($cur -eq 1) { $text = 'on' }
    Write-Output "Fast startup: $text"
    $pw = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -ErrorAction SilentlyContinue
    $hib = $pw.HibernateEnabled
    if ($null -eq $hib) { $hib = $pw.HibernateEnabledDefault }
    if ($cur -eq 1 -and $hib -ne 1) { Write-Output 'Note: hibernation is disabled, fast startup has no effect until it is enabled' }
    $pol = (Get-ItemProperty -LiteralPath $policy -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
    if ($null -ne $pol) { Write-Output "Note: a policy sets HiberbootEnabled to $pol and overrides this value" }
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
