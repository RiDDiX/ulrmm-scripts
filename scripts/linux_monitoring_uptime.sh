#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Warns when the machine has been up longer than MAX_DAYS (pending reboots, kernel updates).
# Variables: MAX_DAYS (60)
# Exit: 0 ok, 2 up longer than MAX_DAYS, 3 bad input or unsupported system
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

MAX=${MAX_DAYS:-60}
case $MAX in '' | *[!0-9]*) echo "MAX_DAYS must be a whole number"; exit 3 ;; esac
{ [ "${#MAX}" -le 5 ] && [ "$MAX" -ge 1 ]; } || { echo "MAX_DAYS must be between 1 and 99999"; exit 3; }
[ -r /proc/uptime ] || { echo "Unsupported: /proc/uptime not readable"; exit 3; }
read -r up _ </proc/uptime
secs=${up%%.*}
days=$((secs / 86400))
hours=$((secs % 86400 / 3600))
if [ "$days" -ge "$MAX" ]; then
  echo "WARNING: up $days days $hours h, limit is $MAX days"
  exit 2
fi
echo "OK: up $days days $hours h, limit is $MAX days"
