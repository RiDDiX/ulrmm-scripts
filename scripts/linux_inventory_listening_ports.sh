#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists listening TCP and UDP sockets with the owning process (ss, netstat, or /proc without names).
# Variables: none
# Exit: 0 report printed, 3 no way to read sockets
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

if command -v ss >/dev/null 2>&1; then
  echo "Proto Local address               Process"
  ss -H -l -n -t -u -p 2>/dev/null | awk '{p = ""; if (match($0, /users:\(\("[^"]*"/)) p = substr($0, RSTART + 9, RLENGTH - 9); gsub(/"/, "", p); printf "%-5s %-26s %s\n", $1, $5, p}' | sort -u
elif command -v netstat >/dev/null 2>&1 && netstat -ltnp >/dev/null 2>&1; then
  echo "Proto Local address               Process"
  netstat -l -n -t -u -p 2>/dev/null | awk '$1 ~ /^(tcp|udp)/ {pid = $NF; if ($1 ~ /^udp/ && NF < 6) pid = "-"; printf "%-5s %-26s %s\n", $1, $4, pid}' | sort -u
elif [ -r /proc/net/tcp ]; then
  echo "Proto Port   (no ss or netstat installed: process names unavailable)"
  for f in tcp tcp6 udp udp6; do
    [ -r /proc/net/$f ] || continue
    awk -v pr="$f" '
      function hex(s,  i, v) { v = 0; for (i = 1; i <= length(s); i++) v = v * 16 + index("0123456789ABCDEF", toupper(substr(s, i, 1))) - 1; return v }
      NR > 1 && (($4 == "0A" && pr ~ /^tcp/) || ($4 == "07" && pr ~ /^udp/)) { n = split($2, a, ":"); printf "%-5s %s\n", pr, hex(a[n]) }' /proc/net/$f
  done | sort -u
else
  echo "Unsupported: no ss, netstat or /proc/net"
  exit 3
fi
