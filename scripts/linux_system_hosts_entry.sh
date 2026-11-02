#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Adds or removes a managed entry in /etc/hosts (marked with # ulrmm, other lines are never touched).
# Variables: ACTION (add, remove; default add), IP (required for add), ENTRY_HOSTNAME (required).
# Exit codes: 0 done, 1 failed, 3 bad input or the name is already mapped by an unmanaged line.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

act=${ACTION:-add}
ip=${IP:-}
hn=${ENTRY_HOSTNAME:-}
case $act in add | remove) ;; *) echo "ACTION must be add or remove"; exit 3 ;; esac
[ -n "$hn" ] || { echo "ENTRY_HOSTNAME is required"; exit 3; }
case $hn in -* | .* | *. | *..* | *[!A-Za-z0-9.-]*) echo "ENTRY_HOSTNAME has characters that are not allowed"; exit 3 ;; esac
[ ${#hn} -le 253 ] || { echo "ENTRY_HOSTNAME is too long"; exit 3; }
[ "$hn" != localhost ] || { echo "Refusing to touch localhost"; exit 3; }
if [ "$act" = add ]; then
  [ -n "$ip" ] || { echo "IP is required"; exit 3; }
  case $ip in *[!0-9A-Fa-f.:]* | '') echo "IP is not an IPv4 or IPv6 address"; exit 3 ;; esac
  case $ip in
  *:*) case $ip in *:::*) echo "IP is not valid"; exit 3 ;; esac ;;
  *)
    printf '%s' "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || { echo "IP is not a valid IPv4 address"; exit 3; }
    if printf '%s' "$ip" | tr '.' '\n' | awk '$1>255 {f=1} END {exit !f}'; then echo "IP is not a valid IPv4 address"; exit 3; fi
    ;;
  esac
fi
[ -f /etc/hosts ] || { echo "/etc/hosts not found"; exit 3; }
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT
managed=$(awk -v h="$hn" '/# ulrmm$/ && $0 !~ /^#/ {for (i=2;i<=NF;i++) if (tolower($i)==tolower(h)) {print $1; exit}}' /etc/hosts)
other=$(awk -v h="$hn" '$0 !~ /^[ \t]*#/ && $0 !~ /# ulrmm$/ {for (i=2;i<=NF;i++) if (tolower($i)==tolower(h)) {print $1; exit}}' /etc/hosts)
if [ "$act" = add ]; then
  if [ -n "$other" ]; then
    [ "$other" = "$ip" ] && { echo "$hn already maps to $ip"; exit 0; }
    echo "$hn is already mapped to $other by an unmanaged line, remove that line by hand first"
    exit 3
  fi
  [ "$managed" = "$ip" ] && { echo "$hn already maps to $ip"; exit 0; }
  awk -v h="$hn" '/# ulrmm$/ {ok=0; for (i=2;i<=NF;i++) if (tolower($i)==tolower(h)) ok=1; if (ok) next} {print}' /etc/hosts >"$tmp"
  printf '%s\t%s\t# ulrmm\n' "$ip" "$hn" >>"$tmp"
  cat "$tmp" >/etc/hosts || { echo "Writing /etc/hosts failed"; exit 1; }
  grep -q "^$ip	$hn	# ulrmm\$" /etc/hosts || { echo "Entry missing after write"; exit 1; }
  echo "Added $hn -> $ip${managed:+ (replaced $managed)}"
  if grep -Eqs '^[[:space:]]*manage_etc_hosts:[[:space:]]*(true|template|True)' /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.d/*.cfg; then
    echo "Note: cloud-init rewrites /etc/hosts at every boot (manage_etc_hosts); change /etc/cloud/templates/hosts.*.tmpl as well"
  fi
  exit 0
fi
if [ -z "$managed" ]; then
  [ -n "$other" ] && { echo "$hn is mapped by an unmanaged line, not removing it"; exit 3; }
  echo "$hn has no managed entry, nothing to do"
  exit 0
fi
awk -v h="$hn" '/# ulrmm$/ {ok=0; for (i=2;i<=NF;i++) if (tolower($i)==tolower(h)) ok=1; if (ok) next} {print}' /etc/hosts >"$tmp"
cat "$tmp" >/etc/hosts || { echo "Writing /etc/hosts failed"; exit 1; }
echo "Removed $hn ($managed)"
exit 0
