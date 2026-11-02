#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Locks or unlocks a local account (password lock plus account expiry, so key logins stop too).
# Variables: TARGET_USER (required), STATE (lock, unlock; default lock).
# Exit codes: 0 in requested state, 1 failed, 3 bad input, unknown user or a guard refused it.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

u=${TARGET_USER:-}
st=${STATE:-lock}
[ -n "$u" ] || { echo "TARGET_USER is required"; exit 3; }
case $u in [!a-z_]* | *[!a-z0-9_-]*) echo "TARGET_USER has characters that are not allowed"; exit 3 ;; esac
case $st in lock | unlock) ;; *) echo "STATE must be lock or unlock"; exit 3 ;; esac
ent=$(getent passwd "$u") || { echo "User $u does not exist"; exit 3; }
uid=$(echo "$ent" | cut -d: -f3)
fld() { awk -F: -v u="$u" -v n="$1" '$1==u {print $n}' /etc/shadow; }
locked() { case $(fld 2) in '!'*) return 0 ;; esac; return 1; }
expired() { case $(fld 8) in 0 | 1) return 0 ;; esac; return 1; }

if [ "$st" = lock ]; then
  [ "$uid" -ne 0 ] || { echo "Refusing to lock root"; exit 3; }
  others=0
  for g in sudo wheel admin; do
    for m in $(getent group "$g" 2>/dev/null | cut -d: -f4 | tr ',' ' '); do
      [ "$m" = "$u" ] && continue
      case $(awk -F: -v u="$m" '$1==u {print $2}' /etc/shadow) in '!'* | '*'* | '') ;; *) others=$((others + 1)) ;; esac
    done
  done
  case $(awk -F: '$1=="root" {print $2}' /etc/shadow) in '' | '!'* | '*'*) ;; *) others=$((others + 1)) ;; esac
  mine=0
  for g in sudo wheel admin; do getent group "$g" 2>/dev/null | cut -d: -f4 | tr ',' '\n' | grep -qx "$u" && mine=1; done
  if [ "$mine" = 1 ] && [ "$others" -eq 0 ]; then
    echo "Refusing to lock $u: it is the last unlocked admin account"
    exit 3
  fi
  if locked && { expired || ! command -v usermod >/dev/null 2>&1; }; then echo "User $u already locked"; exit 0; fi
  if ! locked; then
    { usermod -L "$u" || passwd -l "$u"; } >/dev/null 2>&1 || { echo "Locking the password failed"; exit 1; }
  fi
  if command -v usermod >/dev/null 2>&1; then usermod -e 1 "$u" >/dev/null 2>&1 && ex=" and expired"; else ex=" (password only, no usermod to expire the account)"; fi
  locked || { echo "User $u is not locked after the change"; exit 1; }
  echo "User $u locked${ex:-}"
  exit 0
fi
done=
nohash=
case $(fld 2) in '!' | '!!' | '!*' | '!!*') nohash=1 ;; esac
if locked && [ -z "$nohash" ]; then
  { usermod -U "$u" || passwd -u "$u"; } >/dev/null 2>&1 || { echo "Unlocking failed"; exit 1; }
  done=1
fi
if expired && command -v usermod >/dev/null 2>&1; then usermod -e "" "$u" >/dev/null 2>&1 && done=1; fi
[ -z "$nohash" ] && locked && { echo "User $u still locked"; exit 1; }
[ -n "$nohash" ] && echo "Note: $u has no password (key login only), set one with the set password script"
if [ -n "$done" ]; then echo "User $u unlocked"; else echo "User $u already unlocked"; fi
case $(fld 2) in '') echo "Note: $u has an empty password" ;; esac
exit 0
