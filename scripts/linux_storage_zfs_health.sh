#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks the health of all ZFS pools.
# Variables: none
# Exit: 0 all pools online, 1 a pool is degraded or faulted, 3 ZFS not installed or no pools
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

command -v zpool >/dev/null 2>&1 || { echo "Unsupported: ZFS tools not installed (zfsutils-linux, zfs or zfs-utils)"; exit 3; }
l=$(zpool list -H -o name,health,capacity 2>&1) || { echo "Cannot query ZFS: $(printf '%s' "$l" | head -n 1)"; exit 3; }
[ -n "$l" ] || { echo "No ZFS pools imported"; exit 3; }
bad=$(printf '%s\n' "$l" | awk -F'\t' '$2 != "ONLINE"')
if [ -n "$bad" ]; then
  echo "ERROR: ZFS pool not online"
  printf '%s\n' "$bad" | awk -F'\t' '{print $1 ": " $2}'
  zpool status -x 2>/dev/null | head -n 20
  exit 1
fi
echo "OK: $(printf '%s\n' "$l" | wc -l) ZFS pools online"
printf '%s\n' "$l" | awk -F'\t' '{print $1 ": " $2 ", " $3 " full"}'
