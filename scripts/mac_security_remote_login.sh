#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Remote Login (SSH). STATE: status (default), on, off.
# Exit: 0 ok, 1 state not reached, 3 bad input, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

state=${STATE:-status}
label=com.openssh.sshd
plist=/System/Library/LaunchDaemons/ssh.plist

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }
case "$state" in status | on | off) ;; *) echo "STATE must be status, on or off."; exit 3 ;; esac

# prints on or off: on means sshd is loaded in launchd and accepts connections
current() {
  if launchctl print "system/$label" >/dev/null 2>&1; then echo on; else echo off; fi
}

before=$(current)
if [ "$state" = status ]; then
  echo "Remote Login: $before"
  exit 0
fi
if [ "$before" = "$state" ]; then
  echo "Remote Login was already $state."
  # a launchd override that disagrees would flip it at the next restart
  ov=$(launchctl print-disabled system 2>/dev/null | sed -n "s/.*\"$label\" => //p")
  if [ "$state" = on ] && [ "$ov" = disabled ]; then
    launchctl enable "system/$label" && echo "Also enabled it in launchd so it stays on after a restart."
  elif [ "$state" = off ] && [ "$ov" = enabled ]; then
    launchctl disable "system/$label" && echo "Also disabled it in launchd so it stays off after a restart."
  fi
  exit 0
fi

out=$(systemsetup -f -setremotelogin "$state" 2>&1)
case "$(current)" in
"$state") ;;
*)
  echo "systemsetup did not apply it (Full Disk Access is probably missing); using launchctl."
  if [ "$state" = on ]; then
    launchctl enable "system/$label" >/dev/null 2>&1
    launchctl bootstrap system "$plist" >/dev/null 2>&1
  else
    launchctl bootout "system/$label" >/dev/null 2>&1
    launchctl disable "system/$label" >/dev/null 2>&1
  fi
  ;;
esac

after=$(current)
if [ "$after" = "$state" ]; then
  echo "Remote Login set to $state (was $before)."
  exit 0
fi
echo "Remote Login is $after, wanted $state. A managed profile may control it."
echo "$out" | head -n 3
exit 1
