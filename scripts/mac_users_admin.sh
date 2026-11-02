#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Grant or revoke administrator rights. TARGET_USER, STATE: grant or revoke.
# Refuses to revoke the last enabled local administrator.
# Exit: 0 done or already in place, 1 change failed, 3 bad input, refused, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

ok() { case "$1" in *$'\n'*) return 1 ;; esac; printf '%s' "$1" | LC_ALL=C grep -Eq "$2"; }

user=${TARGET_USER:-}
state=${STATE:-}

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }
ok "$user" '^[A-Za-z0-9][A-Za-z0-9_.-]{0,30}$' || { echo "TARGET_USER is empty or has characters outside A-Z a-z 0-9 _ . -"; exit 3; }
case "$state" in grant | revoke) ;; *) echo "STATE must be grant or revoke."; exit 3 ;; esac

uid=$(dscl . -read "/Users/$user" UniqueID 2>/dev/null | awk '{print $2}')
case "$uid" in '' | *[!0-9]*) echo "No local user $user."; exit 3 ;; esac
[ "$uid" -ge 500 ] || { echo "$user is a system account, refusing."; exit 3; }

is_admin() { dseditgroup -o checkmember -m "$1" admin >/dev/null 2>&1; }

if [ "$state" = grant ]; then
  if is_admin "$user"; then echo "$user is already an administrator."; exit 0; fi
  dseditgroup -o edit -a "$user" -t user admin || { echo "Granting failed."; exit 1; }
  is_admin "$user" && { echo "$user is now an administrator."; exit 0; }
  echo "Granting did not take effect."
  exit 1
fi

if ! is_admin "$user"; then echo "$user is not an administrator."; exit 0; fi
others=0
for m in $(dscl . -read /Groups/admin GroupMembership 2>/dev/null | sed 's/^GroupMembership://'); do
  [ "$m" = "$user" ] && continue
  mu=$(dscl . -read "/Users/$m" UniqueID 2>/dev/null | awk '{print $2}')
  case "$mu" in '' | *[!0-9]*) continue ;; esac
  [ "$mu" -ge 500 ] || continue
  dscl . -read "/Users/$m" AuthenticationAuthority 2>/dev/null | grep -q ';DisabledUser;' && continue
  others=$((others + 1))
done
if [ "$others" -eq 0 ]; then
  echo "$user is the last enabled local administrator, not revoking."
  exit 3
fi
dseditgroup -o edit -d "$user" -t user admin || { echo "Revoking failed."; exit 1; }
is_admin "$user" && { echo "Revoking did not take effect."; exit 1; }
echo "$user is no longer an administrator."
exit 0
