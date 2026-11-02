# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Network repair step: flush the DNS cache, renew DHCP leases, reset Winsock or reset the TCP/IP stack (the two resets need a restart).
# Variables: ACTION (flush dns) flush dns, renew dhcp, reset winsock or reset tcpip.
# Exit: 0 done, 1 the command failed, 3 bad input.
$action = 'flush dns'
if ($env:ACTION) { $action = $env:ACTION.Trim().ToLower() }
$sys = Join-Path $env:windir 'System32'
switch ($action) {
    'flush dns' { $exe = 'ipconfig.exe'; $arguments = @('/flushdns') }
    'renew dhcp' { $exe = 'ipconfig.exe'; $arguments = @('/renew') }
    'reset winsock' { $exe = 'netsh.exe'; $arguments = @('winsock', 'reset') }
    'reset tcpip' { $exe = 'netsh.exe'; $arguments = @('int', 'ip', 'reset') }
    default { Write-Output 'ACTION must be flush dns, renew dhcp, reset winsock or reset tcpip'; exit 3 }
}
$out = (& (Join-Path $sys $exe) @arguments 2>&1 | Out-String).Trim()
$rc = $LASTEXITCODE
if ($rc -ne 0) { Write-Output "$action failed (exit $rc): $out"; exit 1 }
Write-Output "$action done"
if ($action -like 'reset*') { Write-Output 'Restart the computer to finish the reset' }
exit 0
