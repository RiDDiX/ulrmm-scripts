#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Creates a local user, optionally with password, sudo rights and an SSH key; an existing user is only completed.
# Variables: TARGET_USER (required), PASSWORD (optional), SUDO (default false), SSH_PUBLIC_KEY (optional), LOGIN_SHELL (optional, default /bin/bash or /bin/sh).
# Exit codes: 0 user in place, 1 failed, 3 bad input or unsupported system.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

u=${TARGET_USER:-}
pw=${PASSWORD:-}
sudo_=${SUDO:-false}
key=${SSH_PUBLIC_KEY:-}
shl=${LOGIN_SHELL:-}
[ -n "$u" ] || { echo "TARGET_USER is required"; exit 3; }
case $u in [!a-z_]* | *[!a-z0-9_-]*) echo "TARGET_USER must be lowercase letters, digits, - and _, starting with a letter or _"; exit 3 ;; esac
[ ${#u} -le 32 ] || { echo "TARGET_USER is longer than 32 characters"; exit 3; }
case $sudo_ in true | false) ;; *) echo "SUDO must be true or false"; exit 3 ;; esac
if [ "$sudo_" = true ] && ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is not installed: install the sudo package, then run again"
  exit 3
fi
if [ -n "$pw" ]; then
  [ ${#pw} -ge 8 ] && [ ${#pw} -le 128 ] || { echo "PASSWORD must be 8-128 characters"; exit 3; }
  case $pw in *"
"*) echo "PASSWORD must not contain a line break"; exit 3 ;; esac
fi
if [ -n "$key" ]; then
  key=$(printf '%s' "$key" | tr -d '\r' | sed -n '1p')
  echo "$key" | grep -Eq '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com) [A-Za-z0-9+/]{40,}=*( [[:print:]]*)?$' ||
    { echo "SSH_PUBLIC_KEY is not a plain public key line"; exit 3; }
fi
if [ -z "$shl" ]; then
  if [ -x /bin/bash ]; then shl=/bin/bash; else shl=/bin/sh; fi
fi
case $shl in /*) ;; *) echo "LOGIN_SHELL must be an absolute path"; exit 3 ;; esac
case $shl in *[!A-Za-z0-9/_.-]*) echo "LOGIN_SHELL has characters that are not allowed"; exit 3 ;; esac
grep -qx "$shl" /etc/shells 2>/dev/null && [ -x "$shl" ] || { echo "LOGIN_SHELL $shl is not listed in /etc/shells or not installed"; exit 3; }

did=
if getent passwd "$u" >/dev/null 2>&1; then
  echo "User $u already exists"
else
  if command -v useradd >/dev/null 2>&1; then
    useradd -m -s "$shl" "$u" >/dev/null 2>&1 || { echo "useradd failed"; exit 1; }
  elif command -v adduser >/dev/null 2>&1; then
    adduser -D -s "$shl" "$u" >/dev/null 2>&1 || { echo "adduser failed"; exit 1; }
    printf '%s:*\n' "$u" | chpasswd -e >/dev/null 2>&1
  else
    echo "Neither useradd nor adduser found"
    exit 3
  fi
  getent passwd "$u" >/dev/null 2>&1 || { echo "User $u missing after creation"; exit 1; }
  did="created"
fi
home=$(getent passwd "$u" | cut -d: -f6)

if [ -n "$pw" ]; then
  printf '%s:%s\n' "$u" "$pw" | chpasswd >/dev/null 2>&1 || { echo "Setting the password failed"; exit 1; }
  did="${did:+$did, }password set"
fi
if [ "$sudo_" = true ]; then
  command -v sudo >/dev/null 2>&1 || { echo "sudo is not installed: install the sudo package, then run again"; exit 3; }
  g=
  for c in sudo wheel; do getent group "$c" >/dev/null 2>&1 && g=$c && break; done
  if [ -z "$g" ]; then
    groupadd wheel >/dev/null 2>&1 || addgroup -S wheel >/dev/null 2>&1
    g=wheel
  fi
  if ! id -Gn "$u" | tr ' ' '\n' | grep -qx "$g"; then
    { usermod -aG "$g" "$u" || addgroup "$u" "$g"; } >/dev/null 2>&1 || { echo "Adding $u to $g failed"; exit 1; }
    did="${did:+$did, }added to $g"
  fi
  if ! cat /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -Eq "^%${g}[[:space:]]"; then
    f=/etc/sudoers.d/ulrmm-$g
    mkdir -p /etc/sudoers.d
    printf '%%%s ALL=(ALL:ALL) ALL\n' "$g" >"$f.tmp"
    chmod 440 "$f.tmp"
    if command -v visudo >/dev/null 2>&1 && ! visudo -cf "$f.tmp" >/dev/null 2>&1; then rm -f "$f.tmp"; echo "sudoers rule invalid"; exit 1; fi
    mv "$f.tmp" "$f"
    did="${did:+$did, }sudoers rule for %$g added"
  fi
  [ -n "$pw" ] || echo "Note: $u has no password, sudo will ask for one"
fi
if [ -n "$key" ]; then
  [ -d "$home" ] && [ ! -L "$home" ] && [ "$home" != / ] || { echo "Home directory $home is not usable for an SSH key"; exit 1; }
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
  0) did="${did:+$did, }SSH key added" ;;
  10) echo "SSH key already present" ;;
  4) echo "Home directory $home is not usable"; exit 1 ;;
  5) echo "$home/.ssh or its authorized_keys is a symlink or not a regular file, refusing"; exit 1 ;;
  *) echo "Writing $home/.ssh/authorized_keys as $u failed (exit $rc): check ownership, or the account is expired"; exit 1 ;;
  esac
fi
echo "User $u ready${did:+ ($did)}"
exit 0
