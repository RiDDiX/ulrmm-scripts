#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports the SELinux and AppArmor state.
# Variables: none. Exit codes: 0 one of them enforcing, 2 none enforcing (disabled, permissive or absent).
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

enf=
se=absent
if command -v getenforce >/dev/null 2>&1; then
  se=$(getenforce 2>/dev/null)
elif [ -r /sys/fs/selinux/enforce ]; then
  case $(cat /sys/fs/selinux/enforce) in 1) se=Enforcing ;; *) se=Permissive ;; esac
fi
[ "$se" = Enforcing ] && enf=1
aa=absent
if [ -r /sys/module/apparmor/parameters/enabled ] && [ "$(cat /sys/module/apparmor/parameters/enabled)" = Y ]; then
  prof=/sys/kernel/security/apparmor/profiles
  if [ -r "$prof" ]; then
    total=$(wc -l <"$prof")
    encl=$(grep -c '(enforce)' "$prof")
    aa="enabled, $total profile(s), $encl enforcing"
    [ "$encl" -gt 0 ] && enf=1
  else
    aa="enabled in kernel, profiles not readable"
  fi
elif command -v aa-status >/dev/null 2>&1; then
  aa="tools installed, kernel module off"
fi
echo "SELinux: $se"
echo "AppArmor: $aa"
if [ -n "$enf" ]; then
  echo "Mandatory access control is enforcing"
  exit 0
fi
echo "No mandatory access control is enforcing"
exit 2
