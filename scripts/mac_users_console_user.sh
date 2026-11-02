#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Console user collector. No variables. The last line is the short name or "none".
# Exit: 0 always, 3 not macOS.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

[ "$(uname -s)" = Darwin ] || { echo "Not macOS."; exit 3; }

user=$(stat -f%Su /dev/console 2>/dev/null)
case "$user" in '' | root | loginwindow | _mbsetupuser) user=none ;; esac
echo "$user"
exit 0
