# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports the antivirus products registered in Security Center with their state; on server editions it falls back
#   to Microsoft Defender status and the uninstall keys.
# Variables: none.
# Exit: 0 an antivirus is active and current, 1 no active antivirus, 2 outdated signatures or several active products.

$rows = @()
$scError = $null
try {
    $products = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop)
} catch {
    $scError = $_.Exception.Message
}

if (-not $scError) {
    # productState is undocumented; byte 2 0x10/0x11 means on, byte 3 0x10 means signatures out of date.
    foreach ($a in $products) {
        $state = [uint32]$a.productState
        $rows += [pscustomobject]@{
            Name    = $a.displayName
            On      = (($state -shr 8) -band 0xF0) -eq 0x10
            Current = ($state -band 0xF0) -eq 0
            Detail  = ('state 0x{0:X6}, {1}' -f $state, $a.pathToSignedReportingExe)
        }
    }
} else {
    $mp = $null
    try { $mp = Get-MpComputerStatus -ErrorAction Stop } catch { $mp = $null }
    if ($mp) {
        $rows += [pscustomobject]@{
            Name    = 'Microsoft Defender Antivirus'
            On      = [bool]($mp.AntivirusEnabled -and $mp.RealTimeProtectionEnabled)
            Current = $mp.AntivirusSignatureAge -le 7
            Detail  = "signatures $($mp.AntivirusSignatureAge) day(s) old, real-time $($mp.RealTimeProtectionEnabled)"
        }
    }
    $vendors = '^(ESET|Bitdefender|Kaspersky|Avast|AVG (AntiVirus|Internet)|Avira|Malwarebytes|Sophos|Norton|McAfee|F-Secure|WithSecure|Trend Micro|G DATA|Symantec|Webroot|Panda)'
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match $vendors -and $_.DisplayName -notmatch 'Management Agent|Remover|Uninstall' } |
        Sort-Object DisplayName -Unique | ForEach-Object {
            $rows += [pscustomobject]@{ Name = $_.DisplayName; On = $true; Current = $true
                Detail = "version $($_.DisplayVersion), installed (state only visible in the vendor console)" }
        }
}

$active = @($rows | Where-Object { $_.On })
if ($active.Count -eq 0) {
    Write-Output 'FAIL: no active antivirus'
    $rc = 1
} elseif (@($active | Where-Object { -not $_.Current }).Count -gt 0) {
    Write-Output "WARNING: signatures out of date: $((@($active | Where-Object { -not $_.Current }) | ForEach-Object { $_.Name }) -join ', ')"
    $rc = 2
} elseif ($active.Count -gt 1 -and -not $scError) {
    Write-Output "WARNING: several active products: $(($active | ForEach-Object { $_.Name }) -join ', ')"
    $rc = 2
} else {
    Write-Output "OK: $(($active | ForEach-Object { $_.Name }) -join ', ')"
    $rc = 0
}
if ($scError) { Write-Output 'Source: Defender status and uninstall keys (no Security Center on this edition)' }
foreach ($r in $rows) {
    $on = if ($r.On) { 'on' } else { 'off' }
    Write-Output "$($r.Name): $on, $($r.Detail)"
}
exit $rc
