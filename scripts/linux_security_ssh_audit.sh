#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Audits the effective sshd settings (sshd -T) for weak configuration.
# Variables: none. Exit codes: 0 no findings, 2 weak settings found, 3 sshd not installed or not readable.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

command -v sshd >/dev/null 2>&1 || { echo "sshd is not installed"; exit 3; }
tmp=$(mktemp -d) || exit 3
trap 'rm -rf "$tmp"' EXIT
cfg=
[ -f /etc/ssh/sshd_config ] && cfg="-f /etc/ssh/sshd_config"
# shellcheck disable=SC2086
if ! sshd -T $cfg >"$tmp/t" 2>/dev/null; then
  command -v ssh-keygen >/dev/null 2>&1 && ssh-keygen -q -t ed25519 -N '' -f "$tmp/k" >/dev/null 2>&1
  # shellcheck disable=SC2086
  sshd -T $cfg -h "$tmp/k" >"$tmp/t" 2>"$tmp/e" || { echo "sshd -T failed: $(head -1 "$tmp/e")"; exit 3; }
fi
g() { awk -v k="$1" '$1==k {sub(/^[^ ]+ /,""); print; exit}' "$tmp/t"; }
find=
add() { find="$find
- $*"; }

[ "$(g permitrootlogin)" = yes ] && add "root login with password is allowed (PermitRootLogin yes)"
[ "$(g passwordauthentication)" = yes ] && add "password authentication is on"
[ "$(g permitemptypasswords)" = yes ] && add "empty passwords are allowed"
[ "$(g hostbasedauthentication)" = yes ] && add "host-based authentication is on"
[ "$(g permituserenvironment)" = yes ] && add "PermitUserEnvironment is on"
[ "$(g ignorerhosts)" = no ] && add "rhosts files are honoured"
[ "$(g pubkeyauthentication)" = no ] && add "public key authentication is off"
m=$(g maxauthtries)
[ -n "$m" ] && [ "$m" -gt 6 ] 2>/dev/null && add "MaxAuthTries is $m"
[ "$(g protocol)" = 1 ] && add "protocol 1 is enabled"
g ciphers | tr ',' '\n' | grep -Eq '3des|arcfour|blowfish|cast128|-cbc' && add "weak ciphers are offered (CBC, 3DES or RC4)"
g macs | tr ',' '\n' | grep -Eq '^hmac-md5|-96$' && add "weak MACs are offered (MD5 or 96-bit)"
g kexalgorithms | tr ',' '\n' | grep -Eq 'diffie-hellman-group1-|diffie-hellman-group-exchange-sha1' && add "weak key exchange is offered (SHA1 or group1)"

echo "port $(g port), root login $(g permitrootlogin), password auth $(g passwordauthentication), empty passwords $(g permitemptypasswords)"
if [ -n "$find" ]; then
  echo "SSH configuration has weak settings:$find"
  exit 2
fi
echo "SSH configuration looks sound"
exit 0
