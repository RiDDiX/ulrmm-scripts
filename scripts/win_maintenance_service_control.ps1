# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows the state of a service or starts, stops or restarts it.
# Variables: SERVICE service name or display name; ACTION (status) status, start, stop or restart.
# Exit: 0 done, 1 the service is not in the wanted state, 3 bad input or unknown service.
$name = ''
if ($env:SERVICE) { $name = $env:SERVICE.Trim() }
if (-not $name -or $name -match '[\*\?\[\]]') { Write-Output 'SERVICE is required and must not contain wildcards'; exit 3 }
$action = 'status'
if ($env:ACTION) { $action = $env:ACTION.Trim().ToLower() }
if ('status', 'start', 'stop', 'restart' -notcontains $action) { Write-Output 'ACTION must be status, start, stop or restart'; exit 3 }

$svc = Get-Service -Name $name -ErrorAction SilentlyContinue
if (-not $svc) { $svc = Get-Service -DisplayName $name -ErrorAction SilentlyContinue | Select-Object -First 1 }
if (-not $svc) { Write-Output "Service '$name' not found"; exit 3 }

function Write-State {
    $svc.Refresh()
    $cim = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $svc.Name.Replace("'", "''"))
    Write-Output ("{0} ({1}): {2}, start type {3}" -f $svc.Name, $svc.DisplayName, $svc.Status, $cim.StartMode)
}

try {
    $want = $null
    switch ($action) {
        'start' { if ($svc.Status -ne 'Running') { Start-Service -InputObject $svc -ErrorAction Stop }; $want = 'Running' }
        'stop' { if ($svc.Status -ne 'Stopped') { Stop-Service -InputObject $svc -Force -ErrorAction Stop }; $want = 'Stopped' }
        'restart' { Restart-Service -InputObject $svc -Force -ErrorAction Stop; $want = 'Running' }
    }
    if ($want) { $svc.WaitForStatus($want, [TimeSpan]::FromSeconds(60)) }
    Write-State
    if ($want -and $svc.Status.ToString() -ne $want) { exit 1 }
    exit 0
} catch {
    Write-Output "$action failed: $($_.Exception.Message)"
    Write-State
    exit 1
}
