#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks the 5-minute load average per CPU core against thresholds.
# Variables: WARN_PER_CORE (1.5), ERROR_PER_CORE (3)
# Exit: 0 ok, 1 error threshold reached, 2 warning threshold reached, 3 bad input or unsupported system
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

dec() {
  case $2 in '' | *[!0-9.]* | *.*.* | . | .* | *.) echo "$1 must be a positive number like 1.5"; exit 3 ;; esac
  [ "${#2}" -le 7 ] || { echo "$1 is too long"; exit 3; }
}
# decimal text to hundredths
cent() {
  i=${1%%.*}
  i=$(printf '%s' "$i" | sed 's/^0*//')
  case $1 in *.*) f=${1#*.} ;; *) f= ;; esac
  f=$(printf '%s00' "$f" | cut -c1-2)
  echo $((${i:-0} * 100 + 1$f - 100))
}
WARN=${WARN_PER_CORE:-1.5}
ERR=${ERROR_PER_CORE:-3}
dec WARN_PER_CORE "$WARN"
dec ERROR_PER_CORE "$ERR"
wc100=$(cent "$WARN")
ec100=$(cent "$ERR")
[ "$wc100" -lt "$ec100" ] || { echo "WARN_PER_CORE must be lower than ERROR_PER_CORE"; exit 3; }

[ -r /proc/loadavg ] || { echo "Unsupported: /proc/loadavg not readable"; exit 3; }
cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
case $cores in '' | 0 | *[!0-9]*) cores=$(nproc 2>/dev/null || echo 1) ;; esac
read -r l1 l5 l15 _ </proc/loadavg
l100=$(cent "$l5")
per=$((l100 / cores))
per=$(printf '%d.%02d' $((per / 100)) $((per % 100)))
msg="load $l1 $l5 $l15 on $cores cores, 5 min per core $per"
if [ "$l100" -ge $((ec100 * cores)) ]; then echo "ERROR: $msg (limit $ERR)"; exit 1; fi
if [ "$l100" -ge $((wc100 * cores)) ]; then echo "WARNING: $msg (limit $WARN)"; exit 2; fi
echo "OK: $msg"
