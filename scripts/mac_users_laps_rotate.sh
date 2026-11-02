#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Rotates the password of a local administrator account, creating it when missing. The password never appears in argv.
# Variables: TARGET_USER (required), NEW_PASSWORD (required, 8-128 characters), CREATE_IF_MISSING (checkbox, default true).
# Exit: 0 password set, 1 failed, 3 bad input, system account, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

ok() { case "$1" in *$'\n'*) return 1 ;; esac; printf '%s' "$1" | LC_ALL=C grep -Eq "$2"; }

user=${TARGET_USER:-}
pw=${NEW_PASSWORD:-}
create=${CREATE_IF_MISSING:-true}

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }
ok "$user" '^[a-z][a-z0-9_-]{0,19}$' || { echo "TARGET_USER must match [a-z][a-z0-9_-]{0,19}"; exit 3; }
[ ${#pw} -ge 8 ] && [ ${#pw} -le 128 ] || { echo "NEW_PASSWORD must be 8-128 characters"; exit 3; }
case "$pw" in *$'\n'*) echo "NEW_PASSWORD must not contain a line break"; exit 3 ;; esac
case "$create" in true | false) ;; *) echo "CREATE_IF_MISSING must be true or false"; exit 3 ;; esac

uid=$(dscl . -read "/Users/$user" UniqueID 2>/dev/null | awk '{print $2}')
created=no
if [ -z "$uid" ]; then
  [ "$create" = true ] || { echo "No local user $user."; exit 3; }
  # sysadminctl reads the new password from stdin with "-password -"
  printf '%s\n' "$pw" | sysadminctl -addUser "$user" -fullName "$user" -password - -admin >/dev/null 2>&1 \
    || { dscl . -read "/Users/$user" >/dev/null 2>&1 && dscl . -delete "/Users/$user" >/dev/null 2>&1; echo "sysadminctl -addUser failed."; exit 1; }
  uid=$(dscl . -read "/Users/$user" UniqueID 2>/dev/null | awk '{print $2}')
  case "$uid" in '' | *[!0-9]*) echo "User $user missing after creation."; exit 1 ;; esac
  created=yes
fi
case "$uid" in *[!0-9]*) echo "No local user $user."; exit 3 ;; esac
[ "$uid" -ge 500 ] || { echo "$user is a system account, refusing."; exit 3; }

if [ "$created" = no ]; then
  if dscl . -read "/Users/$user" AuthenticationAuthority 2>/dev/null | grep -q ';DisabledUser;'; then
    echo "Refusing to rotate $user: the account is disabled."
    exit 3
  fi
  # sysadminctl reads the password from stdin for "-newPassword -"; the fallback feeds dscl's
  # interactive mode on stdin, which only takes passwords without blanks, quotes or backslashes
  if ! printf '%s\n' "$pw" | sysadminctl -resetPasswordFor "$user" -newPassword - >/dev/null 2>&1; then
    case "$pw" in
    *[[:space:]\"\'\\]*) echo "sysadminctl -resetPasswordFor failed."; exit 1 ;;
    esac
    printf 'passwd /Users/%s %s\n' "$user" "$pw" | dscl . >/dev/null 2>&1 \
      || { echo "sysadminctl and dscl password reset failed."; exit 1; }
  fi
fi
echo "Password for $user rotated, created=$created"
exit 0
