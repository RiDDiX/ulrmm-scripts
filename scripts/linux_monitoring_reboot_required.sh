#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports whether a reboot is pending: package manager flag first, then running vs newest installed kernel.
# Variables: none
# Exit: 0 no reboot needed, 2 reboot required, 3 cannot be determined on this system
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

if [ -e /var/run/reboot-required ]; then
  pk=$(tr '\n' ' ' 2>/dev/null </var/run/reboot-required.pkgs)
  echo "WARNING: reboot required${pk:+ by: $pk}"
  exit 2
fi
rc=''
if command -v needs-restarting >/dev/null 2>&1; then
  needs-restarting -r >/dev/null 2>&1
  rc=$?
elif command -v dnf >/dev/null 2>&1 && dnf needs-restarting --help >/dev/null 2>&1; then
  dnf -q needs-restarting -r >/dev/null 2>&1
  rc=$?
fi
case $rc in
0) echo "OK: no reboot required (needs-restarting)"; exit 0 ;;
1) echo "WARNING: reboot required (needs-restarting -r)"; exit 2 ;;
esac
if command -v zypper >/dev/null 2>&1; then
  zypper -q needs-rebooting >/dev/null 2>&1
  case $? in
  0) echo "OK: no reboot required (zypper needs-rebooting)"; exit 0 ;;
  102) echo "WARNING: reboot required (zypper needs-rebooting)"; exit 2 ;;
  esac
fi

run=$(uname -r)
dir=''
for d in /usr/lib/modules /lib/modules; do
  [ -d "$d" ] && [ -n "$(ls "$d" 2>/dev/null)" ] && { dir=$d; break; }
done
if [ -z "$dir" ]; then
  echo "Cannot determine: no package manager flag and no kernel modules directory (container?)"
  exit 3
fi
if [ ! -d "$dir/$run" ]; then
  echo "WARNING: reboot required, running kernel $run is no longer installed"
  exit 2
fi
newest=$(for k in "$dir"/*; do [ -e "$k" ] && echo "${k##*/}"; done | sort -V | tail -n 1)
if [ "$newest" != "$run" ]; then
  echo "WARNING: reboot required, running kernel $run, newest installed $newest"
  exit 2
fi
echo "OK: running the newest installed kernel $run"
