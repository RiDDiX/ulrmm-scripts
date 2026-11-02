#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Reports the DNS resolver setup (resolv.conf, systemd-resolved, nsswitch) and runs test lookups.
# Variables: none
# Exit: 0 lookups work, 1 the public test lookup failed, 3 no resolver configuration and no lookup tool
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

have() { command -v "$1" >/dev/null 2>&1; }
[ -r /etc/resolv.conf ] || have getent || { echo "Unsupported: no /etc/resolv.conf and no getent"; exit 3; }
echo "resolv.conf: $(readlink -f /etc/resolv.conf 2>/dev/null)"
grep -E '^(nameserver|search|domain|options)' /etc/resolv.conf 2>/dev/null | sed 's/^/  /'
if [ -d /run/systemd/system ] && have resolvectl && systemctl is-active systemd-resolved >/dev/null 2>&1; then
  echo "systemd-resolved:"
  resolvectl status 2>/dev/null | grep -E 'Link |Current DNS|DNS Servers|DNS Domain|DNSSEC setting|Protocols' | cut -c1-120 | sed 's/^/  /'
fi
echo "nsswitch hosts: $(sed -n 's/^hosts:[[:space:]]*//p' /etc/nsswitch.conf 2>/dev/null)"

look() {
  if have getent; then getent ahosts "$1" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' '
  elif have nslookup; then nslookup "$1" 2>/dev/null | awk '/^Address/ && !/#/ {print $NF}' | tr '\n' ' '
  elif have host; then host "$1" 2>/dev/null | awk '/has address/ {print $NF}' | tr '\n' ' '; fi
}
rc=0
for n in localhost "$(hostname 2>/dev/null)" example.com; do
  [ -n "$n" ] || continue
  a=$(look "$n")
  if [ -n "$a" ]; then echo "lookup $n: $a"; else echo "lookup $n: FAILED"; [ "$n" = example.com ] && rc=1; fi
done
exit $rc
