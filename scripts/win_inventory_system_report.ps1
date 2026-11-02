# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Prints a hardware and operating system summary: model, serial, BIOS, OS build, install date, uptime, CPU, RAM, disks and network adapters.
# Variables: none
# Exit: 0 reported, 3 CIM data unavailable
$ErrorActionPreference = 'Stop'
try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $bios = Get-CimInstance -ClassName Win32_BIOS
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $cpu = @(Get-CimInstance -ClassName Win32_Processor)
    $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3')
    $nics = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True')
} catch {
    Write-Output ('Cannot read system information: ' + $_.Exception.Message)
    exit 3
}
$build = $os.Version
$ubr = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).UBR
if ($null -ne $ubr) { $build = $build + '.' + $ubr }
$up = (Get-Date) - $os.LastBootUpTime
Write-Output ('Host: ' + $env:COMPUTERNAME + ' (' + $cs.Domain + ')')
Write-Output ('Model: ' + $cs.Manufacturer + ' ' + $cs.Model)
Write-Output ('Serial: ' + $bios.SerialNumber)
Write-Output ('BIOS: ' + $bios.Manufacturer + ' ' + $bios.SMBIOSBIOSVersion + ' (' + ('{0:yyyy-MM-dd}' -f $bios.ReleaseDate) + ')')
Write-Output ('OS: ' + $os.Caption + ' ' + $os.OSArchitecture + ', build ' + $build)
Write-Output ('Installed: {0:yyyy-MM-dd}' -f $os.InstallDate)
Write-Output ('Uptime: {0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes)
foreach ($c in $cpu) {
    Write-Output ('CPU: ' + ($c.Name -replace '\s+', ' ').Trim() + ', ' + $c.NumberOfCores + ' cores, ' + $c.NumberOfLogicalProcessors + ' threads')
}
Write-Output ('RAM: {0:N1} GB' -f ($cs.TotalPhysicalMemory / 1GB))
foreach ($d in $disks) {
    Write-Output ('Disk {0} {1:N1} GB free of {2:N1} GB ({3})' -f $d.DeviceID, ($d.FreeSpace / 1GB), ($d.Size / 1GB), $d.FileSystem)
}
foreach ($n in $nics) {
    Write-Output ('NIC: ' + $n.Description + ' | MAC ' + $n.MACAddress + ' | ' + (@($n.IPAddress) -join ', '))
}
exit 0
