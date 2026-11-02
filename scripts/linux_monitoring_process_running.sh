#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks that every listed process name is running (matches the kernel process name, max 15 characters).
# Variables: PROCESSES (names, comma or line separated, required)
# Exit: 0 all running, 1 at least one not running, 3 bad input
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

LIST=$(printf '%s\n' "${PROCESSES:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d')
[ -n "$LIST" ] || { echo "PROCESSES is required"; exit 3; }
case $(printf %s "$LIST" | tr -d "\n") in *[!A-Za-z0-9._+:@-]* | -*) echo "PROCESSES: names may only contain letters, digits and ._+:@- and no spaces"; exit 3 ;; esac
printf '%s\n' "$LIST" | grep -q '^-' && { echo "A process name must not start with a dash"; exit 3; }
[ -r /proc/self/comm ] || { echo "Unsupported: /proc not available"; exit 3; }

names=$(cat /proc/[0-9]*/comm 2>/dev/null)
nl='
'
down='' up=0 n=0
for p in $LIST; do
  n=$((n + 1))
  k=$(printf '%s' "$p" | cut -c1-15)
  c=$(printf '%s\n' "$names" | grep -cxF -- "$k")
  if [ "$c" -gt 0 ]; then up=$((up + 1)); else down="$down$p: not running$nl"; fi
done
if [ -z "$down" ]; then
  echo "OK: $up of $n processes running"
  exit 0
fi
echo "ERROR: $((n - up)) of $n processes not running"
printf '%s' "$down"
exit 1
