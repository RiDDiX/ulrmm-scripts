#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks that every listed port has a listener (read from /proc/net, no extra tools needed).
# Variables: PORTS (1-65535, optionally prefixed tcp: or udp:, default tcp; comma or line separated, required)
# Exit: 0 all listening, 1 at least one port closed, 3 bad input
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

LIST=$(printf '%s\n' "${PORTS:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d')
[ -n "$LIST" ] || { echo "PORTS is required"; exit 3; }
for p in $LIST; do
  case $p in tcp:* | udp:*) num=${p#*:} ;; *) num=$p ;; esac
  case $num in '' | *[!0-9]*) echo "Bad port: $p"; exit 3 ;; esac
  { [ "${#num}" -le 5 ] && [ "$num" -ge 1 ] && [ "$num" -le 65535 ]; } || { echo "Port out of range: $p"; exit 3; }
done
[ -r /proc/net/tcp ] || { echo "Unsupported: /proc/net/tcp not readable"; exit 3; }

# listening sockets as proto:port lines
open=$(
  for f in tcp tcp6 udp udp6; do
    [ -r /proc/net/$f ] || continue
    awk -v pr="${f%6}" '
      function hex(s,  i, v, c) { v = 0; for (i = 1; i <= length(s); i++) { c = index("0123456789ABCDEF", toupper(substr(s, i, 1))) - 1; v = v * 16 + c } return v }
      NR > 1 && (($4 == "0A" && pr == "tcp") || ($4 == "07" && pr == "udp")) { n = split($2, a, ":"); print pr ":" hex(a[n]) }' /proc/net/$f
  done | sort -u
)
nl='
'
down='' up=0 n=0
for p in $LIST; do
  n=$((n + 1))
  case $p in tcp:* | udp:*) k=$p ;; *) k=tcp:$p ;; esac
  if printf '%s\n' "$open" | grep -qxF -- "$k"; then up=$((up + 1)); else down="$down$k: nothing listening$nl"; fi
done
if [ -z "$down" ]; then
  echo "OK: $up of $n ports listening"
  exit 0
fi
echo "ERROR: $((n - up)) of $n ports not listening"
printf '%s' "$down"
exit 1
