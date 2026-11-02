#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Installs packages with the system package manager (apt, dnf, yum, zypper, pacman, apk) or reports whether they are installed.
# Variables: PACKAGES (required, names separated by spaces, commas or line breaks), ACTION (install, status; default install).
# Exit codes: 0 all installed, 1 install failed or a package is missing, 3 bad input or no package manager.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

set -f
act=${ACTION:-install}
list=$(printf '%s' "${PACKAGES:-}" | tr ',\r\n\t' '    ')
case $act in install | status) ;; *) echo "ACTION must be install or status"; exit 3 ;; esac
n=0
for p in $list; do
  case $p in -* | *[!A-Za-z0-9+._:@-]*) echo "Package name '$p' has characters that are not allowed"; exit 3 ;; esac
  [ ${#p} -le 100 ] || { echo "Package name too long"; exit 3; }
  n=$((n + 1))
done
[ "$n" -ge 1 ] && [ "$n" -le 50 ] || { echo "PACKAGES needs 1-50 package names"; exit 3; }
for c in apt-get dnf yum zypper pacman apk; do
  command -v "$c" >/dev/null 2>&1 && pm=$c && break
done
[ -n "${pm:-}" ] || { echo "No supported package manager found"; exit 3; }

have() {
  case $pm in
  apt-get) dpkg -s "$1" 2>/dev/null | grep -q '^Status: install ok installed' ;;
  dnf | yum | zypper) rpm -q "$1" >/dev/null 2>&1 || rpm -q --whatprovides "$1" >/dev/null 2>&1 ;;
  pacman) pacman -Qq "$1" >/dev/null 2>&1 ;;
  apk) apk info -e "$1" >/dev/null 2>&1 ;;
  esac
}
missing=
for p in $list; do have "$p" || missing="$missing $p"; done
if [ "$act" = status ]; then
  for p in $list; do if have "$p"; then echo "$p: installed"; else echo "$p: missing"; fi; done
  [ -z "$missing" ]
  exit $?
fi
if [ -z "$missing" ]; then
  echo "Already installed: $list"
  exit 0
fi
export DEBIAN_FRONTEND=noninteractive
# shellcheck disable=SC2086
case $pm in
apt-get)
  apt-get -o DPkg::Lock::Timeout=300 update >/dev/null 2>&1
  apt-get install -y -o DPkg::Lock::Timeout=300 -o Dpkg::Options::=--force-confold $missing >/dev/null 2>&1
  ;;
dnf | yum)
  $pm -y makecache >/dev/null 2>&1
  $pm -y install $missing >/dev/null 2>&1
  ;;
zypper)
  zypper -n refresh >/dev/null 2>&1
  zypper -n install --no-recommends $missing >/dev/null 2>&1
  ;;
pacman)
  # no -Sy here: refreshing the databases without a full upgrade is an unsupported partial upgrade
  pacman -S --needed --noconfirm $missing >/dev/null 2>&1 || echo "pacman failed; if the package databases are stale, run a full upgrade (pacman -Syu) first"
  ;;
apk)
  apk update >/dev/null 2>&1
  apk add $missing >/dev/null 2>&1
  ;;
esac
rc=$?
bad=
for p in $missing; do have "$p" || bad="$bad $p"; done
if [ -n "$bad" ]; then
  echo "Not installed after $pm (exit $rc):$bad"
  exit 1
fi
echo "Installed with $pm:$missing"
exit 0
