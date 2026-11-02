#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Installs ClamAV with freshclam, enables automatic signature updates and loads the signatures.
# Variables: ENABLE_EPEL (true) add EPEL on RHEL-family systems when ClamAV is not available otherwise.
# Exit: 0 installed or already in place, 1 failed, 3 bad input or unsupported system.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

enable_epel=${ENABLE_EPEL:-true}
case "$enable_epel" in
true | false) ;;
*) echo "ENABLE_EPEL must be true or false"; exit 3 ;;
esac

[ "$(id -u)" -eq 0 ] || { echo "Must run as root"; exit 3; }

# Runs a package manager command quietly and shows its last lines only when it fails.
pkg() {
	out=$("$@" 2>&1)
	prc=$?
	[ $prc -eq 0 ] || echo "$out" | tail -n 5
	return $prc
}

if command -v clamscan >/dev/null 2>&1 && command -v freshclam >/dev/null 2>&1; then
	echo "ClamAV already installed: $(clamscan --version 2>/dev/null)"
else
	if command -v apt-get >/dev/null 2>&1; then
		export DEBIAN_FRONTEND=noninteractive
		pkg apt-get update -q && pkg apt-get install -y -q clamav clamav-freshclam
	elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
		pm=dnf
		command -v dnf >/dev/null 2>&1 || pm=yum
		if ! "$pm" -q list clamav >/dev/null 2>&1; then
			if [ "$enable_epel" != true ]; then
				echo "ClamAV is not in the enabled repositories and ENABLE_EPEL is false"
				exit 3
			fi
			echo "Adding the EPEL repository"
			pkg "$pm" -y -q install epel-release || {
				echo "Cannot install epel-release (on RHEL enable codeready-builder and install EPEL from fedoraproject.org)"
				exit 1
			}
		fi
		pkg "$pm" -y -q install clamav clamav-update
	elif command -v zypper >/dev/null 2>&1; then
		pkg zypper --non-interactive --quiet install clamav
	elif command -v pacman >/dev/null 2>&1; then
		# No -y here: a refresh without a full upgrade is a partial upgrade on Arch.
		pkg pacman -S --noconfirm --needed clamav || { echo "If the package was not found, run pacman -Syu first"; false; }
	elif command -v apk >/dev/null 2>&1; then
		pkg apk add -q clamav clamav-scanner freshclam
	else
		echo "No supported package manager (apt-get, dnf, yum, zypper, pacman, apk)"
		exit 3
	fi
	rc=$?
	if [ $rc -ne 0 ] || ! command -v clamscan >/dev/null 2>&1 || ! command -v freshclam >/dev/null 2>&1; then
		echo "Package installation failed (exit $rc)"
		exit 1
	fi
	echo "Installed: $(clamscan --version 2>/dev/null)"
fi

# Some packages ship freshclam.conf with an "Example" line that disables it.
for conf in /etc/freshclam.conf /etc/clamav/freshclam.conf; do
	if [ -f "$conf" ] && grep -q '^Example' "$conf"; then
		sed -i 's/^Example/#Example/' "$conf"
		echo "Enabled $conf (commented out the Example line)"
	fi
done

unit=""
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
	for u in clamav-freshclam.service freshclam.service freshclam.timer; do
		if systemctl cat "$u" >/dev/null 2>&1; then unit=$u; break; fi
	done
fi
openrc=false
if [ -z "$unit" ] && command -v rc-service >/dev/null 2>&1 && [ -e /etc/init.d/freshclam ]; then
	openrc=true
fi

# Load the signatures once in the foreground so the result is known now.
if [ -n "$unit" ]; then systemctl stop "$unit" >/dev/null 2>&1; fi
if $openrc; then rc-service freshclam stop >/dev/null 2>&1; fi
out=$(freshclam --stdout 2>&1)
frc=$?
case $frc in
0 | 1) echo "Signatures: $(echo "$out" | sed -n 's/.*\(daily\.c[lv]d.*\)/\1/p' | tail -n 1)" ;;
*)
	echo "freshclam failed (exit $frc):"
	echo "$out" | grep -iE 'error|warning' | tail -n 5
	;;
esac

if [ -n "$unit" ]; then
	if systemctl enable --now "$unit" >/dev/null 2>&1; then
		echo "Automatic updates: $unit enabled and running"
	else
		echo "Could not enable $unit"
		frc=1
	fi
elif $openrc; then
	rc-update add freshclam default >/dev/null 2>&1
	if rc-service freshclam start >/dev/null 2>&1; then
		echo "Automatic updates: OpenRC service freshclam enabled and running"
	else
		echo "Could not start the OpenRC service freshclam"
		frc=1
	fi
else
	echo "Automatic updates: no running systemd or OpenRC found, schedule the signature update script instead"
fi

case $frc in
0 | 1) exit 0 ;;
*) exit 1 ;;
esac
