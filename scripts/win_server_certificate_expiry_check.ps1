# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks the certificates of a store for expiry and shows which IIS HTTPS bindings use a certificate when the IIS module exists.
# Variables: WARN_DAYS (30) days before expiry that count as a warning; STORE (LocalMachine\My) certificate store, for example LocalMachine\My or LocalMachine\WebHosting.
# Exit: 0 all valid, 1 a certificate is expired, 2 a certificate expires soon, 3 bad input.
$warn = 30
if ($env:WARN_DAYS) { if (-not [int]::TryParse($env:WARN_DAYS.Trim(), [ref]$warn) -or $warn -lt 1 -or $warn -gt 3650) { Write-Output 'WARN_DAYS must be a number from 1 to 3650'; exit 3 } }
$store = 'LocalMachine\My'
if ($env:STORE) { $store = $env:STORE.Trim() }
if ($store -notmatch '^(LocalMachine|CurrentUser)\\[A-Za-z0-9 _-]{1,60}$') { Write-Output 'STORE must look like LocalMachine\My'; exit 3 }
$path = 'Cert:\' + $store
if (-not (Test-Path -LiteralPath $path)) { Write-Output "Certificate store $store does not exist"; exit 3 }

$bindings = @{}
$iisNote = ''
if (Get-Module -ListAvailable -Name WebAdministration) {
    try {
        Import-Module WebAdministration -ErrorAction Stop
        foreach ($b in @(Get-WebBinding -Protocol https -ErrorAction Stop)) {
            $hash = [string]$b.certificateHash
            if (-not $hash) { continue }
            $site = ''
            if ($b.ItemXPath -match "@name='([^']+)'") { $site = $Matches[1] }
            $label = "$site $($b.bindingInformation)".Trim()
            if ($bindings.ContainsKey($hash)) { $bindings[$hash] += "; $label" } else { $bindings[$hash] = $label }
        }
    } catch { $iisNote = "IIS bindings could not be read: $($_.Exception.Message)" }
}

$now = Get-Date
$certs = @(Get-ChildItem -LiteralPath $path -ErrorAction Stop | Where-Object { $_.NotAfter })
$expired = 0
$soon = 0
$lines = @()
foreach ($c in ($certs | Sort-Object -Property NotAfter)) {
    $days = [int][math]::Floor(($c.NotAfter - $now).TotalDays)
    $tag = 'ok'
    if ($days -lt 0) { $tag = 'EXPIRED'; $expired++ } elseif ($days -le $warn) { $tag = 'EXPIRES SOON'; $soon++ }
    if ($tag -eq 'ok') { continue }
    $use = ''
    if ($bindings.ContainsKey($c.Thumbprint)) { $use = " used by IIS: $($bindings[$c.Thumbprint])" }
    $lines += ("{0}: {1} thumbprint {2} valid until {3:yyyy-MM-dd} ({4} days){5}" -f $tag, $c.Subject, $c.Thumbprint, $c.NotAfter, $days, $use)
}
if ($expired -gt 0) { Write-Output "CRITICAL: $expired expired, $soon expiring within $warn days in $store ($($certs.Count) certificates)" }
elseif ($soon -gt 0) { Write-Output "WARNING: $soon certificate(s) expire within $warn days in $store ($($certs.Count) certificates)" }
else { Write-Output "OK: $($certs.Count) certificate(s) in $store, none expiring within $warn days" }
$lines | ForEach-Object { Write-Output $_ }
if ($iisNote) { Write-Output $iisNote }
if ($expired + $soon -eq 0) { exit 0 }
if ($expired -gt 0) { exit 1 }
exit 2
