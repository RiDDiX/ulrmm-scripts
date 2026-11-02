#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Opens, blocks or removes a firewall rule for one TCP or UDP port with ufw or firewalld.
# Variables: ACTION (allow, deny, remove; default allow), PORT (required, 1-65535), PROTOCOL (tcp, udp; default tcp).
# Exit codes: 0 rule in place, 1 failed, 3 bad input, no ufw or firewalld, or the rule would block SSH.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

act=${ACTION:-allow}
port=${PORT:-}
proto=${PROTOCOL:-tcp}
case $act in allow | deny | remove) ;; *) echo "ACTION must be allow, deny or remove"; exit 3 ;; esac
case $proto in tcp | udp) ;; *) echo "PROTOCOL must be tcp or udp"; exit 3 ;; esac
case $port in '' | *[!0-9]*) echo "PORT must be a whole number"; exit 3 ;; esac
[ ${#port} -le 5 ] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || { echo "PORT must be 1-65535"; exit 3; }
port=$((port + 0))

if [ "$act" != allow ]; then
  sshp=
  if command -v sshd >/dev/null 2>&1; then
    mkdir -p /run/sshd 2>/dev/null
    sshp=$(sshd -T 2>/dev/null | awk '$1=="port" {print $2} $1=="listenaddress" {n = split($2, a, ":"); print a[n]}')
  fi
  if [ "$proto" = tcp ] && printf '%s\n' 22 "$sshp" | grep -qx "$port"; then
    echo "Refusing to $act port $port/tcp: it is the SSH port"
    exit 3
  fi
fi

# the active firewall gets the rule; an installed but inactive ufw only when firewalld is not running
fwd=
command -v firewall-cmd >/dev/null 2>&1 && [ "$(firewall-cmd --state 2>/dev/null)" = running ] && fwd=1
if command -v ufw >/dev/null 2>&1 && { [ -z "$fwd" ] || ufw status 2>/dev/null | grep -q '^Status: active'; }; then
  r="$port/$proto"
  case $act in
  allow) ufw allow "$r" >/dev/null 2>&1 ;;
  deny) ufw deny "$r" >/dev/null 2>&1 ;;
  remove)
    ufw delete allow "$r" >/dev/null 2>&1
    ufw delete deny "$r" >/dev/null 2>&1
    ;;
  esac
  rules=$(ufw show added 2>/dev/null | grep -E "^ufw (allow|deny) $r\$")
  case $act in
  allow | deny) printf '%s\n' "$rules" | grep -qx "ufw $act $r" || { echo "ufw rule not present after change"; exit 1; } ;;
  remove) [ -z "$rules" ] || { echo "ufw rule still present"; exit 1; } ;;
  esac
  ufw status 2>/dev/null | grep -q '^Status: active' || echo "Note: ufw is not active, the rule applies once it is enabled"
  echo "ufw: $act $r done"
  exit 0
fi
if command -v firewall-cmd >/dev/null 2>&1; then
  [ "$(firewall-cmd --state 2>/dev/null)" = running ] || { echo "firewalld is installed but not running"; exit 3; }
  r="$port/$proto"
  rich="rule port port=$port protocol=$proto reject"
  for perm in --permanent ""; do
    case $act in
    allow)
      firewall-cmd $perm --remove-rich-rule="$rich" >/dev/null 2>&1
      firewall-cmd $perm --add-port="$r" >/dev/null 2>&1
      ;;
    deny)
      firewall-cmd $perm --remove-port="$r" >/dev/null 2>&1
      firewall-cmd $perm --add-rich-rule="$rich" >/dev/null 2>&1
      ;;
    remove)
      firewall-cmd $perm --remove-port="$r" >/dev/null 2>&1
      firewall-cmd $perm --remove-rich-rule="$rich" >/dev/null 2>&1
      ;;
    esac
  done
  open=$(firewall-cmd --permanent --query-port="$r" 2>/dev/null)
  blk=$(firewall-cmd --permanent --query-rich-rule="$rich" 2>/dev/null)
  case $act in
  allow) [ "$open" = yes ] || { echo "firewalld port not open after change"; exit 1; } ;;
  deny) [ "$blk" = yes ] || { echo "firewalld reject rule missing after change"; exit 1; } ;;
  remove) [ "$open" = no ] && [ "$blk" = no ] || { echo "firewalld rule still present"; exit 1; } ;;
  esac
  echo "firewalld: $act $r done (runtime and permanent)"
  exit 0
fi
echo "Neither ufw nor firewalld is installed; port rules are only supported for those"
exit 3
