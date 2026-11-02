#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks used memory (from MemAvailable) against thresholds and reports swap.
# Variables: WARN_PERCENT (85), ERROR_PERCENT (95)
# Exit: 0 ok, 1 error threshold reached, 2 warning threshold reached, 3 bad input or unsupported system
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

int() {
  case $2 in '' | *[!0-9]*) echo "$1 must be a whole number"; exit 3 ;; esac
  { [ "${#2}" -le 3 ] && [ "$2" -ge 1 ] && [ "$2" -le 100 ]; } || { echo "$1 must be between 1 and 100"; exit 3; }
}
WARN=${WARN_PERCENT:-85}
ERR=${ERROR_PERCENT:-95}
int WARN_PERCENT "$WARN"
int ERROR_PERCENT "$ERR"
[ "$WARN" -lt "$ERR" ] || { echo "WARN_PERCENT must be lower than ERROR_PERCENT"; exit 3; }

mi() { sed -n "s/^$1:[[:space:]]*\([0-9]*\).*/\1/p" /proc/meminfo 2>/dev/null; }
total=$(mi MemTotal)
avail=$(mi MemAvailable)
[ -n "$total" ] && [ -n "$avail" ] || { echo "Unsupported: MemTotal/MemAvailable missing in /proc/meminfo"; exit 3; }
swt=$(mi SwapTotal)
swf=$(mi SwapFree)
used=$((total - avail))
pct=$((used * 100 / total))
mb() { echo $(($1 / 1024)); }
if [ "${swt:-0}" -gt 0 ]; then
  swinfo="swap $(mb $((swt - swf))) of $(mb "$swt") MB used ($(((swt - swf) * 100 / swt))%)"
else
  swinfo="no swap"
fi
msg="$pct% used ($(mb $used) of $(mb "$total") MB, $(mb "$avail") MB available), $swinfo"
if [ "$pct" -ge "$ERR" ]; then echo "ERROR: memory $msg"; exit 1; fi
if [ "$pct" -ge "$WARN" ]; then echo "WARNING: memory $msg"; exit 2; fi
echo "OK: memory $msg"
