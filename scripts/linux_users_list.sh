#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists login-capable accounts with groups, locked state, last login and number of SSH keys.
# Variables: none. Exit codes: 0 done, 3 /etc/passwd unreadable.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

[ -r /etc/passwd ] || { echo "/etc/passwd not readable"; exit 3; }
umin=$(awk '$1=="UID_MIN" {print $2}' /etc/login.defs 2>/dev/null)
umin=${umin:-1000}
case $umin in *[!0-9]*) umin=1000 ;; esac
tmp=$(mktemp) || exit 3
trap 'rm -f "$tmp"' EXIT
awk -F: -v m="$umin" '($3==0 || $3>=m) && $3<65534 && $7!~/(nologin|false|sync|shutdown|halt)$/ && $7!="" {print $1":"$3":"$6}' /etc/passwd >"$tmp"
echo "$(wc -l <"$tmp") login-capable account(s)"
printf '%-16s %-6s %-22s %-7s %-4s %s\n' USER UID GROUPS STATE KEYS LAST
while IFS=: read -r u uid home; do
  groups=$(id -Gn "$u" 2>/dev/null | tr ' ' ',' | cut -c1-22)
  pw=$(awk -F: -v u="$u" '$1==u {print $2}' /etc/shadow 2>/dev/null)
  case $pw in '!'* | '*'*) state=locked ;; '') state=nopass ;; *) state=active ;; esac
  keys=0
  f=$home/.ssh/authorized_keys
  [ -f "$f" ] && keys=$(grep -Ecv '^[[:space:]]*(#|$)' "$f")
  last=never
  if command -v lastlog >/dev/null 2>&1; then
    l=$(lastlog -u "$u" 2>/dev/null | sed -n '2p')
    case $l in *"Never logged in"*) ;; '') last=n/a ;; *) last=$(printf '%s' "$l" | awk '{for (i=1;i<=NF;i++) if ($i ~ /^[0-9]{4}$/) {printf "%s %s %s %s", $(i-4), $(i-3), $(i-2), $i; exit}}') ;; esac
  elif command -v last >/dev/null 2>&1; then
    l=$(last -n 1 "$u" 2>/dev/null | sed -n '1p')
    case $l in '' | wtmp* | *"begins"*) ;; *) last=$(printf '%s' "$l" | awk '{print $4,$5,$6,$7}') ;; esac
  else
    last=n/a
  fi
  printf '%-16s %-6s %-22s %-7s %-4s %s\n' "$u" "$uid" "$groups" "$state" "$keys" "${last:-n/a}"
done <"$tmp"
exit 0
