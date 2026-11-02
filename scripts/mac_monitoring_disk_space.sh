#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Disk space of the data volume. WARN_PERCENT (85), ERROR_PERCENT (95): used space of the APFS container.
# Exit: 0 ok, 1 at or above ERROR_PERCENT, 2 at or above WARN_PERCENT, 3 bad input or not macOS.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

warn=${WARN_PERCENT:-85}
err=${ERROR_PERCENT:-95}

[ "$(uname -s)" = Darwin ] || { echo "Not macOS."; exit 3; }
case "$warn$err" in *[!0-9]*) echo "WARN_PERCENT and ERROR_PERCENT must be whole numbers."; exit 3 ;; esac
[ -n "$warn" ] && [ -n "$err" ] && [ "$warn" -ge 1 ] && [ "$err" -le 100 ] && [ "$warn" -le "$err" ] ||
  { echo "Need 1 <= WARN_PERCENT <= ERROR_PERCENT <= 100."; exit 3; }

mnt=/System/Volumes/Data
[ -d "$mnt" ] || mnt=/
# On APFS the size and available columns are those of the whole container, the used column
# is only this volume. Used percent is taken from container size and free space.
line=$(df -k -P "$mnt" 2>/dev/null | awk 'NR==2 {print $(NF-4), $(NF-2)}')
size=${line% *}
avail=${line#* }
case "${size}x${avail}" in *[!0-9x]* | x* | *x) echo "Could not read df for $mnt."; exit 3 ;; esac
[ "$size" -gt 0 ] || { echo "Could not read df for $mnt."; exit 3; }

pct=$(awk -v s="$size" -v a="$avail" 'BEGIN { printf "%d", ((s - a) * 100 + s - 1) / s }')
gb() { awk -v k="$1" 'BEGIN { printf "%.1f", k / 1048576 }'; }

verdict="OK"
rc=0
if [ "$pct" -ge "$err" ]; then verdict="CRITICAL"; rc=1; elif [ "$pct" -ge "$warn" ]; then verdict="WARNING"; rc=2; fi
echo "$verdict: $mnt is $pct% used ($(gb "$avail") GB free of $(gb "$size") GB)"
echo "Thresholds: warn $warn%, error $err%. Purgeable space counts as used."
exit $rc
