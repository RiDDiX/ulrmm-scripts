# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists installed memory modules (slot, size, type, speed, manufacturer, part number, serial) and the number of slots.
# Variables: none
# Exit: 0 reported, 3 memory information unavailable
$ErrorActionPreference = 'Stop'
$types = @{ 18 = 'DDR'; 19 = 'DDR2'; 20 = 'DDR2 FB-DIMM'; 24 = 'DDR3'; 26 = 'DDR4'; 34 = 'DDR5'; 35 = 'LPDDR5'; 29 = 'LPDDR3'; 30 = 'LPDDR4' }
try {
    $mods = @(Get-CimInstance -ClassName Win32_PhysicalMemory)
    $arrays = @(Get-CimInstance -ClassName Win32_PhysicalMemoryArray)
} catch {
    Write-Output ('Cannot read memory modules: ' + $_.Exception.Message)
    exit 3
}
if ($mods.Count -eq 0) {
    Write-Output 'No physical memory modules reported (virtual machine)'
    exit 0
}
$slots = ($arrays | Measure-Object -Property MemoryDevices -Sum).Sum
$total = ($mods | Measure-Object -Property Capacity -Sum).Sum
Write-Output ('{0} module(s) in {1} slot(s), {2:N1} GB total' -f $mods.Count, $slots, ($total / 1GB))
foreach ($m in ($mods | Sort-Object DeviceLocator)) {
    $type = if ($types.ContainsKey([int]$m.SMBIOSMemoryType)) { $types[[int]$m.SMBIOSMemoryType] } else { 'type ' + $m.SMBIOSMemoryType }
    $speed = if ($m.ConfiguredClockSpeed) { $m.ConfiguredClockSpeed } else { $m.Speed }
    Write-Output ('{0} {1}: {2:N0} GB {3} {4} MHz | {5} {6} | serial {7}' -f $m.BankLabel, $m.DeviceLocator, ($m.Capacity / 1GB), $type, $speed, ([string]$m.Manufacturer).Trim(), ([string]$m.PartNumber).Trim(), ([string]$m.SerialNumber).Trim())
}
exit 0
