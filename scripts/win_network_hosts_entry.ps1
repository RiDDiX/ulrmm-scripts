# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Adds or removes a host name in the hosts file. Add makes the name point to the given IP and drops the name from other lines.
# Variables: ACTION (add) add or remove; IP address for add; ENTRY_HOSTNAME host name.
# Exit: 0 done or already in place, 1 failed, 3 bad input.
$action = 'add'
if ($env:ACTION) { $action = $env:ACTION.Trim().ToLower() }
if ('add', 'remove' -notcontains $action) { Write-Output 'ACTION must be add or remove'; exit 3 }
$name = ''
if ($env:ENTRY_HOSTNAME) { $name = $env:ENTRY_HOSTNAME.Trim().ToLower() }
if ($name -notmatch '^[a-z0-9]([a-z0-9._-]{0,251}[a-z0-9])?$') { Write-Output 'ENTRY_HOSTNAME is required and must be a valid host name'; exit 3 }
$ip = ''
if ($action -eq 'add') {
    $parsed = $null
    if (-not $env:IP -or $env:IP.Trim() -notmatch '^(\d{1,3}\.){3}\d{1,3}$|:' -or -not [System.Net.IPAddress]::TryParse($env:IP.Trim(), [ref]$parsed)) { Write-Output 'IP must be a valid IP address'; exit 3 }
    $ip = $parsed.ToString()
}
$path = Join-Path $env:windir 'System32\drivers\etc\hosts'
try {
    $lines = @()
    if (Test-Path -LiteralPath $path) { $lines = @([System.IO.File]::ReadAllLines($path)) }
    $out = New-Object System.Collections.Generic.List[string]
    $changed = $false
    $already = $false
    foreach ($l in $lines) {
        if ($l.IndexOf($name, [StringComparison]::OrdinalIgnoreCase) -lt 0) { $out.Add($l); continue }
        $body = $l
        $comment = ''
        $h = $l.IndexOf('#')
        if ($h -ge 0) { $body = $l.Substring(0, $h); $comment = $l.Substring($h) }
        $tok = @($body -split '\s+' | Where-Object { $_ })
        if ($tok.Count -lt 2 -or ($tok[1..($tok.Count - 1)] | ForEach-Object { $_.ToLower() }) -notcontains $name) { $out.Add($l); continue }
        if ($action -eq 'add' -and $tok[0] -eq $ip -and $tok.Count -eq 2 -and -not $already) { $already = $true; $out.Add($l); continue }
        $rest = @($tok[1..($tok.Count - 1)] | Where-Object { $_.ToLower() -ne $name })
        $changed = $true
        if ($rest.Count -gt 0) {
            $new = $tok[0] + ' ' + ($rest -join ' ')
            if ($comment) { $new += ' ' + $comment }
            $out.Add($new)
        } elseif ($comment) { $out.Add($comment) }
    }
    if ($action -eq 'add' -and -not $already) { $out.Add("$ip`t$name"); $changed = $true }
    if (-not $changed) {
        if ($action -eq 'add') { Write-Output "Already in place: $ip $name" } else { Write-Output "$name is not in the hosts file" }
        exit 0
    }
    [System.IO.File]::WriteAllLines($path, [string[]]$out, (New-Object System.Text.UTF8Encoding $false))
    if ($action -eq 'add') { Write-Output "Hosts entry set: $ip $name" } else { Write-Output "Removed $name from the hosts file" }
    exit 0
} catch {
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
