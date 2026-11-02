#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists scheduled jobs: system crontab, cron.d, per-user crontabs, periodic directories, systemd timers, at jobs.
# Variables: none
# Exit: 0 report printed
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

show() {
  [ -r "$1" ] || return 0
  body=$(grep -v '^[[:space:]]*#' "$1" 2>/dev/null | grep -v '^[[:space:]]*$' | grep -Ev '^[A-Za-z_]+=')
  [ -n "$body" ] || return 0
  echo "== $1"
  printf '%s\n' "$body" | cut -c1-200 | sed 's/^/  /'
}
show /etc/crontab
for f in /etc/cron.d/*; do [ -f "$f" ] && show "$f"; done
for dir in /var/spool/cron/crontabs /var/spool/cron/tabs /var/spool/cron /etc/crontabs; do
  [ -d "$dir" ] || continue
  for f in "$dir"/*; do [ -f "$f" ] && show "$f"; done
done
echo "== periodic directories"
for d in hourly daily weekly monthly; do
  [ -d "/etc/cron.$d" ] && echo "  cron.$d: $(for j in "/etc/cron.$d"/*; do [ -e "$j" ] && printf '%s ' "${j##*/}"; done)"
done
[ -d /etc/periodic ] && for d in /etc/periodic/*; do [ -d "$d" ] && echo "  periodic/${d##*/}: $(for j in "$d"/*; do [ -e "$j" ] && printf '%s ' "${j##*/}"; done)"; done
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
  echo "== systemd timers"
  systemctl list-timers --all --no-pager --no-legend 2>/dev/null | cut -c1-160 | sed 's/^/  /'
fi
if command -v atq >/dev/null 2>&1; then
  a=$(atq 2>/dev/null)
  [ -n "$a" ] && { echo "== at jobs"; printf '%s\n' "$a" | sed 's/^/  /'; }
fi
exit 0
