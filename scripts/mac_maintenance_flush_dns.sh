#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Flush the DNS cache. No variables.
# Exit: 0 flushed, 1 failed, 3 not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }

rc=0
dscacheutil -flushcache || rc=1
killall -HUP mDNSResponder || rc=1
if [ $rc -eq 0 ]; then echo "DNS cache flushed."; else echo "Flushing the DNS cache failed."; fi
exit $rc
