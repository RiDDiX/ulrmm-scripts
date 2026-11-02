#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Tail the agent log (/var/log/ulrmm-agent.log). LINES (100): 1-2000.
# Exit: 0 printed, 1 log missing, 3 bad input, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

lines=${LINES:-100}
log=/var/log/ulrmm-agent.log

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }
case "$lines" in '' | *[!0-9]*) echo "LINES must be a whole number."; exit 3 ;; esac
[ "$lines" -ge 1 ] && [ "$lines" -le 2000 ] || { echo "LINES must be 1-2000."; exit 3; }

[ -f "$log" ] || { echo "$log does not exist."; exit 1; }
echo "$log, last $lines lines ($(stat -f%z "$log") bytes)"
tail -n "$lines" "$log" | cut -c1-2000
exit 0
