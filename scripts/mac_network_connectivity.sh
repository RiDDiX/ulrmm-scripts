#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Connectivity test. TARGETS: host or host:port, one per line or comma separated (ping, or TCP connect with a port). DNS_NAME: optional name to resolve.
# Exit: 0 all reachable, 1 something failed, 3 bad input or not macOS.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

ok() { case "$1" in *$'\n'*) return 1 ;; esac; printf '%s' "$1" | LC_ALL=C grep -Eq "$2"; }

targets=$(printf '%s' "${TARGETS:-}" | tr ',' '\n')
dnsname=${DNS_NAME:-}

[ "$(uname -s)" = Darwin ] || { echo "Not macOS."; exit 3; }
hostre='^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$'
if [ -n "$dnsname" ]; then
  ok "$dnsname" "$hostre" || { echo "DNS_NAME is not a valid host name."; exit 3; }
fi

list=""
n=0
while IFS= read -r line; do
  line=$(printf '%s' "$line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -n "$line" ] || continue
  host=${line%%:*}
  port=""
  case "$line" in *:*) port=${line#*:} ;; esac
  ok "$host" "$hostre" || { echo "Bad target: $line"; exit 3; }
  if [ -n "$port" ]; then
    case "$port" in *[!0-9]*) echo "Bad port in: $line"; exit 3 ;; esac
    [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || { echo "Bad port in: $line"; exit 3; }
  fi
  n=$((n + 1))
  [ $n -le 50 ] || { echo "At most 50 targets."; exit 3; }
  list="$list$host $port
"
done <<EOT
$targets
EOT
[ -n "$list" ] || [ -n "$dnsname" ] || { echo "Give TARGETS or DNS_NAME."; exit 3; }

fail=0
total=0
details=""
if [ -n "$dnsname" ]; then
  total=$((total + 1))
  if dscacheutil -q host -a name "$dnsname" 2>/dev/null | grep -q '^ip'; then
    details="${details}ok   resolve $dnsname
"
  else
    details="${details}FAIL resolve $dnsname
"
    fail=$((fail + 1))
  fi
fi
while read -r host port; do
  [ -n "$host" ] || continue
  total=$((total + 1))
  if [ -n "$port" ]; then
    if nc -z -G 5 "$host" "$port" >/dev/null 2>&1; then
      details="${details}ok   $host:$port
"
    else
      details="${details}FAIL $host:$port
"
      fail=$((fail + 1))
    fi
  else
    if ping -c 2 -t 6 "$host" >/dev/null 2>&1; then
      details="${details}ok   ping $host
"
    else
      details="${details}FAIL ping $host
"
      fail=$((fail + 1))
    fi
  fi
done <<EOT
$list
EOT

if [ $fail -eq 0 ]; then echo "OK: $total of $total checks passed"; else echo "FAILING: $fail of $total checks failed"; fi
printf '%s' "$details"
[ $fail -eq 0 ]
