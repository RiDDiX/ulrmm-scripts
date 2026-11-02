#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Removes packages nothing depends on any more (apt, dnf, yum, zypper, pacman); never the running kernel.
# Variables: DRY_RUN (default true, only lists what would go).
# Exit codes: 0 done or nothing to do, 1 removal failed, 3 bad input or unsupported system.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

dry=${DRY_RUN:-true}
case $dry in true) ;; false) dry= ;; *) echo "DRY_RUN must be true or false"; exit 3 ;; esac
for c in apt-get dnf yum zypper pacman apk; do
  command -v "$c" >/dev/null 2>&1 && pm=$c && break
done
[ -n "${pm:-}" ] || { echo "No supported package manager found"; exit 3; }
kern=$(uname -r)
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT

case $pm in
apt-get)
  export DEBIAN_FRONTEND=noninteractive
  apt-get -s autoremove 2>/dev/null | sed -n 's/^Remv \([^ ]*\).*/\1/p' >"$tmp"
  if grep -qx "linux-image-$kern" "$tmp"; then
    echo "Refusing: the running kernel linux-image-$kern is on the removal list"
    exit 1
  fi
  n=$(wc -l <"$tmp")
  if [ -n "$dry" ] || [ "$n" -eq 0 ]; then
    echo "$n package(s) can be removed${dry:+ (dry run)}"
    cat "$tmp"
    exit 0
  fi
  apt-get -y -o DPkg::Lock::Timeout=300 autoremove >/dev/null 2>&1 || { echo "apt-get autoremove failed"; exit 1; }
  ;;
dnf | yum)
  $pm autoremove --assumeno 2>&1 | awk '/^[ ]*Removing( dependent packages)?:[ ]*$/ {f=1; next} /^[ ]*$/ {f=0} f && NF>=4 {print $1}' | sort -u >"$tmp"
  n=$(wc -l <"$tmp")
  if [ -n "$dry" ] || [ "$n" -eq 0 ]; then
    echo "$n package(s) can be removed${dry:+ (dry run)}"
    cat "$tmp"
    exit 0
  fi
  $pm -y autoremove >/dev/null 2>&1 || { echo "$pm autoremove failed"; exit 1; }
  ;;
zypper)
  zypper -n packages --unneeded 2>/dev/null | awk -F'|' '$1 ~ /i/ {gsub(/ /,"",$3); print $3}' |
    grep -E '^[A-Za-z0-9][A-Za-z0-9+._-]*$' | grep -v '^kernel' >"$tmp"
  n=$(wc -l <"$tmp")
  if [ -n "$dry" ] || [ "$n" -eq 0 ]; then
    echo "$n unneeded package(s)${dry:+ (dry run)}"
    cat "$tmp"
    exit 0
  fi
  # shellcheck disable=SC2046
  zypper -n remove --no-clean-deps $(cat "$tmp") >/dev/null 2>&1 || { echo "zypper remove failed"; exit 1; }
  ;;
pacman)
  pacman -Qdtq 2>/dev/null | grep -E '^[A-Za-z0-9@._+-]+$' >"$tmp"
  owner=$(pacman -Qqo "/usr/lib/modules/$kern/vmlinuz" 2>/dev/null)
  [ -n "$owner" ] && grep -vx "$owner" "$tmp" >"$tmp.2" && mv "$tmp.2" "$tmp"
  n=$(wc -l <"$tmp")
  if [ -n "$dry" ] || [ "$n" -eq 0 ]; then
    echo "$n orphan package(s)${dry:+ (dry run)}"
    cat "$tmp"
    exit 0
  fi
  # no -s: it would also take dependencies the dry run did not list
  # shellcheck disable=SC2046
  pacman -Rn --noconfirm $(cat "$tmp") >/dev/null 2>&1 || { echo "pacman remove failed"; exit 1; }
  ;;
apk)
  echo "apk has no unused-package concept, nothing to do"
  exit 0
  ;;
esac
echo "Unused packages removed with $pm"
exit 0
