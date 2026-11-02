#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Deletes a local user. Refuses root, system accounts, logged-in users and the last admin.
# Variables: TARGET_USER (required), REMOVE_HOME (default false).
# Exit codes: 0 user gone, 1 failed, 3 bad input or a guard refused it.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

u=${TARGET_USER:-}
rm_home=${REMOVE_HOME:-false}
[ -n "$u" ] || { echo "TARGET_USER is required"; exit 3; }
case $u in [!a-z_]* | *[!a-z0-9_-]*) echo "TARGET_USER has characters that are not allowed"; exit 3 ;; esac
case $rm_home in true | false) ;; *) echo "REMOVE_HOME must be true or false"; exit 3 ;; esac
ent=$(getent passwd "$u") || { echo "User $u does not exist, nothing to do"; exit 0; }
uid=$(echo "$ent" | cut -d: -f3)
umin=$(awk '$1=="UID_MIN" {print $2}' /etc/login.defs 2>/dev/null)
umin=${umin:-1000}
[ "$uid" -ne 0 ] && [ "$u" != root ] || { echo "Refusing to delete root"; exit 3; }
[ "$uid" -ge "$umin" ] && [ "$uid" -lt 65534 ] || { echo "Refusing to delete $u: uid $uid is a system account"; exit 3; }
if who 2>/dev/null | awk '{print $1}' | grep -qx "$u" || pgrep -u "$uid" >/dev/null 2>&1; then
  echo "Refusing to delete $u: the user is logged in or has running processes"
  exit 3
fi
mine=0
others=0
for g in sudo wheel admin; do
  for m in $(getent group "$g" 2>/dev/null | cut -d: -f4 | tr ',' ' '); do
    if [ "$m" = "$u" ]; then mine=1; continue; fi
    case $(awk -F: -v u="$m" '$1==u {print $2}' /etc/shadow) in '!'* | '*'* | '') ;; *) others=$((others + 1)) ;; esac
  done
done
case $(awk -F: '$1=="root" {print $2}' /etc/shadow) in '' | '!'* | '*'*) ;; *) others=$((others + 1)) ;; esac
if [ "$mine" = 1 ] && [ "$others" -eq 0 ]; then
  echo "Refusing to delete $u: it is the last sudo/wheel member"
  exit 3
fi
home=$(echo "$ent" | cut -d: -f6)
if command -v userdel >/dev/null 2>&1; then
  if [ "$rm_home" = true ]; then userdel -r "$u" >/dev/null 2>&1; else userdel "$u" >/dev/null 2>&1; fi
elif command -v deluser >/dev/null 2>&1; then
  if [ "$rm_home" = true ]; then deluser --remove-home "$u" >/dev/null 2>&1; else deluser "$u" >/dev/null 2>&1; fi
else
  echo "Neither userdel nor deluser found"
  exit 3
fi
getent passwd "$u" >/dev/null 2>&1 && { echo "User $u still exists after deletion"; exit 1; }
for c in /var/spool/cron/crontabs/"$u" /var/spool/cron/"$u" /var/spool/cron/tabs/"$u"; do
  [ -f "$c" ] && echo "Note: crontab $c of $u still exists"
done
if [ "$rm_home" = true ]; then
  [ -d "$home" ] && echo "Deleted $u, home $home was kept (not removed by the tool)" || echo "Deleted $u and removed $home"
else
  echo "Deleted $u, home directory $home kept"
fi
exit 0
