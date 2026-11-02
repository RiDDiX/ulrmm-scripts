#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Runs fstrim on all mounted filesystems that support it.
# Variables: none. Exit codes: 0 done, 1 trim failed, 3 fstrim missing or not possible here (container, no discard).
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v fstrim >/dev/null 2>&1 || { echo "fstrim not found: install util-linux"; exit 3; }
if [ -f /.dockerenv ] || grep -qaE 'docker|lxc|containerd|kubepods' /proc/1/cgroup 2>/dev/null; then
  echo "Running in a container, the host has to trim"
  exit 3
fi
out=$(fstrim -av 2>&1)
rc=$?
echo "$out"
if [ "$rc" -ne 0 ] && [ -z "$out" ]; then
  echo "No filesystem supports trim here"
  exit 3
fi
[ "$rc" -eq 0 ] || exit 1
exit 0
