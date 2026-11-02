#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Wi-Fi report: interface, power, SSID where readable, signal, security. No variables.
# Exit: 0 reported, 3 no Wi-Fi interface, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }

dev=$(networksetup -listallhardwareports 2>/dev/null | awk '/^Hardware Port: Wi-Fi/ {f = 1; next} f && /^Device:/ {print $2; exit}')
[ -n "$dev" ] || { echo "No Wi-Fi interface."; exit 3; }
echo "Interface: $dev"
echo "Power: $(networksetup -getairportpower "$dev" 2>/dev/null | sed 's/.*: //')"

info=$(wdutil info 2>/dev/null)
# first match of "key : value" inside the report
wf() { echo "$info" | awk -F' : ' -v k="$1" '{ key = $1; gsub(/^[ \t]+|[ \t]+$/, "", key) } key == k { print $2; exit }'; }
ssid=$(wf SSID)
rssi=$(wf RSSI)
sec=$(wf Security)
if [ -z "$info" ]; then
  sp=$(system_profiler SPAirPortDataType 2>/dev/null | awk '/Current Network Information:/ {f = 1; next} f')
  ssid=$(echo "$sp" | sed -n '1s/^ *\(.*\):$/\1/p')
  rssi=$(echo "$sp" | sed -n 's/^ *Signal \/ Noise: \(-[0-9]*\) dBm.*/\1/p' | head -n 1)
  sec=$(echo "$sp" | sed -n 's/^ *Security: //p' | head -n 1)
fi

if [ -z "$ssid$rssi" ]; then
  echo "Not associated to a network."
  exit 0
fi
case "$ssid" in
'' | *redacted*) echo "SSID: hidden by macOS privacy rules (location permission is not available to the agent)" ;;
*) echo "SSID: $ssid" ;;
esac
[ -n "$rssi" ] && echo "Signal: $rssi"
[ -n "$sec" ] && echo "Security: $sec"
for k in Channel "Tx Rate" "Link Quality"; do
  v=$(wf "$k")
  [ -n "$v" ] && echo "$k: $v"
done
exit 0
