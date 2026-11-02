#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports fail2ban state, its jails and the currently banned addresses per jail.
# Variables: none. Exit codes: 0 running, 1 installed but not running, 3 fail2ban not installed.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v fail2ban-client >/dev/null 2>&1 || { echo "fail2ban is not installed (package fail2ban)"; exit 3; }
if ! fail2ban-client ping >/dev/null 2>&1; then
  echo "fail2ban is installed but not running"
  exit 1
fi
jails=$(fail2ban-client status 2>/dev/null | sed -n 's/.*Jail list:[[:space:]]*//p' | tr -d ',')
n=0
for j in $jails; do n=$((n + 1)); done
echo "fail2ban running, $n jail(s)"
for j in $jails; do
  case $j in *[!A-Za-z0-9_.-]* | -*) continue ;; esac
  s=$(fail2ban-client status "$j" 2>/dev/null)
  cur=$(printf '%s\n' "$s" | sed -n 's/.*Currently banned:[[:space:]]*//p')
  tot=$(printf '%s\n' "$s" | sed -n 's/.*Total banned:[[:space:]]*//p')
  ips=$(printf '%s\n' "$s" | sed -n 's/.*Banned IP list:[[:space:]]*//p' | cut -c1-300)
  echo "$j: banned now $cur, total $tot${ips:+, $ips}"
done
exit 0
