#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Tests connectivity: ping for a host, TCP connect for host:port, and an optional DNS lookup.
# Variables: TARGETS (host or host:port, one per line, required), DNS_NAME (name to resolve, optional)
# Exit: 0 everything reachable, 1 at least one test failed, 3 bad input or required tool missing
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

have() { command -v "$1" >/dev/null 2>&1; }
LIST=$(printf '%s\n' "${TARGETS:-}" | tr ',' '\n' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d')
[ -n "$LIST" ] || { echo "TARGETS is required"; exit 3; }
hostok() { case $1 in '' | -* | *[!A-Za-z0-9.-]*) return 1 ;; esac; }
needping=0 needtcp=0
for t in $LIST; do
  case $t in
  *:*)
    h=${t%:*} p=${t##*:}
    hostok "$h" || { echo "Bad host in target: $t (IPv6 literals are not supported)"; exit 3; }
    case $p in '' | *[!0-9]*) echo "Bad port in target: $t"; exit 3 ;; esac
    { [ "${#p}" -le 5 ] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]; } || { echo "Port out of range: $t"; exit 3; }
    needtcp=1 ;;
  *) hostok "$t" || { echo "Bad host in target: $t"; exit 3; }; needping=1 ;;
  esac
done
D=${DNS_NAME:-}
[ -z "$D" ] || hostok "$D" || { echo "Bad DNS_NAME: only letters, digits, dots and dashes"; exit 3; }
[ $needping -eq 0 ] || have ping || { echo "Unsupported: ping is not installed (iputils-ping, iputils or inetutils)"; exit 3; }
tcp=''
if [ $needtcp -eq 1 ]; then
  if have nc; then tcp=nc
  elif have curl; then tcp=curl
  else echo "Unsupported: no nc or curl for TCP tests (install netcat-openbsd or curl)"; exit 3; fi
fi

nl='
'
bad='' ok='' n=0
for t in $LIST; do
  n=$((n + 1))
  case $t in
  *:*)
    h=${t%:*} p=${t##*:}
    if [ $tcp = nc ]; then nc -z -w 5 "$h" "$p" >/dev/null 2>&1; else curl -sS -m 5 "telnet://$h:$p" </dev/null >/dev/null 2>&1; fi
    r=$? ;;
  *) ping -c 2 -W 3 "$t" >/dev/null 2>&1 || ping -c 2 -w 6 "$t" >/dev/null 2>&1; r=$? ;;
  esac
  if [ $r -eq 0 ]; then ok="$ok$t "; else bad="$bad$t: unreachable$nl"; fi
done
if [ -n "$D" ]; then
  n=$((n + 1))
  a=''
  if have getent; then a=$(getent ahosts "$D" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ')
  elif have nslookup; then a=$(nslookup "$D" 2>/dev/null | awk '/^Address/ && !/#/ {print $NF}' | tr '\n' ' ')
  elif have host; then a=$(host "$D" 2>/dev/null | awk '/has address/ {print $NF}' | tr '\n' ' ')
  else echo "Unsupported: no getent, nslookup or host for the DNS test"; exit 3; fi
  if [ -n "$a" ]; then ok="$ok$D=$a"; else bad="$bad$D: DNS lookup failed$nl"; fi
fi
if [ -z "$bad" ]; then
  echo "OK: $n tests passed ($ok)"
  exit 0
fi
echo "ERROR: $(printf '%s' "$bad" | wc -l) of $n tests failed"
printf '%s' "$bad"
exit 1
