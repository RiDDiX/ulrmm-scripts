#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Counts failed SSH logins of the last HOURS hours and shows the top sources.
# Variables: HOURS (24), THRESHOLD (50, failures that count as a warning)
# Exit: 0 below threshold, 2 threshold reached, 3 bad input or no log source
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

int() {
  case $2 in '' | *[!0-9]*) echo "$1 must be a whole number"; exit 3 ;; esac
  { [ "${#2}" -le 6 ] && [ "$2" -ge 1 ] && [ "$2" -le "$3" ]; } || { echo "$1 must be between 1 and $3"; exit 3; }
}
H=${HOURS:-24}
T=${THRESHOLD:-50}
int HOURS "$H" 168
int THRESHOLD "$T" 1000000

pat='Failed password|Failed publickey|Failed keyboard-interactive|Invalid user'
if [ -d /run/systemd/system ] && command -v journalctl >/dev/null 2>&1; then
  src=journald
  out=$(journalctl -t sshd -t sshd-session -q --no-pager --since "$H hours ago" 2>/dev/null | grep -E "$pat")
else
  f=''
  for c in /var/log/auth.log /var/log/secure; do [ -r "$c" ] && { f=$c; break; }; done
  [ -n "$f" ] || { echo "Unsupported: no journald and no /var/log/auth.log or /var/log/secure"; exit 3; }
  src=$f
  now=$(date +%s)
  pats='|' h=0
  while [ "$h" -le "$H" ]; do
    s=$(date -d "@$((now - h * 3600))" '+%b %e %H|%Y-%m-%dT%H' 2>/dev/null) || { echo "Unsupported: date cannot convert epoch times"; exit 3; }
    pats="$pats${s%|*}|${s#*|}|"
    h=$((h + 1))
  done
  out=$(awk -v p="$pats" 'index(p, "|" substr($0, 1, 9) "|") || index(p, "|" substr($0, 1, 13) "|")' "$f" | grep -E "$pat")
fi
n=$(printf '%s' "$out" | grep -c .)
if [ "$n" -ge "$T" ]; then v="WARNING"; rc=2; else v="OK"; rc=0; fi
echo "$v: $n failed SSH logins in the last $H hours (threshold $T, $src)"
if [ "$n" -gt 0 ]; then
  echo "Top sources:"
  printf '%s\n' "$out" | sed -n 's/.* from \([0-9A-Fa-f.:]*\)\( port.*\)\{0,1\}$/\1/p' | sort | uniq -c | sort -rn | head -n 5
fi
exit $rc
