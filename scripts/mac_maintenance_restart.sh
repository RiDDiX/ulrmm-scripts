#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Restart or shut down. MODE: restart (default), shutdown, cancel. DELAY_MINUTES (1): 0-1440. MESSAGE: shown to the console user.
# Exit: 0 scheduled or cancelled, 1 shutdown could not be scheduled, 3 bad input, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

mode=${MODE:-restart}
delay=${DELAY_MINUTES:-1}
msg=${MESSAGE:-}

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }
case "$mode" in restart | shutdown | cancel) ;; *) echo "MODE must be restart, shutdown or cancel."; exit 3 ;; esac
case "$delay" in '' | *[!0-9]*) echo "DELAY_MINUTES must be a whole number."; exit 3 ;; esac
[ "$delay" -le 1440 ] || { echo "DELAY_MINUTES must be 0-1440."; exit 3; }
[ ${#msg} -le 200 ] || { echo "MESSAGE is longer than 200 characters."; exit 3; }
case "$msg" in *[[:cntrl:]]*) echo "MESSAGE must not contain control characters or line breaks."; exit 3 ;; esac

if [ "$mode" = cancel ]; then
  if pgrep -x shutdown >/dev/null 2>&1; then
    pkill -x shutdown
    echo "Pending shutdown cancelled."
  else
    echo "No shutdown was pending."
  fi
  exit 0
fi

# a pending one is replaced
if pgrep -x shutdown >/dev/null 2>&1; then
  pkill -x shutdown
  echo "Replaced a pending shutdown."
fi

if [ "$mode" = restart ]; then
  flag=-r
  what=restart
else
  flag=-h
  what="shut down"
fi
[ -n "$msg" ] || msg="This computer will $what in $delay minute(s)."

when="+$delay"
[ "$delay" -eq 0 ] && when=now
if ! shutdown "$flag" "$when" "$msg" >/dev/null 2>&1; then
  echo "shutdown refused to schedule the $what."
  exit 1
fi
echo "Scheduled: $what $( [ "$delay" -eq 0 ] && echo now || echo "in $delay minute(s)" )."

# notify whoever sits at the screen; the dialog gives up by itself and never blocks this script
user=$(stat -f%Su /dev/console 2>/dev/null)
case "$user" in '' | root | loginwindow | _mbsetupuser) echo "No console user to notify." ;;
*)
  uid=$(id -u "$user" 2>/dev/null)
  if [ -n "$uid" ]; then
    launchctl asuser "$uid" sudo -u "$user" osascript \
      -e 'on run argv' \
      -e 'display dialog (item 1 of argv) with title "Notice" buttons {"OK"} default button 1 giving up after 120' \
      -e 'end run' -- "$msg" >/dev/null 2>&1 &
    echo "Message sent to $user."
  fi
  ;;
esac
exit 0
