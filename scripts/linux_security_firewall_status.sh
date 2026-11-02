#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports which host firewall is active (ufw, firewalld, nftables, iptables), its default policy and open ports.
# Variables: none. Exit codes: 0 a firewall filters, 1 nothing filters, 3 no firewall tool installed.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

active=
detail=
found=
if command -v ufw >/dev/null 2>&1; then
  found=1
  s=$(ufw status verbose 2>/dev/null)
  case $s in
  *"Status: active"*)
    active="$active ufw"
    detail="$detail
ufw: $(printf '%s\n' "$s" | grep '^Default:')
ufw rules: $(printf '%s\n' "$s" | awk '/ALLOW|DENY|REJECT|LIMIT/ && !/\(v6\)/ {printf "%s %s; ", $1, $(NF-1)" "$NF}' | cut -c1-600)"
    ;;
  esac
fi
if command -v firewall-cmd >/dev/null 2>&1; then
  found=1
  if [ "$(firewall-cmd --state 2>/dev/null)" = running ]; then
    active="$active firewalld"
    z=$(firewall-cmd --get-default-zone 2>/dev/null)
    detail="$detail
firewalld: default zone $z, services: $(firewall-cmd --list-services 2>/dev/null), ports: $(firewall-cmd --list-ports 2>/dev/null)"
  fi
fi
if command -v nft >/dev/null 2>&1; then
  found=1
  n=$(nft list ruleset 2>/dev/null)
  # only input chains count: container runtimes add forward chains with a drop policy on their own
  if printf '%s\n' "$n" | awk '/^[[:space:]]*chain / {c = 0} /hook input/ {c = 1; if (/policy drop/) a = 1; next} c && /(drop|reject)/ {a = 1} END {exit !a}'; then
    pol=$(printf '%s\n' "$n" | grep -Eo 'hook input[^;]*; (policy [a-z]+)?' | head -1)
    if ! printf '%s\n' "$active" | grep -Eq 'ufw|firewalld'; then
      active="$active nftables"
      detail="$detail
nftables: $pol, ports: $(printf '%s\n' "$n" | grep -Eo '(tcp|udp) dport [{ 0-9,a-z-]+' | tr '\n' ';' | cut -c1-400)"
    fi
  fi
fi
if command -v iptables >/dev/null 2>&1; then
  found=1
  i=$(iptables -S 2>/dev/null)
  if printf '%s\n' "$i" | grep -Eq '^-P INPUT (DROP|REJECT)|^-A INPUT .*-j (DROP|REJECT)'; then
    case $active in *ufw* | *firewalld* | *nftables*) ;; *)
      active="$active iptables"
      detail="$detail
iptables: $(printf '%s\n' "$i" | grep '^-P INPUT'), ports: $(printf '%s\n' "$i" | grep -Eo -e '-p (tcp|udp).*--dport [0-9:]+' | tr '\n' ';' | cut -c1-400)"
      ;;
    esac
  fi
fi
if [ -z "$found" ]; then
  echo "No firewall tool installed (ufw, firewalld, nft, iptables)"
  exit 3
fi
if [ -z "$active" ]; then
  echo "No active firewall: nothing filters inbound traffic"
  exit 1
fi
echo "Firewall active:$active"
printf '%s\n' "$detail" | sed '/^$/d'
exit 0
