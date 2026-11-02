#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks ClamAV: installed, signature age and whether automatic signature updates run.
# Variables: WARN_DAYS (2) and FAIL_DAYS (7) signature age thresholds in days.
# Exit: 0 ok, 1 not installed or signatures older than FAIL_DAYS, 2 warning, 3 bad input.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

warn_days=${WARN_DAYS:-2}
fail_days=${FAIL_DAYS:-7}
for v in "$warn_days" "$fail_days"; do
	case "$v" in
	'' | *[!0-9]*) echo "WARN_DAYS and FAIL_DAYS must be whole numbers"; exit 3 ;;
	esac
done
[ "$warn_days" -le "$fail_days" ] || { echo "WARN_DAYS must not be larger than FAIL_DAYS"; exit 3; }

if ! command -v clamscan >/dev/null 2>&1; then
	echo "FAIL: ClamAV is not installed"
	exit 1
fi
version=$(clamscan --version 2>/dev/null)

dbdir=""
for conf in /etc/clamav/freshclam.conf /etc/freshclam.conf; do
	[ -f "$conf" ] || continue
	dbdir=$(sed -n 's/^DatabaseDirectory[[:space:]]\{1,\}//p' "$conf" | tail -n 1)
	break
done
[ -n "$dbdir" ] || dbdir=/var/lib/clamav

newest=0
for f in "$dbdir"/daily.cld "$dbdir"/daily.cvd; do
	[ -f "$f" ] || continue
	t=$(stat -c %Y "$f" 2>/dev/null || echo 0)
	[ "$t" -gt "$newest" ] && newest=$t
done

updater=none
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
	for u in clamav-freshclam.service freshclam.service freshclam.timer; do
		if systemctl is-active --quiet "$u"; then updater=$u; break; fi
	done
elif command -v rc-service >/dev/null 2>&1 && rc-service freshclam status >/dev/null 2>&1; then
	updater="OpenRC freshclam"
fi
if [ "$updater" = none ] && grep -qs freshclam /etc/crontab /etc/cron.d/* /etc/crontabs/root /var/spool/cron/crontabs/root /var/spool/cron/root; then
	updater=cron
fi

if [ "$newest" -eq 0 ]; then
	echo "FAIL: no daily signature database in $dbdir"
	echo "$version"
	exit 1
fi
age=$((($(date +%s) - newest) / 86400))
detail="signatures ${age} day(s) old, automatic updates: $updater"

if [ "$age" -ge "$fail_days" ]; then
	echo "FAIL: $detail"; rc=1
elif [ "$age" -ge "$warn_days" ] || [ "$updater" = none ]; then
	echo "WARNING: $detail"; rc=2
else
	echo "OK: $detail"; rc=0
fi
echo "$version"
echo "Database: $dbdir, daily updated $(date -d "@$newest" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$newest")"
exit $rc
