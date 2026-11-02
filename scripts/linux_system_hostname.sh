#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows the host name, or sets it (also in /etc/hostname and /etc/hosts).
# Variables: NEW_HOSTNAME (optional, empty = only report).
# Exit codes: 0 done, 1 failed, 3 bad input.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

new=${NEW_HOSTNAME:-}
old=$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname)
if [ -z "$new" ]; then
  echo "Host name: $old"
  exit 0
fi
[ ${#new} -le 253 ] || { echo "NEW_HOSTNAME is longer than 253 characters"; exit 3; }
case $new in -* | .* | *. | *..* | *[!A-Za-z0-9.-]*) echo "NEW_HOSTNAME must be letters, digits, - and . (no leading dash or dot)"; exit 3 ;; esac
oldifs=$IFS
IFS=.
for l in $new; do
  case $l in -* | *-) echo "NEW_HOSTNAME labels must not start or end with a dash"; IFS=$oldifs; exit 3 ;; esac
  [ ${#l} -le 63 ] || { echo "NEW_HOSTNAME label longer than 63 characters"; IFS=$oldifs; exit 3; }
done
IFS=$oldifs
if [ "$old" = "$new" ] && [ "$(cat /etc/hostname 2>/dev/null)" = "$new" ]; then
  echo "Host name already $new"
  exit 0
fi
set_name() {
  if [ -d /run/systemd/system ] && command -v hostnamectl >/dev/null 2>&1 && hostnamectl set-hostname "$new" >/dev/null 2>&1; then return 0; fi
  printf '%s\n' "$new" >/etc/hostname || return 1
  hostname "$new" >/dev/null 2>&1 || printf '%s' "$new" >/proc/sys/kernel/hostname 2>/dev/null
}
set_name || { echo "Setting the host name failed"; exit 1; }
printf '%s\n' "$new" >/etc/hostname 2>/dev/null
if [ -f /etc/hosts ]; then
  tmp=$(mktemp) || exit 1
  short=${new%%.*}
  if grep -Eq '^127\.0\.1\.1[[:space:]]' /etc/hosts; then
    awk -v n="$new" -v s="$short" '/^127\.0\.1\.1[ \t]/ { if (n==s) print "127.0.1.1\t" n; else print "127.0.1.1\t" n " " s; next } {print}' /etc/hosts >"$tmp"
  elif [ "$old" != localhost ] && grep -Eq "(^|[[:space:]])$old([[:space:]]|\$)" /etc/hosts; then
    awk -v o="$old" -v n="$new" '/^#/ {print; next} {for (i=2;i<=NF;i++) if ($i==o) $i=n; print}' /etc/hosts >"$tmp"
  else
    awk '{print}' /etc/hosts >"$tmp"
    printf '127.0.1.1\t%s\n' "$new" >>"$tmp"
  fi
  cat "$tmp" >/etc/hosts
  rm -f "$tmp"
fi
now=$(cat /proc/sys/kernel/hostname)
[ "$now" = "$new" ] || { echo "Host name is $now after the change"; exit 1; }
echo "Host name changed from $old to $new"
if grep -Eqs '^[[:space:]]*manage_etc_hosts:[[:space:]]*(true|template|True)' /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.d/*.cfg; then
  echo "Note: cloud-init rewrites /etc/hosts at every boot (manage_etc_hosts); change /etc/cloud/templates/hosts.*.tmpl as well"
fi
exit 0
