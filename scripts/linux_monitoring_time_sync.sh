#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks that the clock is synchronised (chrony, ntpd/ntpq, systemd-timesyncd or busybox ntpd).
# Variables: none
# Exit: 0 synchronised, 1 not synchronised, 3 no time sync tool found
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

if command -v chronyc >/dev/null 2>&1 && t=$(chronyc tracking 2>/dev/null) && [ -n "$t" ]; then
  ref=$(printf '%s\n' "$t" | sed -n 's/^Reference ID *: *\([0-9A-Fa-f]*\).*/\1/p')
  off=$(printf '%s\n' "$t" | sed -n 's/^System time *: *\(.*\)/\1/p')
  case $ref in 0 | 00000000 | '') echo "ERROR: chrony has no time source ($off)"; exit 1 ;; esac
  case $(printf '%s\n' "$t" | sed -n 's/^Leap status *: *//p') in 'Not synchronised') echo "ERROR: chrony not synchronised"; exit 1 ;; esac
  echo "OK: chrony synchronised, offset $off"
  exit 0
fi
if command -v ntpq >/dev/null 2>&1 && p=$(ntpq -pn 2>/dev/null) && [ -n "$p" ]; then
  peer=$(printf '%s\n' "$p" | sed -n 's/^\*\([^ ]*\).*/\1/p' | head -n 1)
  [ -n "$peer" ] && { echo "OK: ntpd synchronised to $peer"; exit 0; }
  echo "ERROR: ntpd running but has no selected peer"
  exit 1
fi
if command -v timedatectl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  s=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)
  [ -n "$s" ] || s=$(timedatectl 2>/dev/null | sed -n 's/^ *System clock synchronized: *//p;s/^ *NTP synchronized: *//p' | head -n 1)
  case $s in
  yes) echo "OK: clock synchronised (systemd)"; exit 0 ;;
  no) echo "ERROR: clock not synchronised (systemd; is systemd-timesyncd or chrony enabled?)"; exit 1 ;;
  esac
fi
for d in /proc/[0-9]*; do
  [ "$(cat "$d/comm" 2>/dev/null)" = ntpd ] && { echo "OK: busybox ntpd is running (it cannot report its sync state)"; exit 0; }
done
echo "Unsupported: no chronyc, ntpq, timedatectl or running ntpd (install chrony)"
exit 3
