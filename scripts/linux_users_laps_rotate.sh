#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Rotates the password of a local administrator account, creating it when missing (password goes to chpasswd on stdin).
# Variables: TARGET_USER (required), NEW_PASSWORD (required, 8-128 characters), CREATE_IF_MISSING (checkbox, default true).
# Exit codes: 0 password set, 1 failed, 3 bad input, locked account or system account.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }
[ "$(id -u)" -eq 0 ] || { echo "Needs root"; exit 3; }

u=${TARGET_USER:-}
pw=${NEW_PASSWORD:-}
create=${CREATE_IF_MISSING:-true}
[ -n "$u" ] || { echo "TARGET_USER is required"; exit 3; }
case $u in [!a-z]* | *[!a-z0-9_-]*) echo "TARGET_USER must match [a-z][a-z0-9_-]{0,19}"; exit 3 ;; esac
[ ${#u} -le 20 ] || { echo "TARGET_USER is longer than 20 characters"; exit 3; }
[ ${#pw} -ge 8 ] && [ ${#pw} -le 128 ] || { echo "NEW_PASSWORD must be 8-128 characters"; exit 3; }
case $pw in *"
"*) echo "NEW_PASSWORD must not contain a line break"; exit 3 ;; esac
case $create in true | false) ;; *) echo "CREATE_IF_MISSING must be true or false"; exit 3 ;; esac
command -v chpasswd >/dev/null 2>&1 || { echo "chpasswd not found"; exit 3; }

umin=$(awk '$1=="UID_MIN" {print $2}' /etc/login.defs 2>/dev/null)
case $umin in '' | *[!0-9]*) umin=1000 ;; esac

ent=$(getent passwd "$u") || ent=""
created=no
# a half-created account must not survive a failed run
undo() {
  [ "$created" = yes ] || return 0
  if command -v userdel >/dev/null 2>&1; then userdel -r "$u" >/dev/null 2>&1; else deluser --remove-home "$u" >/dev/null 2>&1; fi
}
if [ -z "$ent" ]; then
  [ "$create" = true ] || { echo "User $u does not exist"; exit 3; }
  grp=""
  for g in sudo wheel; do
    if getent group "$g" >/dev/null 2>&1; then grp=$g; break; fi
  done
  [ -n "$grp" ] || { echo "No sudo or wheel group to put $u in"; exit 3; }
  if command -v useradd >/dev/null 2>&1; then
    useradd -m -s /bin/sh -G "$grp" "$u" >/dev/null 2>&1 || { echo "useradd failed"; exit 1; }
    created=yes
  elif command -v adduser >/dev/null 2>&1; then
    if adduser -D -s /bin/sh "$u" >/dev/null 2>&1; then
      created=yes
      addgroup "$u" "$grp" >/dev/null 2>&1 || { undo; echo "addgroup failed"; exit 1; }
    else
      echo "adduser failed"
      exit 1
    fi
  else
    echo "Neither useradd nor adduser found"
    exit 3
  fi
  created=yes
  ent=$(getent passwd "$u") || { undo; echo "User $u missing after creation"; exit 1; }
fi

uid=$(echo "$ent" | cut -d: -f3)
if [ "$uid" -lt "$umin" ] || [ "$uid" -ge 65534 ]; then
  echo "Refusing to rotate $u: uid $uid is a system account"
  undo
  exit 3
fi
before=$(awk -F: -v u="$u" '$1==u {print $2}' /etc/shadow)
if [ "$created" = no ]; then
  case $before in '!'?* | '*'?*) echo "Refusing to rotate $u: the account is locked"; exit 3 ;; esac
fi

printf '%s:%s\n' "$u" "$pw" | chpasswd >/dev/null 2>&1 || { undo; echo "chpasswd failed"; exit 1; }
after=$(awk -F: -v u="$u" '$1==u {print $2}' /etc/shadow)
case $after in '' | '!'* | '*'*) echo "Password for $u is still not usable after the change"; undo; exit 1 ;; esac
[ "$after" != "$before" ] || { echo "Password hash unchanged"; undo; exit 1; }
echo "Password for $u rotated, created=$created"
exit 0
