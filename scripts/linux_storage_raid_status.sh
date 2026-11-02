#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks Linux software RAID (md) arrays for degraded members and running rebuilds.
# Variables: none
# Exit: 0 all arrays healthy, 1 degraded array, 2 rebuild or check running, 3 no md arrays on this system
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

[ -r /proc/mdstat ] || { echo "No software RAID: /proc/mdstat not present (md driver not loaded)"; exit 3; }
grep -q '^md' /proc/mdstat || { echo "No software RAID arrays configured"; exit 3; }
res=$(awk '
  /^md/ { name = $1; next }
  /\[[U_]+\]/ { if (match($0, /\[[U_]+\]/)) { s = substr($0, RSTART, RLENGTH); st[name] = s; if (s ~ /_/) bad[name] = 1 } }
  /(resync|recovery|reshape|check) *=/ { act[name] = $0 }
  END { for (n in st) print n, st[n], (n in bad) ? "DEGRADED" : "ok", (n in act) ? "ACTIVITY" : "" }' /proc/mdstat | sort)
n=$(printf '%s\n' "$res" | grep -c .)
if printf '%s\n' "$res" | grep -q DEGRADED; then
  echo "ERROR: degraded RAID array found ($n arrays)"; printf '%s\n' "$res"; exit 1
fi
if printf '%s\n' "$res" | grep -q ACTIVITY; then
  echo "WARNING: RAID rebuild or check running ($n arrays)"; printf '%s\n' "$res"; exit 2
fi
echo "OK: $n RAID arrays healthy"
printf '%s\n' "$res"
