#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports the running kernel, the installed kernels and the newest one.
# Variables: none
# Exit: 0 report printed, 3 no kernel information on this system (container without module directory)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

run=$(uname -r)
echo "Running: $run"
dir=''
for d in /usr/lib/modules /lib/modules; do
  [ -d "$d" ] && [ -n "$(ls "$d" 2>/dev/null)" ] && { dir=$d; break; }
done
if [ -z "$dir" ]; then
  echo "Unsupported: no installed kernel found in /lib/modules (container?)"
  exit 3
fi
list=$(for k in "$dir"/*; do [ -e "$k" ] && echo "${k##*/}"; done | sort -V)
echo "Installed:"
printf '%s\n' "$list" | sed 's/^/  /'
newest=$(printf '%s\n' "$list" | tail -n 1)
echo "Newest installed: $newest"
if command -v dpkg >/dev/null 2>&1; then
  p=$(dpkg-query -W -f '${Package} ${Version}\n' 'linux-image-[0-9]*' 2>/dev/null)
elif command -v rpm >/dev/null 2>&1; then
  p=$(rpm -q kernel kernel-default kernel-core 2>/dev/null | grep -v 'not installed')
elif command -v pacman >/dev/null 2>&1; then
  p=$(pacman -Q 2>/dev/null | grep -E '^linux(-lts|-zen|-hardened)? ')
elif command -v apk >/dev/null 2>&1; then
  p=$(apk info -v 2>/dev/null | grep -E '^linux-(lts|virt|edge)-[0-9]')
else
  p=''
fi
[ -n "$p" ] && { echo "Packages:"; printf '%s\n' "$p" | sed 's/^/  /'; }
if [ "$newest" = "$run" ]; then echo "Reboot needed: no"; else echo "Reboot needed: yes (running $run, newest $newest)"; fi
