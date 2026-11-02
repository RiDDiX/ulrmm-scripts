#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Updates the ClamAV signatures now with freshclam.
# Variables: none.
# Exit: 0 updated or already current, 1 update failed, 3 ClamAV is not installed.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v freshclam >/dev/null 2>&1 || {
	echo "freshclam not found, run the ClamAV install script first (package clamav / clamav-update / freshclam)"
	exit 3
}

# A running freshclam daemon holds the log and database lock; pause it for the manual run.
unit=""
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
	for u in clamav-freshclam.service freshclam.service; do
		if systemctl is-active --quiet "$u"; then unit=$u; break; fi
	done
fi
openrc=false
if [ -z "$unit" ] && command -v rc-service >/dev/null 2>&1 && rc-service freshclam status >/dev/null 2>&1; then
	openrc=true
fi
[ -n "$unit" ] && systemctl stop "$unit"
$openrc && rc-service freshclam stop >/dev/null 2>&1

out=$(freshclam --stdout 2>&1)
rc=$?

[ -n "$unit" ] && systemctl start "$unit"
$openrc && rc-service freshclam start >/dev/null 2>&1

case $rc in
0 | 1)
	if echo "$out" | grep -q 'c[lv]d updated'; then echo "Signatures updated"; else echo "Signatures already current"; fi
	echo "$out" | sed -n -E 's/.*((main|daily|bytecode)\.c[lv]d.*)/\1/p'
	exit 0
	;;
*)
	echo "Signature update failed (freshclam exit $rc)"
	echo "$out" | grep -iE 'error|warning' | tail -n 5
	exit 1
	;;
esac
