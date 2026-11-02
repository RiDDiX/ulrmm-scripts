#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists uid 0 accounts, sudo/wheel/admin members, NOPASSWD sudo rules and accounts with an empty password.
# Variables: none. Exit codes: 0 clean, 1 empty password or an extra uid 0 account, 3 /etc/passwd unreadable.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

[ -r /etc/passwd ] || { echo "/etc/passwd not readable"; exit 3; }
bad=
uid0=$(awk -F: '$3==0 {print $1}' /etc/passwd | tr '\n' ' ')
extra=$(awk -F: '$3==0 && $1!="root" {print $1}' /etc/passwd | tr '\n' ' ')
[ -n "$extra" ] && bad=1
empty=
if [ -r /etc/shadow ]; then
  empty=$(awk -F: '$2=="" {print $1}' /etc/shadow | tr '\n' ' ')
  [ -n "$empty" ] && bad=1
fi
admins=
for g in sudo wheel admin; do
  m=$(getent group "$g" 2>/dev/null | cut -d: -f4 | tr ',' ' ')
  [ -n "$m" ] && admins="$admins $g:[$m]"
done
nopw=$( { cat /etc/sudoers; find /etc/sudoers.d -type f 2>/dev/null | while read -r f; do cat "$f"; done; } 2>/dev/null |
  grep -E '^[^#]*NOPASSWD' | sed 's/[[:space:]]\+/ /g' | cut -c1-120)

if [ -n "$bad" ]; then echo "Privileged access audit: problems found"; else echo "Privileged access audit: no problems"; fi
echo "uid 0 accounts: ${uid0:-none}"
[ -n "$extra" ] && echo "EXTRA uid 0 accounts: $extra"
echo "admin group members:${admins:- none}"
echo "empty password accounts: ${empty:-none}"
if [ -n "$nopw" ]; then
  echo "NOPASSWD sudo rules:"
  printf '%s\n' "$nopw"
else
  echo "NOPASSWD sudo rules: none"
fi
[ -z "$bad" ]
