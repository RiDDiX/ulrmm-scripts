#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists the largest first-level directories under PATH, staying on one filesystem.
# Variables: PATH_TO_SCAN (/), TOP (15)
# Exit: 0 report printed, 3 bad input
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

P=${PATH_TO_SCAN:-/}
case $P in /*) ;; *) echo "PATH_TO_SCAN must be an absolute path"; exit 3 ;; esac
case $P in *[!A-Za-z0-9/._+@\ -]*) echo "PATH_TO_SCAN has characters that are not allowed"; exit 3 ;; esac
[ -d "$P" ] || { echo "PATH_TO_SCAN is not a directory: $P"; exit 3; }
N=${TOP:-15}
case $N in '' | *[!0-9]*) echo "TOP must be a whole number"; exit 3 ;; esac
{ [ "${#N}" -le 3 ] && [ "$N" -ge 1 ] && [ "$N" -le 200 ]; } || { echo "TOP must be between 1 and 200"; exit 3; }
P=${P%/}

tab=$(printf '\t')
echo "Largest directories under ${P:-/} (one filesystem)"
for e in "$P"/* "$P"/.[!.]* "$P"/..?*; do
  [ -d "$e" ] && [ ! -L "$e" ] || continue
  du -x -k -s "$e" 2>/dev/null
done | sort -rn | head -n "$N" | while IFS="$tab" read -r kb name; do
  if [ "$kb" -ge 1048576 ]; then v=$((kb * 10 / 1048576)); u=G
  elif [ "$kb" -ge 1024 ]; then v=$((kb * 10 / 1024)); u=M
  else v=$((kb * 10)); u=K; fi
  printf '%6s.%s %s  %s\n' "$((v / 10))" "$((v % 10))" "$u" "$name"
done
