# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Measures the clock offset against the configured time source over SNTP and optionally resyncs the clock.
# Variables: MAX_OFFSET_SECONDS (60) allowed offset; RESYNC (false) run w32tm /resync when the offset is too large.
# Exit: 0 clock within the limit, 1 offset too large, 2 offset could not be measured, 3 bad input.
$max = 60
if ($env:MAX_OFFSET_SECONDS) {
    if (-not [int]::TryParse($env:MAX_OFFSET_SECONDS.Trim(), [ref]$max) -or $max -lt 1 -or $max -gt 86400) { Write-Output 'MAX_OFFSET_SECONDS must be a number from 1 to 86400'; exit 3 }
}
$resync = $env:RESYNC -eq 'true'
$w32 = Join-Path $env:windir 'System32\w32tm.exe'

function Get-Source {
    $list = @()
    $src = (& $w32 /query /source 2>&1 | Out-String).Trim()
    if ($src -match '^[A-Za-z0-9][A-Za-z0-9.\-]*(,0x[0-9a-fA-F]+)?$' -and $src -notmatch '^Local|^Free') { $list += ($src -split ',')[0] }
    $ntp = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -ErrorAction SilentlyContinue).NtpServer
    foreach ($s in ([string]$ntp -split '\s+')) {
        $h = ($s -split ',')[0]
        if ($h) { $list += $h }
    }
    $list += 'time.windows.com'
    return @($list | Select-Object -Unique)
}

function Get-Offset([string]$Server) {
    $udp = New-Object System.Net.Sockets.UdpClient
    try {
        $udp.Client.ReceiveTimeout = 3000
        $udp.Connect($Server, 123)
        $req = New-Object byte[] 48
        $req[0] = 0x1B
        $t1 = [DateTime]::UtcNow
        [void]$udp.Send($req, 48)
        $ep = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, 0)
        $resp = $udp.Receive([ref]$ep)
        $t4 = [DateTime]::UtcNow
        if ($resp.Length -lt 48 -or $resp[1] -eq 0) { return $null }
        $secs = [double]0
        $frac = [double]0
        for ($i = 0; $i -lt 4; $i++) { $secs = $secs * 256 + $resp[40 + $i]; $frac = $frac * 256 + $resp[44 + $i] }
        $remote = (New-Object DateTime 1900, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)).AddSeconds($secs + $frac / 4294967296)
        $mid = $t1.AddTicks([int64](($t4 - $t1).Ticks / 2))
        return ($remote - $mid).TotalSeconds
    } catch { return $null }
    finally { $udp.Close() }
}

function Measure-Clock {
    foreach ($s in (Get-Source)) {
        $o = Get-Offset $s
        if ($null -ne $o) { return @{ Server = $s; Offset = $o } }
    }
    return $null
}

$svc = Get-Service -Name W32Time -ErrorAction SilentlyContinue
$notes = @()
if ($svc) { $notes += "Windows Time service: $($svc.Status)" }
$m = Measure-Clock
if (-not $m) { Write-Output 'WARNING: no time server answered on UDP 123, offset unknown'; Write-Output $notes; exit 2 }
$off = [math]::Abs($m.Offset)
if ($off -gt $max -and $resync) {
    if ($svc -and $svc.Status -ne 'Running') { Start-Service -Name W32Time -ErrorAction SilentlyContinue }
    & $w32 /resync 2>&1 | Out-Null
    $notes += "Resync requested, w32tm exit code $LASTEXITCODE"
    Start-Sleep -Seconds 3
    $m2 = Measure-Clock
    if ($m2) { $m = $m2; $off = [math]::Abs($m.Offset) }
}
$text = "clock offset against {0}: {1:N2} s (limit {2} s)" -f $m.Server, $m.Offset, $max
if ($off -gt $max) { Write-Output "CRITICAL: $text"; Write-Output $notes; exit 1 }
Write-Output "OK: $text"
Write-Output $notes
exit 0
