# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks Active Directory replication of this domain controller with its partners.
# Variables: none
# Exit: 0 all partners replicate, 1 a replication failure exists, 3 not a domain controller or no AD tooling
$ErrorActionPreference = 'Stop'
$cs = Get-CimInstance -ClassName Win32_ComputerSystem
if ($cs.DomainRole -lt 4) {
    Write-Output 'This computer is not a domain controller'
    exit 3
}
$failures = @()
$lines = @()
if (Get-Module -ListAvailable -Name ActiveDirectory) {
    try {
        Import-Module ActiveDirectory
        $meta = @(Get-ADReplicationPartnerMetadata -Target $env:COMPUTERNAME -Scope Server -Partition *)
    } catch {
        Write-Output ('Cannot read replication metadata: ' + $_.Exception.Message)
        exit 3
    }
    foreach ($m in $meta) {
        $partner = ([string]$m.Partner -split ',')[1] -replace '^CN=', ''
        $lines += ('{0} / {1}: last success {2:yyyy-MM-dd HH:mm}, result {3}, failures {4}' -f $partner, $m.Partition, $m.LastReplicationSuccess, $m.LastReplicationResult, $m.ConsecutiveReplicationFailures)
        if ($m.LastReplicationResult -ne 0 -or $m.ConsecutiveReplicationFailures -gt 0) {
            $failures += ($partner + ' / ' + $m.Partition)
        }
    }
    $count = $meta.Count
} else {
    $exe = Join-Path $env:SystemRoot 'System32\repadmin.exe'
    if (-not (Test-Path $exe)) {
        Write-Output 'Neither the ActiveDirectory module nor repadmin.exe is available'
        exit 3
    }
    $ErrorActionPreference = 'Continue'
    $csv = & $exe /showrepl $env:COMPUTERNAME /csv 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($rc -ne 0) {
        Write-Output ('repadmin failed with exit code ' + $rc)
        exit 3
    }
    $rows = @($csv | ForEach-Object { [string]$_ } | Where-Object { $_ -like 'showrepl_*' } | ConvertFrom-Csv | Where-Object { $_.'Source DSA' })
    foreach ($r in $rows) {
        $n = 0
        [void][int]::TryParse([string]$r.'Number of Failures', [ref]$n)
        $lines += ('{0} / {1}: last success {2}, failures {3}' -f $r.'Source DSA', $r.'Naming Context', $r.'Last Success Time', $n)
        if ($n -gt 0) { $failures += ([string]$r.'Source DSA' + ' / ' + $r.'Naming Context') }
    }
    $count = $rows.Count
}
if ($count -eq 0) {
    Write-Output 'OK: no replication partners (single domain controller)'
    exit 0
}
if ($failures.Count -gt 0) {
    Write-Output ('FAIL: ' + $failures.Count + ' replication failure(s) of ' + $count + ' link(s)')
} else {
    Write-Output ('OK: ' + $count + ' replication link(s) healthy')
}
$lines | ForEach-Object { Write-Output ('  ' + $_) }
if ($failures.Count -gt 0) { exit 1 }
exit 0
