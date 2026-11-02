#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# DNS report: resolvers and search domains from scutil --dns, plus test lookups. No variables.
# Exit: 0 resolvers present and lookups work, 1 no resolver or all lookups failed, 2 some lookups failed, 3 not macOS.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

[ "$(uname -s)" = Darwin ] || { echo "Not macOS."; exit 3; }

dns=$(scutil --dns 2>/dev/null)
ns=$(echo "$dns" | sed -n 's/^ *nameserver\[[0-9]*\] : //p' | sort -u)
search=$(echo "$dns" | sed -n 's/^ *search domain\[[0-9]*\] : //p' | sort -u)

ok=0
fail=0
res=""
for name in apple.com example.com; do
  if dscacheutil -q host -a name "$name" 2>/dev/null | grep -q '^ip'; then
    res="${res}lookup $name: ok
"
    ok=$((ok + 1))
  else
    res="${res}lookup $name: FAILED
"
    fail=$((fail + 1))
  fi
done

rc=0
if [ -z "$ns" ]; then
  rc=1
  echo "FAILING: no nameserver configured"
elif [ $fail -eq 0 ]; then
  echo "OK: all $ok test lookups work"
elif [ $ok -eq 0 ]; then
  rc=1
  echo "FAILING: no test lookup works"
else
  rc=2
  echo "WARNING: $fail of $((ok + fail)) test lookups failed"
fi
echo "Nameservers: $(echo "$ns" | tr '\n' ' ')"
echo "Search domains: $(echo "$search" | tr '\n' ' ')"
echo "Resolvers: $(echo "$dns" | grep -c '^resolver #')"
printf '%s' "$res"
exit $rc
