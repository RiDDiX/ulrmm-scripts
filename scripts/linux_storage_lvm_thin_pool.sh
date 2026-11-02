#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks data and metadata usage of LVM thin pools.
# Variables: WARN_PERCENT (80), ERROR_PERCENT (90)
# Exit: 0 ok, 1 error threshold reached, 2 warning threshold reached, 3 bad input, no LVM or no thin pools
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

int() {
  case $2 in '' | *[!0-9]*) echo "$1 must be a whole number"; exit 3 ;; esac
  { [ "${#2}" -le 3 ] && [ "$2" -ge 1 ] && [ "$2" -le 100 ]; } || { echo "$1 must be between 1 and 100"; exit 3; }
}
WARN=${WARN_PERCENT:-80}
ERR=${ERROR_PERCENT:-90}
int WARN_PERCENT "$WARN"
int ERROR_PERCENT "$ERR"
[ "$WARN" -lt "$ERR" ] || { echo "WARN_PERCENT must be lower than ERROR_PERCENT"; exit 3; }
command -v lvs >/dev/null 2>&1 || { echo "Unsupported: LVM tools not installed (lvm2)"; exit 3; }
out=$(lvs --noheadings --separator '|' -o vg_name,lv_name,lv_attr,data_percent,metadata_percent 2>&1) || { echo "Cannot query LVM: $(printf '%s' "$out" | head -n 1)"; exit 3; }
pools=$(printf '%s\n' "$out" | awk -F'|' '{gsub(/^ +/, "", $1); if ($3 ~ /^ *t/) print $1 "/" $2 "|" $4 "|" $5}')
[ -n "$pools" ] || { echo "No LVM thin pools on this system"; exit 3; }
res=$(printf '%s\n' "$pools" | awk -F'|' -v w="$WARN" -v e="$ERR" '{
  d = $2 + 0; m = $3 + 0; s = "ok"
  if (d >= e || m >= e) s = "ERROR"; else if (d >= w || m >= w) s = "WARN"
  printf "%s %s data %.1f%% metadata %.1f%%\n", s, $1, d, m }')
if printf '%s\n' "$res" | grep -q '^ERROR'; then echo "ERROR: thin pool at or above $ERR%"; rc=1
elif printf '%s\n' "$res" | grep -q '^WARN'; then echo "WARNING: thin pool at or above $WARN%"; rc=2
else echo "OK: $(printf '%s\n' "$res" | wc -l) thin pools below $WARN%"; rc=0; fi
printf '%s\n' "$res"
exit $rc
