#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Looks for out-of-memory kills in the kernel log of the last HOURS hours.
# Variables: HOURS (24)
# Exit: 0 none found, 1 OOM kills found, 3 bad input or no kernel log source
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

H=${HOURS:-24}
case $H in '' | *[!0-9]*) echo "HOURS must be a whole number"; exit 3 ;; esac
{ [ "${#H}" -le 4 ] && [ "$H" -ge 1 ] && [ "$H" -le 720 ]; } || { echo "HOURS must be between 1 and 720"; exit 3; }

pat='out of memory: kill|oom-kill:|invoked oom-killer|oom_reaper'
if [ -d /run/systemd/system ] && command -v journalctl >/dev/null 2>&1; then
  src=journald
  win="$H hours"
  out=$(journalctl -k -q --no-pager --since "$H hours ago" 2>/dev/null | grep -Ei "$pat")
else
  win='no time filter'
  # no timestamps in the ring buffer without journald: whole buffer since boot, say so
  src=''
  out=''
  if d=$(dmesg 2>/dev/null); then
    src="kernel ring buffer since boot"
    out=$(printf '%s\n' "$d" | grep -Ei "$pat")
  fi
  if [ -z "$out" ]; then
    for c in /var/log/kern.log /var/log/messages; do
      [ -r "$c" ] && { src=$c; out=$(grep -Ei "$pat" "$c" | tail -n 200); break; }
    done
  fi
  [ -n "$src" ] || { echo "Unsupported: no journald, no readable dmesg and no kernel log file"; exit 3; }
fi
n=$(printf '%s' "$out" | grep -c .)
if [ "$n" -eq 0 ]; then
  echo "OK: no out-of-memory kills found ($src, $win)"
  exit 0
fi
echo "ERROR: $n out-of-memory log entries ($src, $win)"
printf '%s\n' "$out" | tail -n 20 | cut -c1-300
exit 1
