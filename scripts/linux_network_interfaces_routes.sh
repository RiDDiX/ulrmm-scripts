#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists network interfaces with state, MAC and addresses, plus the IPv4 and IPv6 routing tables.
# Variables: none
# Exit: 0 report printed, 3 no tool or /proc data to read interfaces
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

if command -v ip >/dev/null 2>&1; then
  echo "Interfaces:"
  ip -o link show 2>/dev/null | awk '{mac = ""; for (i = 1; i <= NF; i++) { if ($i == "link/ether") mac = $(i + 1); if ($i == "mtu") mtu = $(i + 1); if ($i == "state") st = $(i + 1) } printf "  %-14s %-8s mtu %-6s %s\n", $2, st, mtu, mac}'
  echo "Addresses:"
  ip -o addr show 2>/dev/null | awk '$3 ~ /^inet/ {print "  " $2 " " $3 " " $4}'
  echo "IPv4 routes:"
  ip -4 route show 2>/dev/null | sed 's/^/  /'
  echo "IPv6 routes:"
  ip -6 route show 2>/dev/null | sed 's/^/  /'
elif command -v ifconfig >/dev/null 2>&1; then
  echo "Interfaces:"
  ifconfig -a 2>/dev/null | sed 's/^/  /'
  echo "Routes:"
  { route -n 2>/dev/null || netstat -rn 2>/dev/null; } | sed 's/^/  /'
elif [ -r /proc/net/dev ]; then
  echo "Interfaces (no ip or ifconfig installed, names only):"
  awk 'NR > 2 {sub(":", "", $1); print "  " $1}' /proc/net/dev
  echo "IPv4 routes (hex):"
  awk 'NR > 1 {print "  " $1 " dest " $2 " gw " $3}' /proc/net/route
else
  echo "Unsupported: no ip, ifconfig or /proc/net"
  exit 3
fi
