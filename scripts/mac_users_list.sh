#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# List local user accounts with admin rights, Secure Token state, last login. No variables.
# Exit: 0 listed, 3 not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }

admins=" $(dscl . -read /Groups/admin GroupMembership 2>/dev/null | sed 's/^GroupMembership://') "
count=0
printf '%-20s %-5s %-6s %-9s %-8s %s\n' USER UID ADMIN TOKEN DISABLED LAST_LOGIN
while read -r name uid; do
  case "$name" in '' | _*) continue ;; esac
  case "$uid" in '' | *[!0-9]*) continue ;; esac
  [ "$uid" -ge 500 ] || continue
  adm=no
  case "$admins" in *" $name "*) adm=yes ;; esac
  tok=$(sysadminctl -secureTokenStatus "$name" 2>&1 | sed -n 's/.*Secure token is \([A-Z]*\).*/\1/p' | head -n 1)
  [ -n "$tok" ] || tok=unknown
  dis=no
  dscl . -read "/Users/$name" AuthenticationAuthority 2>/dev/null | grep -q ';DisabledUser;' && dis=yes
  last=$(last -1 "$name" 2>/dev/null | sed -n "1s/^$name  *//p" | sed 's/  */ /g')
  [ -n "$last" ] || last=never
  printf '%-20s %-5s %-6s %-9s %-8s %s\n' "$name" "$uid" "$adm" "$tok" "$dis" "$last"
  count=$((count + 1))
done < <(dscl . -list /Users UniqueID)
echo "$count local accounts."
exit 0
