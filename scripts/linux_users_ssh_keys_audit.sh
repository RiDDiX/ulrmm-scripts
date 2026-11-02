#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists the authorized SSH keys of every account with fingerprint and size; flags weak keys.
# Variables: none. Exit codes: 0 done, 2 weak keys (DSA or RSA below 2048 bits) found, 3 ssh-keygen missing.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

command -v ssh-keygen >/dev/null 2>&1 || { echo "ssh-keygen not found: install openssh-client (openssh-clients, openssh)"; exit 3; }
tmp=$(mktemp) || exit 3
trap 'rm -f "$tmp"' EXIT
total=0
weak=0
awk -F: '$6!="" && $6!="/" {print $1":"$6}' /etc/passwd | while IFS=: read -r u home; do
  f=$home/.ssh/authorized_keys
  [ -f "$f" ] && [ ! -L "$f" ] || continue
  ssh-keygen -l -f "$f" 2>/dev/null | while read -r bits fp rest; do
    printf '%s %s %s %s\n' "$u" "$bits" "$fp" "$rest"
  done
done >"$tmp"
total=$(wc -l <"$tmp")
weak=$(awk '($2<2048 && $NF!="(ED25519)" && $NF!="(ECDSA)" && $NF!="(ECDSA-SK)" && $NF!="(ED25519-SK)") || $NF=="(DSA)" {c++} END {print c+0}' "$tmp")
if [ "$weak" -gt 0 ]; then echo "$total key(s), $weak weak"; else echo "$total key(s), none weak"; fi
cat "$tmp"
[ "$weak" -eq 0 ] || exit 2
exit 0
