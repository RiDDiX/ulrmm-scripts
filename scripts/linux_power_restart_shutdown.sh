#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Schedules a restart or shutdown, or cancels a scheduled one.
# Variables: MODE (restart, shutdown, cancel; default restart), DELAY_MINUTES (default 1, 1-1440), MESSAGE (optional notice for logged-in users).
# Exit codes: 0 scheduled or cancelled, 1 failed, 3 bad input or no shutdown command.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

mode=${MODE:-restart}
delay=${DELAY_MINUTES:-1}
msg=${MESSAGE:-}
case $mode in restart | shutdown | cancel) ;; *) echo "MODE must be restart, shutdown or cancel"; exit 3 ;; esac
case $delay in '' | *[!0-9]*) echo "DELAY_MINUTES must be a whole number"; exit 3 ;; esac
[ ${#delay} -le 4 ] && [ "$delay" -ge 1 ] && [ "$delay" -le 1440 ] || { echo "DELAY_MINUTES must be 1-1440"; exit 3; }
# a leading dash would be parsed as an option (-k only warns, -c cancels)
msg=$(printf '%s' "$msg" | tr -d '\000-\037\177' | sed 's/^[-[:space:]]*//' | cut -c1-200)
command -v shutdown >/dev/null 2>&1 || { echo "shutdown command not found"; exit 3; }
if [ -f /.dockerenv ] && [ ! -d /run/systemd/system ]; then
  echo "Container without init, nothing to restart"
  exit 3
fi

if [ "$mode" = cancel ]; then
  if shutdown -c >/dev/null 2>&1; then
    echo "Scheduled shutdown cancelled (or none was pending)"
    exit 0
  fi
  echo "Could not cancel"
  exit 1
fi
[ "$mode" = restart ] && flag=-r || flag=-h
if [ -n "$msg" ]; then
  shutdown "$flag" "+$delay" "$msg" >/dev/null 2>&1 || { echo "shutdown failed"; exit 1; }
else
  shutdown "$flag" "+$delay" >/dev/null 2>&1 || { echo "shutdown failed"; exit 1; }
fi
echo "$mode scheduled in $delay minute(s)"
exit 0
