#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Uptime check. MAX_DAYS (30): longest accepted time since the last boot.
# Exit: 0 ok, 1 uptime above MAX_DAYS, 3 bad input or not macOS.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

max=${MAX_DAYS:-30}

[ "$(uname -s)" = Darwin ] || { echo "Not macOS."; exit 3; }
case "$max" in '' | *[!0-9]*) echo "MAX_DAYS must be a whole number."; exit 3 ;; esac
[ "$max" -ge 1 ] && [ "$max" -le 3650 ] || { echo "MAX_DAYS must be 1-3650."; exit 3; }

boot=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/^{ sec = \([0-9]*\),.*/\1/p')
case "$boot" in '' | *[!0-9]*) echo "Could not read the boot time."; exit 3 ;; esac
now=$(date +%s)
secs=$((now - boot))
days=$((secs / 86400))
hours=$((secs % 86400 / 3600))
since=$(date -r "$boot" '+%Y-%m-%d %H:%M')

if [ "$days" -ge "$max" ]; then
  echo "FAILING: up $days days $hours h, limit is $max days (booted $since)"
  exit 1
fi
echo "OK: up $days days $hours h, limit is $max days (booted $since)"
exit 0
