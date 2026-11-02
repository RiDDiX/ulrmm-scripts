#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Create a local user. TARGET_USER, FULL_NAME, PASSWORD (read by sysadminctl from stdin), ADMINISTRATOR (false).
# The new account gets no Secure Token unless it is the first one; that needs the credentials of an existing
# token holder, which this script does not take.
# Exit: 0 created or already there, 1 creation failed, 3 bad input, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

ok() { case "$1" in *$'\n'*) return 1 ;; esac; printf '%s' "$1" | LC_ALL=C grep -Eq "$2"; }

user=${TARGET_USER:-}
full=${FULL_NAME:-}
pass=${PASSWORD:-}
admin=${ADMINISTRATOR:-false}

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }
ok "$user" '^[a-z_][a-z0-9_.-]{0,30}$' || { echo "TARGET_USER must be 1-31 characters: a-z, 0-9, _ . - and not start with a digit."; exit 3; }
[ -n "$full" ] || full=$user
ok "$full" "^[A-Za-z0-9 ._'-]{1,60}\$" || { echo "FULL_NAME must be 1-60 characters: letters, digits, space and . _ ' -"; exit 3; }
[ ${#pass} -ge 8 ] && [ ${#pass} -le 128 ] || { echo "PASSWORD must be 8-128 characters."; exit 3; }
case "$pass" in *[[:cntrl:]]*) echo "PASSWORD must not contain control characters or line breaks."; exit 3 ;; esac
case "$admin" in true | false) ;; *) echo "ADMINISTRATOR must be true or false."; exit 3 ;; esac

if dscl . -read "/Users/$user" UniqueID >/dev/null 2>&1; then
  echo "User $user already exists, nothing changed."
  exit 0
fi

args=(-addUser "$user" -fullName "$full" -password -)
[ "$admin" = true ] && args+=(-admin)
out=$(printf '%s\n' "$pass" | sysadminctl "${args[@]}" 2>&1)

if ! dscl . -read "/Users/$user" UniqueID >/dev/null 2>&1; then
  echo "sysadminctl did not create the account."
  echo "$out" | grep -vi 'password' | head -n 5
  exit 1
fi
# no password hash, or an empty password that works, means the stdin password was not taken
if ! dscl . -read "/Users/$user" AuthenticationAuthority 2>/dev/null | grep -q ShadowHash ||
  dscl . -authonly "$user" "" </dev/null >/dev/null 2>&1; then
  sysadminctl -deleteUser "$user" >/dev/null 2>&1
  if dscl . -read "/Users/$user" UniqueID >/dev/null 2>&1; then
    echo "The account was created without the password (sysadminctl did not read it from stdin) and could not be removed. Delete $user by hand."
  else
    echo "The account was created without the password (sysadminctl did not read it from stdin) and was removed again."
  fi
  exit 1
fi

tok=$(sysadminctl -secureTokenStatus "$user" 2>&1 | sed -n 's/.*Secure token is \([A-Z]*\).*/\1/p' | head -n 1)
echo "User $user created (administrator: $admin)."
echo "Secure Token: ${tok:-unknown}. Without one the user cannot unlock FileVault at the login window."
exit 0
