#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Time Machine check. MAX_HOURS (48): oldest accepted age of the latest backup.
# Exit: 0 ok, 1 not configured, no backup or too old, 3 bad input, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

max=${MAX_HOURS:-48}
prefs=/Library/Preferences/com.apple.TimeMachine

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }
case "$max" in '' | *[!0-9]*) echo "MAX_HOURS must be a whole number."; exit 3 ;; esac
[ "$max" -ge 1 ] && [ "$max" -le 8760 ] || { echo "MAX_HOURS must be 1-8760."; exit 3; }

# The preferences list the backup dates (SnapshotDates, UTC; not AttemptDates) without Full Disk Access.
epoch=""
snap=$(defaults read "$prefs" 2>/dev/null | awk '/SnapshotDates = / { f = !/\)/; next } f && /\)/ { f = 0 } f' | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} \+0000' | sort | tail -n 1)
if [ -n "$snap" ]; then
  epoch=$(date -j -u -f '%Y-%m-%d %H:%M:%S +0000' "$snap" +%s 2>/dev/null)
fi

dest=$(tmutil destinationinfo 2>&1)
case "$dest" in
*"Full Disk Access"*)
  if [ -z "$epoch" ]; then
    echo "tmutil needs Full Disk Access for the agent and no snapshot dates are readable."
    echo "Grant it in System Settings > Privacy & Security, or deploy a PPPC profile."
    exit 3
  fi
  dest=""
  ;;
*"No destinations"*)
  echo "FAILING: Time Machine has no backup destination."
  exit 1
  ;;
esac

if [ -z "$epoch" ]; then
  last=$(tmutil latestbackup 2>&1)
  ts=$(echo "$last" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' | tail -n 1)
  case "$last" in *"Full Disk Access"*) echo "tmutil needs Full Disk Access."; exit 3 ;; esac
  [ -n "$ts" ] && epoch=$(date -j -f '%Y-%m-%d-%H%M%S' "$ts" +%s 2>/dev/null)
fi

if [ -z "$epoch" ]; then
  echo "FAILING: no completed backup found (the destination may be offline)."
  [ -n "$dest" ] && echo "$dest" | grep -E '^(Name|Kind|URL|Mount Point)' | head -n 4
  exit 1
fi

age=$(($(date +%s) - epoch))
hours=$((age / 3600))
when=$(date -r "$epoch" '+%Y-%m-%d %H:%M')
if [ "$hours" -ge "$max" ]; then
  echo "FAILING: last backup $when, $hours h ago, limit is $max h"
  exit 1
fi
echo "OK: last backup $when, $hours h ago, limit is $max h"
exit 0
