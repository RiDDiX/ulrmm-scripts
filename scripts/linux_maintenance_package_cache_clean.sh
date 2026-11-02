#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Cleans the package manager cache (apt, dnf, yum, zypper, pacman, apk) and reports the space freed.
# Variables: none. Exit codes: 0 done, 1 cleaning failed, 3 no supported package manager.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

size_kb() {
  t=0
  for d in /var/cache/apt /var/cache/dnf /var/cache/yum /var/cache/zypp /var/cache/pacman/pkg /var/cache/apk; do
    [ -d "$d" ] || continue
    k=$(du -sk "$d" 2>/dev/null | cut -f1)
    t=$((t + ${k:-0}))
  done
  echo "$t"
}

for c in apt-get dnf yum zypper pacman apk; do
  command -v "$c" >/dev/null 2>&1 && pm=$c && break
done
[ -n "${pm:-}" ] || { echo "No supported package manager found"; exit 3; }

before=$(size_kb)
case $pm in
apt-get) apt-get clean >/dev/null 2>&1 ;;
dnf) dnf -y clean all >/dev/null 2>&1 ;;
yum) yum -y clean all >/dev/null 2>&1 ;;
zypper) zypper -n clean --all >/dev/null 2>&1 ;;
pacman) yes | pacman -Scc >/dev/null 2>&1; [ -d /var/cache/pacman/pkg ] && find /var/cache/pacman/pkg -maxdepth 1 -type f -exec rm -f -- {} + ;;
apk) apk cache clean >/dev/null 2>&1; [ -d /var/cache/apk ] && find /var/cache/apk -maxdepth 1 -type f -exec rm -f -- {} + ;;
esac
rc=$?
after=$(size_kb)
if [ "$rc" -ne 0 ]; then
  echo "Cache clean failed with $pm (exit $rc)"
  exit 1
fi
echo "Package cache cleaned with $pm: $((before / 1024)) MB before, $((after / 1024)) MB after"
exit 0
