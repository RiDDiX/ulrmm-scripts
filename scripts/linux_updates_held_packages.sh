#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists packages that are held back from updates (apt-mark hold, dnf versionlock, zypper locks, pacman IgnorePkg, apk pins).
# Variables: none. Exit codes: 0 report printed, 3 no supported package manager.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

if command -v apt-mark >/dev/null 2>&1; then
  out=$(apt-mark showhold 2>/dev/null)
  mgr=apt
elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
  mgr=dnf
  pm=$(command -v dnf || command -v yum)
  out=$("$pm" versionlock list 2>&1)
  case $out in *"nknown command"* | *"No such command"* | *"nrecognized"*)
    echo "Version lock plugin not installed, no locks can exist"
    exit 0
    ;;
  esac
  out=$(printf '%s\n' "$out" | grep -v -e '^Last metadata' -e '^$')
  case $out in *"Error"* | *"error"*) out= ;; esac
  ex=$(grep -hE '^[[:space:]]*exclude[[:space:]]*=' /etc/dnf/dnf.conf /etc/yum.conf 2>/dev/null)
  [ -n "$ex" ] && out="$out
$ex"
elif command -v zypper >/dev/null 2>&1; then
  mgr=zypper
  out=$(zypper -n locks 2>&1 | grep -E '^[0-9]+ ' )
elif command -v pacman >/dev/null 2>&1; then
  mgr=pacman
  out=$(grep -E '^[[:space:]]*(IgnorePkg|IgnoreGroup)[[:space:]]*=' /etc/pacman.conf 2>/dev/null)
elif command -v apk >/dev/null 2>&1; then
  mgr=apk
  out=$(grep -E '[<>=~]' /etc/apk/world 2>/dev/null)
else
  echo "No supported package manager found"
  exit 3
fi
out=$(printf '%s\n' "$out" | sed '/^$/d')
if [ -z "$out" ]; then
  echo "No held packages ($mgr)"
else
  echo "$(printf '%s\n' "$out" | wc -l) held entry/entries ($mgr)"
  printf '%s\n' "$out"
fi
exit 0
