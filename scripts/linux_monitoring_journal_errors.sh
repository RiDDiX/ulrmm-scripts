#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports error-level log entries of the last HOURS hours (journald, else /var/log/messages or syslog).
# Variables: HOURS (24), MAX (30, entries shown)
# Exit: 0 no errors, 2 errors found, 3 bad input or no log source
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

int() {
  case $2 in '' | *[!0-9]*) echo "$1 must be a whole number"; exit 3 ;; esac
  { [ "${#2}" -le 4 ] && [ "$2" -ge 1 ] && [ "$2" -le "$3" ]; } || { echo "$1 must be between 1 and $3"; exit 3; }
}
H=${HOURS:-24}
M=${MAX:-30}
int HOURS "$H" 168
int MAX "$M" 500

if [ -d /run/systemd/system ] && command -v journalctl >/dev/null 2>&1; then
  src=journald
  out=$(journalctl -p err -q --no-pager --since "$H hours ago" 2>/dev/null)
else
  f=''
  for c in /var/log/messages /var/log/syslog; do [ -r "$c" ] && { f=$c; break; }; done
  [ -n "$f" ] || { echo "Unsupported: no journald and no /var/log/messages or /var/log/syslog"; exit 3; }
  src=$f
  now=$(date +%s)
  pats='|' h=0
  while [ "$h" -le "$H" ]; do
    s=$(date -d "@$((now - h * 3600))" '+%b %e %H|%Y-%m-%dT%H' 2>/dev/null) || { echo "Unsupported: date cannot convert epoch times"; exit 3; }
    pats="$pats${s%|*}|${s#*|}|"
    h=$((h + 1))
  done
  out=$(awk -v p="$pats" 'index(p, "|" substr($0, 1, 9) "|") || index(p, "|" substr($0, 1, 13) "|")' "$f" | grep -Ei 'error|fail|critical|fatal|panic' )
fi
n=$(printf '%s' "$out" | grep -c .)
if [ "$n" -eq 0 ]; then
  echo "OK: no error entries in the last $H hours ($src)"
  exit 0
fi
echo "WARNING: $n error entries in the last $H hours ($src), last $M shown"
printf '%s\n' "$out" | tail -n "$M" | cut -c1-300
exit 2
