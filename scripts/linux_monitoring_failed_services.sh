#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists failed systemd units or crashed OpenRC services.
# Variables: IGNORE (service names to skip, comma or line separated, optional)
# Exit: 0 none failed, 1 at least one failed, 3 bad input or no supported service manager
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

IGN=$(printf '%s\n' "${IGNORE:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d')
case $(printf %s "$IGN" | tr -d "\n") in *[!A-Za-z0-9@._:\\-]* | -*) echo "IGNORE has characters that are not allowed in a service name"; exit 3 ;; esac

if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
  mgr=systemd
  all=$(systemctl --failed --no-legend --plain --no-pager 2>/dev/null | awk '{print $1}')
elif command -v rc-status >/dev/null 2>&1 && [ -d /run/openrc ]; then
  mgr=OpenRC
  all=$(rc-status --crashed 2>/dev/null | awk 'NF && $1 !~ /:$/ {print $1}')
else
  echo "Unsupported: neither a running systemd nor OpenRC found"
  exit 3
fi

fail=''
nl='
'
for u in $all; do
  s=${u%.service}
  if [ -n "$IGN" ] && { printf '%s\n' "$IGN" | grep -qxF -- "$u" || printf '%s\n' "$IGN" | grep -qxF -- "$s"; }; then continue; fi
  fail="$fail$u$nl"
done
if [ -z "$fail" ]; then
  echo "OK: no failed services ($mgr)"
  exit 0
fi
echo "ERROR: $(printf '%s' "$fail" | wc -l) failed services ($mgr)"
printf '%s' "$fail"
exit 1
