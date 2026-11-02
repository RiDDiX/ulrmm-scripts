#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Computer name. NAME: new name, empty reports the current names. Sets ComputerName as given and
# LocalHostName and HostName in a hostname-safe form (letters, digits, hyphen, up to 63).
# Exit: 0 reported or set, 1 change failed, 3 bad input, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

ok() { case "$1" in *$'\n'*) return 1 ;; esac; printf '%s' "$1" | LC_ALL=C grep -Eq "$2"; }

name=${NAME:-}

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }

show() {
  echo "ComputerName: $(scutil --get ComputerName 2>/dev/null)"
  echo "LocalHostName: $(scutil --get LocalHostName 2>/dev/null)"
  echo "HostName: $(scutil --get HostName 2>/dev/null)"
}

if [ -z "$name" ]; then
  show
  exit 0
fi

ok "$name" "^[A-Za-z0-9 ._'-]{1,63}\$" || { echo "NAME must be 1-63 characters: letters, digits, space and . _ ' -"; exit 3; }
host=$(printf '%s' "$name" | tr -cs 'A-Za-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-63 | sed 's/-*$//')
[ -n "$host" ] || { echo "NAME has no letter or digit to build a host name from."; exit 3; }

rc=0
set_one() { # key value
  if [ "$(scutil --get "$1" 2>/dev/null)" = "$2" ]; then
    echo "$1 already $2"
  elif scutil --set "$1" "$2"; then
    echo "$1 set to $2"
  else
    echo "$1 could not be set"
    rc=1
  fi
}
set_one ComputerName "$name"
set_one LocalHostName "$host"
set_one HostName "$host"
dscacheutil -flushcache >/dev/null 2>&1
exit $rc
