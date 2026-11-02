#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shrinks the systemd journal to a size and optionally an age limit.
# Variables: MAX_SIZE_MB (default 500), MAX_AGE_DAYS (optional, unset = no age limit).
# Exit codes: 0 done, 1 vacuum failed, 3 bad input or no systemd journal.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

size=${MAX_SIZE_MB:-500}
age=${MAX_AGE_DAYS:-}
case $size in '' | *[!0-9]*) echo "MAX_SIZE_MB must be a whole number"; exit 3 ;; esac
[ ${#size} -le 6 ] && [ "$size" -ge 1 ] && [ "$size" -le 100000 ] || { echo "MAX_SIZE_MB must be 1-100000"; exit 3; }
if [ -n "$age" ]; then
  case $age in *[!0-9]*) echo "MAX_AGE_DAYS must be a whole number"; exit 3 ;; esac
  [ ${#age} -le 5 ] && [ "$age" -ge 1 ] && [ "$age" -le 36500 ] || { echo "MAX_AGE_DAYS must be 1-36500"; exit 3; }
fi
command -v journalctl >/dev/null 2>&1 || { echo "journalctl not found: this system has no systemd journal"; exit 3; }
[ -d /run/systemd/system ] || [ -d /var/log/journal ] || { echo "No systemd journal on this system"; exit 3; }

before=$(journalctl --disk-usage 2>&1)
journalctl --rotate >/dev/null 2>&1
journalctl --vacuum-size="${size}M" >/dev/null 2>&1 || { echo "Vacuum by size failed"; exit 1; }
if [ -n "$age" ]; then
  journalctl --vacuum-time="${age}d" >/dev/null 2>&1 || { echo "Vacuum by age failed"; exit 1; }
fi
after=$(journalctl --disk-usage 2>&1)
echo "Journal vacuumed to ${size} MB${age:+ and ${age} days}"
echo "Before: $before"
echo "After:  $after"
exit 0
