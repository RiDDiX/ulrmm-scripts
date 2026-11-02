#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Application firewall. STATE: status (default), on, off. STEALTH (false): with STATE=on also turn stealth mode on.
# Exit: 0 ok or reached, 1 firewall off in status mode or change not applied, 3 bad input, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

state=${STATE:-status}
stealth=${STEALTH:-false}
fw=/usr/libexec/ApplicationFirewall/socketfilterfw

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }
case "$state" in status | on | off) ;; *) echo "STATE must be status, on or off."; exit 3 ;; esac
case "$stealth" in true | false) ;; *) echo "STEALTH must be true or false."; exit 3 ;; esac
[ -x "$fw" ] || { echo "$fw not found."; exit 3; }

fw_on() { "$fw" --getglobalstate 2>&1 | grep -qi "enabled"; }
stealth_on() { "$fw" --getstealthmode 2>&1 | grep -Eqi "mode (is )?(on|enabled)"; }

rc=0
case "$state" in
on)
  if fw_on; then echo "Firewall was already on."; else "$fw" --setglobalstate on >/dev/null 2>&1; fi
  if [ "$stealth" = true ]; then
    if stealth_on; then echo "Stealth mode was already on."; else "$fw" --setstealthmode on >/dev/null 2>&1; fi
  fi
  fw_on || { echo "Firewall is still off (a managed profile may enforce it)."; rc=1; }
  if [ "$stealth" = true ] && ! stealth_on; then echo "Stealth mode is still off."; rc=1; fi
  ;;
off)
  if fw_on; then "$fw" --setglobalstate off >/dev/null 2>&1; else echo "Firewall was already off."; fi
  if fw_on; then echo "Firewall is still on (a managed profile may enforce it)."; rc=1; fi
  ;;
esac

if fw_on; then echo "Firewall: on"; else echo "Firewall: off"; [ "$state" = status ] && rc=1; fi
if stealth_on; then echo "Stealth mode: on"; else echo "Stealth mode: off"; fi
"$fw" --getblockall 2>&1 | head -n 1
exit $rc
