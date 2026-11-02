# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Adds or removes a Windows Firewall port rule. An existing rule with the same name and the same settings counts as done; built-in rule groups are never removed.
# Variables: ACTION (add) add or remove; NAME rule name; PORT number, range (8000-8010) or comma list; PROTOCOL (TCP) TCP or UDP; DIRECTION (inbound) inbound or outbound; RULE_ACTION (allow) allow or block.
# Exit: 0 done or already in place, 1 failed, 3 bad input.
$action = 'add'
if ($env:ACTION) { $action = $env:ACTION.Trim().ToLower() }
if ('add', 'remove' -notcontains $action) { Write-Output 'ACTION must be add or remove'; exit 3 }
$name = ''
if ($env:NAME) { $name = $env:NAME.Trim() }
if ($name -notmatch '^[A-Za-z0-9 ._()-]{1,100}$') { Write-Output 'NAME is required: letters, digits, space and . _ ( ) - only'; exit 3 }
$port = ''
$proto = 'TCP'
$dir = 'inbound'
$verdict = 'allow'
if ($action -eq 'add') {
    if ($env:PORT) { $port = ($env:PORT -replace '\s', '') }
    if ($port -notmatch '^[0-9]{1,5}(-[0-9]{1,5})?(,[0-9]{1,5}(-[0-9]{1,5})?)*$') { Write-Output 'PORT must be a number, a range like 8000-8010 or a comma list'; exit 3 }
    foreach ($n in ($port -split '[,-]')) { if ([int]$n -lt 1 -or [int]$n -gt 65535) { Write-Output 'PORT values must be 1 to 65535'; exit 3 } }
    if ($env:PROTOCOL) { $proto = $env:PROTOCOL.Trim().ToUpper() }
    if ('TCP', 'UDP' -notcontains $proto) { Write-Output 'PROTOCOL must be TCP or UDP'; exit 3 }
    if ($env:DIRECTION) { $dir = $env:DIRECTION.Trim().ToLower() }
    if ('inbound', 'outbound' -notcontains $dir) { Write-Output 'DIRECTION must be inbound or outbound'; exit 3 }
    if ($env:RULE_ACTION) { $verdict = $env:RULE_ACTION.Trim().ToLower() }
    if ('allow', 'block' -notcontains $verdict) { Write-Output 'RULE_ACTION must be allow or block'; exit 3 }
}
try {
    $existing = @(Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue)
    if ($action -eq 'remove') {
        if ($existing.Count -eq 0) { Write-Output "No rule named '$name', nothing to remove"; exit 0 }
        if (@($existing | Where-Object { $_.Group }).Count -gt 0) { Write-Output "'$name' belongs to a built-in rule group, not removed"; exit 1 }
        $existing | Remove-NetFirewallRule -ErrorAction Stop
        Write-Output "Removed $($existing.Count) rule(s) named '$name'"
        exit 0
    }
    $want = @{ inbound = 'Inbound'; outbound = 'Outbound'; allow = 'Allow'; block = 'Block' }
    if ($existing.Count -gt 0) {
        $r = $existing[0]
        $f = $r | Get-NetFirewallPortFilter
        $have = if ($dir -eq 'inbound') { @($f.LocalPort) -join ',' } else { @($f.RemotePort) -join ',' }
        if ($existing.Count -eq 1 -and $r.Enabled -eq 'True' -and $r.Direction -eq $want[$dir] -and $r.Action -eq $want[$verdict] -and $f.Protocol -eq $proto -and $have -eq $port) {
            Write-Output "Rule '$name' already exists with these settings"
            exit 0
        }
        Write-Output "A rule named '$name' exists with different settings; remove it first"
        exit 1
    }
    $params = @{ DisplayName = $name; Direction = $want[$dir]; Action = $want[$verdict]; Protocol = $proto; Profile = 'Any'; Enabled = 'True' }
    if ($dir -eq 'inbound') { $params.LocalPort = $port -split ',' } else { $params.RemotePort = $port -split ',' }
    New-NetFirewallRule @params -ErrorAction Stop | Out-Null
    Write-Output "Added rule '$name': $verdict $dir $proto $port"
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
