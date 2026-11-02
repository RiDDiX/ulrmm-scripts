# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports the Entra ID (Azure AD), hybrid and on-premises domain join state from dsregcmd /status.
# Variables: none
# Exit: 0 reported, 3 dsregcmd.exe not available
$ErrorActionPreference = 'Stop'
$exe = Join-Path $env:SystemRoot 'System32\dsregcmd.exe'
if (-not (Test-Path $exe)) {
    Write-Output 'dsregcmd.exe is not available on this system'
    exit 3
}
$ErrorActionPreference = 'Continue'
$out = & $exe /status 2>&1
$rc = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($rc -ne 0) {
    Write-Output ('dsregcmd failed with exit code ' + $rc)
    exit 3
}
$v = @{}
foreach ($line in $out) {
    if (([string]$line) -match '^\s*([A-Za-z]+)\s*:\s*(.*?)\s*$') {
        if (-not $v.ContainsKey($Matches[1])) { $v[$Matches[1]] = $Matches[2] }
    }
}
$aad = $v['AzureAdJoined'] -eq 'YES'
$dom = $v['DomainJoined'] -eq 'YES'
$ws = $v['WorkplaceJoined'] -eq 'YES'
if ($aad -and $dom) { $type = 'hybrid joined (Entra ID and on-premises domain)' }
elseif ($aad) { $type = 'Entra ID joined' }
elseif ($dom) { $type = 'on-premises domain joined only' }
elseif ($ws) { $type = 'Entra ID registered (workplace)' }
else { $type = 'not joined' }
Write-Output ('Join state: ' + $type)
foreach ($k in 'AzureAdJoined', 'DomainJoined', 'WorkplaceJoined', 'EnterpriseJoined', 'TenantName', 'TenantId', 'DeviceId', 'DomainName', 'MdmUrl', 'AzureAdPrt') {
    if ($v.ContainsKey($k) -and $v[$k]) { Write-Output ('{0}: {1}' -f $k, $v[$k]) }
}
exit 0
