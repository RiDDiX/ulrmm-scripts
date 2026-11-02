#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# System report: hardware, macOS, memory, storage, addresses, battery, MDM state. No variables.
# Exit: 0 printed, 3 not macOS.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

[ "$(uname -s)" = Darwin ] || { echo "Not macOS."; exit 3; }

hw=$(system_profiler SPHardwareDataType 2>/dev/null)
field() { echo "$hw" | sed -n "s/^ *$1: //p" | head -n 1; }

echo "Hostname: $(scutil --get ComputerName 2>/dev/null || hostname)"
echo "Model: $(field 'Model Name') ($(sysctl -n hw.model 2>/dev/null))"
chip=$(field 'Chip')
[ -n "$chip" ] || chip=$(field 'Processor Name')
echo "Chip: $chip"
echo "Serial: $(field 'Serial Number (system)')"
echo "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(uname -m)"
boot=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/^{ sec = \([0-9]*\),.*/\1/p')
[ -n "$boot" ] && echo "Uptime: $((($(date +%s) - boot) / 86400)) days, booted $(date -r "$boot" '+%Y-%m-%d %H:%M')"
echo "Memory: $(field 'Memory')"
echo "Storage: $(df -h /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $2 " total, " $4 " free"}')"
echo "Addresses:"
ifconfig 2>/dev/null | awk '/^[a-z0-9]+:/ {sub(":", "", $1); i = $1} /^\tinet / && i != "lo0" {print "  " i " " $2}'
cycles=$(system_profiler SPPowerDataType 2>/dev/null | sed -n 's/^ *Cycle Count: //p' | head -n 1)
[ -n "$cycles" ] && echo "Battery cycle count: $cycles"
mdm=$(profiles status -type enrollment 2>&1 | tr '\n' ';' | sed 's/;$//; s/; */; /g')
echo "MDM enrollment: ${mdm:-unknown}"
exit 0
