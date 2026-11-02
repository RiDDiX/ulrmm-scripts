#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks that every listed service is running (systemd or OpenRC).
# Variables: SERVICES (service names, comma or line separated, required)
# Exit: 0 all running, 1 at least one not running, 3 bad input or no supported service manager
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

LIST=$(printf '%s\n' "${SERVICES:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d')
[ -n "$LIST" ] || { echo "SERVICES is required"; exit 3; }
case $(printf %s "$LIST" | tr -d "\n") in *[!A-Za-z0-9@._:\\-]* | -*) echo "SERVICES has characters that are not allowed in a service name"; exit 3 ;; esac
if printf '%s\n' "$LIST" | grep -q '^-'; then echo "A service name must not start with a dash"; exit 3; fi
printf '%s\n' "$LIST" | grep -q '[[:space:]]' && { echo "A service name must not contain spaces"; exit 3; }

if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
  mgr=systemd
elif command -v rc-service >/dev/null 2>&1 && [ -d /run/openrc ]; then
  mgr=OpenRC
else
  echo "Unsupported: neither a running systemd nor OpenRC found"
  exit 3
fi

nl='
'
down='' up=0 n=0
for s in $LIST; do
  n=$((n + 1))
  if [ $mgr = systemd ]; then
    case $s in *.*) u=$s ;; *) u=$s.service ;; esac
    st=$(systemctl is-active -- "$u" 2>/dev/null)
    [ "$st" = active ] && { up=$((up + 1)); continue; }
    down="$down$s: ${st:-unknown}$nl"
  else
    if rc-service -- "$s" status >/dev/null 2>&1; then up=$((up + 1)); else down="$down$s: not started$nl"; fi
  fi
done
if [ -z "$down" ]; then
  echo "OK: $up of $n services running ($mgr)"
  exit 0
fi
echo "ERROR: $((n - up)) of $n services not running ($mgr)"
printf '%s' "$down"
exit 1
