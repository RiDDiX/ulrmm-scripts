#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Sets the password of a local user (read from the environment, passed to chpasswd on stdin).
# Variables: TARGET_USER (required), PASSWORD (required, 8-128 characters).
# Exit codes: 0 password set, 1 failed, 3 bad input, unknown user or system account.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

u=${TARGET_USER:-}
pw=${PASSWORD:-}
[ -n "$u" ] || { echo "TARGET_USER is required"; exit 3; }
case $u in [!a-z_]* | *[!a-z0-9_-]*) echo "TARGET_USER has characters that are not allowed"; exit 3 ;; esac
[ ${#pw} -ge 8 ] && [ ${#pw} -le 128 ] || { echo "PASSWORD must be 8-128 characters"; exit 3; }
case $pw in *"
"*) echo "PASSWORD must not contain a line break"; exit 3 ;; esac
ent=$(getent passwd "$u") || { echo "User $u does not exist"; exit 3; }
uid=$(echo "$ent" | cut -d: -f3)
umin=$(awk '$1=="UID_MIN" {print $2}' /etc/login.defs 2>/dev/null)
case $umin in '' | *[!0-9]*) umin=1000 ;; esac
if [ "$uid" -ne 0 ] && { [ "$uid" -lt "$umin" ] || [ "$uid" -ge 65534 ]; }; then
  echo "Refusing to set a password for $u: uid $uid is a system account"
  exit 3
fi
command -v chpasswd >/dev/null 2>&1 || { echo "chpasswd not found"; exit 3; }
before=$(awk -F: -v u="$u" '$1==u {print $2}' /etc/shadow)
printf '%s:%s\n' "$u" "$pw" | chpasswd >/dev/null 2>&1 || { echo "chpasswd failed"; exit 1; }
after=$(awk -F: -v u="$u" '$1==u {print $2}' /etc/shadow)
case $after in '' | '!'* | '*'*) echo "Password for $u is still not usable after the change"; exit 1 ;; esac
[ "$after" != "$before" ] || { echo "Password hash unchanged"; exit 1; }
echo "Password for $u set"
exit 0
