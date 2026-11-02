# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists the Hyper-V virtual machines with state and heartbeat and checks that the VMs named in EXPECT_RUNNING are running.
# Variables: EXPECT_RUNNING VM names that must be running, comma or line separated (empty = only report).
# Exit: 0 ok, 1 an expected VM is not running or missing, 2 a VM is in a critical or paused state, 3 Hyper-V is not available.
if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) { Write-Output 'The Hyper-V PowerShell module is not available on this system'; exit 3 }
$expect = @()
if ($env:EXPECT_RUNNING) { $expect = @($env:EXPECT_RUNNING -split '[,\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
try {
    $vms = @(Get-VM -ErrorAction Stop)
} catch {
    Write-Output "Cannot read the VMs (is this a Hyper-V host?): $($_.Exception.Message)"
    exit 3
}
$bad = 0
$warn = 0
$lines = @()
foreach ($e in $expect) {
    $vm = $vms | Where-Object { $_.Name -ieq $e } | Select-Object -First 1
    if (-not $vm) { $lines += "MISSING expected VM '$e' does not exist on this host"; $bad++ }
    elseif ($vm.State -ne 'Running') { $lines += "DOWN expected VM '$($vm.Name)' is $($vm.State)"; $bad++ }
}
foreach ($vm in $vms) {
    if ($vm.State -like '*Critical*' -or $vm.State -eq 'Paused') { $warn++ }
}
$verdict = 'OK'
if ($bad -gt 0) { $verdict = 'CRITICAL' } elseif ($warn -gt 0) { $verdict = 'WARNING' }
Write-Output ("{0}: {1} VM(s), {2} running; {3} expected VM(s) failing, {4} VM(s) critical or paused" -f $verdict, $vms.Count, @($vms | Where-Object { $_.State -eq 'Running' }).Count, $bad, $warn)
$lines | ForEach-Object { Write-Output $_ }
foreach ($vm in ($vms | Sort-Object -Property Name)) {
    Write-Output ("{0}: {1}, heartbeat {2}, uptime {3}" -f $vm.Name, $vm.State, $vm.Heartbeat, $vm.Uptime.ToString('d\.hh\:mm'))
}
if ($bad -gt 0) { exit 1 }
if ($warn -gt 0) { exit 2 }
exit 0
