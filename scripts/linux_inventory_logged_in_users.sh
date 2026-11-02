#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists logged-in users and the most recent logins.
# Variables: none
# Exit: 0 report printed, 3 no tool to read login records
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

have() { command -v "$1" >/dev/null 2>&1; }
have who || { echo "Unsupported: who is not installed (coreutils or busybox)"; exit 3; }
echo "Logged in now:"
w=$(who 2>/dev/null)
if [ -n "$w" ]; then printf '%s\n' "$w" | sed 's/^/  /'; else echo "  nobody"; fi
if have loginctl && [ -d /run/systemd/system ]; then
  echo "systemd sessions:"
  loginctl list-sessions --no-legend --no-pager 2>/dev/null | sed 's/^/  /'
fi
if have last; then
  echo "Recent logins:"
  last -n 10 2>/dev/null | grep -v '^$' | sed 's/^/  /'
else
  echo "Recent logins: unavailable (last not installed)"
fi
