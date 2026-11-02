#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reads the btrfs device error counters of every mounted btrfs filesystem.
# Variables: none
# Exit: 0 all counters zero, 1 errors recorded, 3 btrfs-progs missing or no btrfs filesystem mounted
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

grep -q ' btrfs ' /proc/mounts 2>/dev/null || { echo "No btrfs filesystem mounted"; exit 3; }
command -v btrfs >/dev/null 2>&1 || { echo "Unsupported: btrfs-progs not installed"; exit 3; }
seen='|' bad='' n=0
nl='
'
while read -r dev mp fs _; do
  [ "$fs" = btrfs ] || continue
  case $seen in *"|$dev|"*) continue ;; esac
  seen="$seen$dev|"
  mp=$(printf '%b' "$mp")
  n=$((n + 1))
  out=$(btrfs device stats -- "$mp" 2>&1) || { bad="$bad$mp: cannot read stats: $(printf '%s' "$out" | head -n 1)$nl"; continue; }
  nz=$(printf '%s\n' "$out" | awk '$2 != 0 {print}')
  [ -n "$nz" ] && bad="$bad$(printf '%s\n' "$nz" | sed "s|^|$mp: |")$nl"
done </proc/mounts
if [ -n "$bad" ]; then
  echo "ERROR: btrfs device errors"
  printf '%s' "$bad"
  exit 1
fi
echo "OK: no btrfs device errors ($n filesystems)"
