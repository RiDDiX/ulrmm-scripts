#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows the time zone, or sets it.
# Variables: TIMEZONE (optional, e.g. Europe/Berlin, empty = only report).
# Exit codes: 0 done, 1 failed, 3 bad input or tzdata missing.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

tz=${TIMEZONE:-}
cur() {
  if [ -d /run/systemd/system ] && command -v timedatectl >/dev/null 2>&1; then
    timedatectl show -p Timezone --value 2>/dev/null && return
  fi
  l=$(readlink /etc/localtime 2>/dev/null)
  case $l in *zoneinfo/*) echo "${l#*zoneinfo/}" ;; *) cat /etc/timezone 2>/dev/null || echo UTC ;; esac
}
if [ -z "$tz" ]; then
  echo "Time zone: $(cur), local time $(date '+%Y-%m-%d %H:%M %Z')"
  exit 0
fi
case $tz in -* | /* | *..* | *[!A-Za-z0-9_+/-]*) echo "TIMEZONE has characters that are not allowed"; exit 3 ;; esac
[ ${#tz} -le 64 ] || { echo "TIMEZONE is too long"; exit 3; }
[ -f "/usr/share/zoneinfo/$tz" ] || { echo "Time zone $tz not found in /usr/share/zoneinfo (install tzdata if the directory is missing)"; exit 3; }
if [ "$(cur)" = "$tz" ]; then
  echo "Time zone already $tz"
  exit 0
fi
old=$(cur)
if [ -d /run/systemd/system ] && command -v timedatectl >/dev/null 2>&1; then
  timedatectl set-timezone "$tz" >/dev/null 2>&1 || { echo "timedatectl failed"; exit 1; }
else
  ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime || exit 1
  [ -d /etc ] && printf '%s\n' "$tz" >/etc/timezone
fi
[ "$(cur)" = "$tz" ] || { echo "Time zone is $(cur) after the change"; exit 1; }
echo "Time zone changed from $old to $tz"
exit 0
