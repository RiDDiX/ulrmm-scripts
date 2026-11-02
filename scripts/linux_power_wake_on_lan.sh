#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows or enables Wake-on-LAN (magic packet) on a network interface and makes it persistent when NetworkManager or systemd-networkd manages it.
# Variables: ACTION (status, enable; default status), INTERFACE (optional, default: first physical interface).
# Exit codes: 0 ok, 1 failed or WoL still off, 3 bad input, no hardware interface or no ethtool.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

act=${ACTION:-status}
ifc=${INTERFACE:-}
case $act in status | enable) ;; *) echo "ACTION must be status or enable"; exit 3 ;; esac
command -v ethtool >/dev/null 2>&1 || { echo "ethtool not found: install the ethtool package"; exit 3; }
if [ -n "$ifc" ]; then
  case $ifc in -* | *[!A-Za-z0-9_.:-]*) echo "INTERFACE has characters that are not allowed"; exit 3 ;; esac
  [ ${#ifc} -le 15 ] || { echo "INTERFACE is too long"; exit 3; }
else
  for p in /sys/class/net/*; do
    [ -e "$p/device" ] && [ ! -e "$p/wireless" ] && ifc=${p##*/} && break
  done
  [ -n "$ifc" ] || { echo "No physical wired network interface found (virtual machine or container)"; exit 3; }
fi
[ -d "/sys/class/net/$ifc" ] || { echo "Interface $ifc does not exist"; exit 3; }

wol() { ethtool "$ifc" 2>/dev/null | awk -F': ' '/^[ \t]*Wake-on:/ {print $2}'; }
sup=$(ethtool "$ifc" 2>/dev/null | awk -F': ' '/Supports Wake-on:/ {print $2}')
case $sup in *g*) ;; *) echo "$ifc does not support magic packet wake (supports: ${sup:-none})"; exit 3 ;; esac
cur=$(wol)
if [ "$act" = status ]; then
  echo "$ifc Wake-on: $cur"
  case $cur in *g*) exit 0 ;; *) exit 1 ;; esac
fi

changed=
case $cur in *g*) ;; *) ethtool -s "$ifc" wol g >/dev/null 2>&1 || { echo "ethtool could not enable WoL on $ifc"; exit 1; }; changed=1 ;; esac
cur=$(wol)
case $cur in *g*) ;; *) echo "$ifc still reports Wake-on: $cur"; exit 1 ;; esac

how=
if command -v nmcli >/dev/null 2>&1 && nmcli -t -f DEVICE,STATE device 2>/dev/null | grep -q "^$ifc:"; then
  con=$(nmcli -t -g GENERAL.CONNECTION device show "$ifc" 2>/dev/null)
  if [ -n "$con" ] && nmcli connection modify "$con" 802-3-ethernet.wake-on-lan magic >/dev/null 2>&1; then
    how="NetworkManager profile $con"
  fi
fi
# only the first matching .link file applies, and netplan generates 10-netplan-*.link
if [ -z "$how" ] && command -v netplan >/dev/null 2>&1; then
  echo "$ifc Wake-on: $cur${changed:+ (enabled now)}; not persistent: netplan manages $ifc, add wakeonlan: true to it in /etc/netplan and run netplan apply"
  exit 0
fi
if [ -z "$how" ] && [ -d /run/systemd/system ] && command -v networkctl >/dev/null 2>&1 &&
  networkctl list 2>/dev/null | grep -qw "$ifc"; then
  f=/etc/systemd/network/50-ulrmm-wol-$ifc.link
  printf '[Match]\nOriginalName=%s\n\n[Link]\nWakeOnLan=magic\n' "$ifc" >"$f" && how="systemd-networkd link file $f"
fi
if [ -n "$how" ]; then
  echo "$ifc Wake-on: $cur, persistent via $how${changed:+ (enabled now)}"
else
  echo "$ifc Wake-on: $cur${changed:+ (enabled now)}; not persistent: neither NetworkManager nor systemd-networkd manages $ifc, it resets at reboot"
fi
exit 0
