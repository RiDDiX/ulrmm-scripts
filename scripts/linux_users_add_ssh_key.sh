#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Adds an SSH public key to a user's authorized_keys (format checked, no duplicates, written as that user).
# Variables: TARGET_USER (required), PUBLIC_KEY (required, one key line without options).
# Exit codes: 0 key in place, 1 failed, 3 bad input or unknown user.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

u=${TARGET_USER:-}
key=${PUBLIC_KEY:-}
[ -n "$u" ] || { echo "TARGET_USER is required"; exit 3; }
case $u in [!a-z_]* | *[!a-z0-9_-]*) echo "TARGET_USER has characters that are not allowed"; exit 3 ;; esac
[ -n "$key" ] || { echo "PUBLIC_KEY is required"; exit 3; }
lines=$(printf '%s\n' "$key" | tr -d '\r' | sed '/^[[:space:]]*$/d' | wc -l)
[ "$lines" -eq 1 ] || { echo "PUBLIC_KEY must be exactly one line"; exit 3; }
key=$(printf '%s\n' "$key" | tr -d '\r' | sed '/^[[:space:]]*$/d')
printf '%s\n' "$key" | grep -Eq '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com) [A-Za-z0-9+/]{40,}=*( [[:print:]]*)?$' ||
  { echo "PUBLIC_KEY is not a plain public key line (options such as command= are refused)"; exit 3; }
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$key" >"$tmp"
if command -v ssh-keygen >/dev/null 2>&1; then
  fp=$(ssh-keygen -l -f "$tmp" 2>/dev/null) || { echo "ssh-keygen rejects this key"; exit 3; }
else
  fp="(not verified with ssh-keygen, it is not installed)"
fi
ent=$(getent passwd "$u") || { echo "User $u does not exist"; exit 3; }
home=$(echo "$ent" | cut -d: -f6)
[ -d "$home" ] && [ ! -L "$home" ] && [ "$home" != / ] || { echo "Home directory $home is not usable"; exit 1; }
# Written as the user, so a symlink or hard link the user planted cannot redirect a root write.
# shellcheck disable=SC2016
KEYLINE=$key KEYHOME=$home su -s /bin/sh "$u" -c '
umask 077
cd "$KEYHOME" || exit 4
f=.ssh/authorized_keys
if [ -L .ssh ] || [ -L "$f" ] || { [ -e "$f" ] && [ ! -f "$f" ]; }; then exit 5; fi
mkdir -p .ssh && chmod 700 .ssh || exit 6
b=$(printf "%s\n" "$KEYLINE" | awk "{print \$2}")
if [ -f "$f" ] && awk -v b="$b" "\$2==b || \$3==b {f=1} END {exit !f}" "$f"; then chmod 600 "$f"; exit 10; fi
if [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ]; then printf "\n" >>"$f" || exit 6; fi
printf "%s\n" "$KEYLINE" >>"$f" && chmod 600 "$f" || exit 6
' </dev/null >/dev/null 2>&1
rc=$?
case $rc in
0) new=1 ;;
10) new=0 ;;
4) echo "Home directory $home is not usable"; exit 1 ;;
5) echo "$home/.ssh or its authorized_keys is a symlink or not a regular file, refusing"; exit 1 ;;
*) echo "Writing $home/.ssh/authorized_keys as $u failed (exit $rc): check ownership, or the account is expired"; exit 1 ;;
esac
if [ "$new" = 1 ]; then echo "Key added for $u: $fp"; else echo "Key already present for $u: $fp"; fi
exit 0
