#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Time zone. TIMEZONE: IANA name such as Europe/Berlin, empty reports the current one.
# Exit: 0 reported or set, 1 change failed, 3 bad input, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

ok() { case "$1" in *$'\n'*) return 1 ;; esac; printf '%s' "$1" | LC_ALL=C grep -Eq "$2"; }

tz=${TIMEZONE:-}
zones=/var/db/timezone/zoneinfo

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }

current=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
auto=$(defaults read /Library/Preferences/com.apple.timezone.auto Active 2>/dev/null)

if [ -z "$tz" ]; then
  echo "Time zone: ${current:-unknown}"
  echo "Set automatically by location: $([ "$auto" = 1 ] && echo yes || echo no)"
  exit 0
fi

ok "$tz" '^[A-Za-z][A-Za-z0-9_+/-]{1,59}$' || { echo "TIMEZONE has characters outside A-Z a-z 0-9 _ + - /"; exit 3; }
[ -f "$zones/$tz" ] || { echo "Unknown time zone $tz (examples: Europe/Berlin, America/New_York, UTC)."; exit 3; }

if [ "$current" = "$tz" ]; then
  echo "Time zone already $tz."
  exit 0
fi

if ! systemsetup -settimezone "$tz" >/dev/null 2>&1 || [ "$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')" != "$tz" ]; then
  # systemsetup needs Full Disk Access; this is the same link it writes
  ln -sfn "$zones/$tz" /etc/localtime
fi
now=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')
if [ "$now" != "$tz" ]; then
  echo "Time zone is $now, wanted $tz."
  exit 1
fi
echo "Time zone set to $tz (was ${current:-unknown})."
[ "$auto" = 1 ] && echo "Warning: automatic time zone by location is on and can change it again."
exit 0
