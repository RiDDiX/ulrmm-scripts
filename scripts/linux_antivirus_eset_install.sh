#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Installs ESET Endpoint Antivirus for Linux or ESET Server Security for Linux from the vendor .bin installer
#   after checking its sha256, then activates it when a license key is given.
# Variables: PRODUCT (endpoint-antivirus) endpoint-antivirus or server-security; INSTALLER_URL ("" = vendor default,
#   required for endpoint-antivirus, https only); INSTALLER_SHA256 (required); LICENSE_KEY ("").
# Exit: 0 installed or already installed, 1 failed, 3 bad input or unsupported system.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

product=${PRODUCT:-endpoint-antivirus}
url=${INSTALLER_URL:-}
sha=$(printf '%s' "${INSTALLER_SHA256:-}" | tr '[:upper:]' '[:lower:]')
key=${LICENSE_KEY:-}

case "$product" in
endpoint-antivirus) dir=/opt/eset/eea; name="ESET Endpoint Antivirus for Linux" ;;
server-security)
	dir=/opt/eset/efs; name="ESET Server Security for Linux"
	[ -n "$url" ] || url=https://download.eset.com/com/eset/apps/business/efs/linux/latest/efs.x86_64.bin
	;;
*) echo "PRODUCT must be endpoint-antivirus or server-security"; exit 3 ;;
esac
[ -n "$url" ] || { echo "INSTALLER_URL is required: ESET publishes the endpoint .bin only behind its download page"; exit 3; }
case "$url" in
https://*) ;;
*) echo "INSTALLER_URL must start with https://"; exit 3 ;;
esac
case "$url" in *[[:space:]\"\'\`]*) echo "INSTALLER_URL contains spaces or quotes"; exit 3 ;; esac
case "$sha" in
*[!0-9a-f]*) echo "INSTALLER_SHA256 must be 64 hex characters"; exit 3 ;;
esac
[ ${#sha} -eq 64 ] || { echo "INSTALLER_SHA256 must be 64 hex characters (sha256sum of the .bin)"; exit 3; }
case "$key" in
*[!A-Za-z0-9-]*) echo "LICENSE_KEY may only contain letters, digits and dashes"; exit 3 ;;
esac

[ "$(id -u)" -eq 0 ] || { echo "Must run as root"; exit 3; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum not found (package coreutils)"; exit 3; }
if command -v curl >/dev/null 2>&1; then
	fetch() { curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 --max-time 3600 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
	fetch() { wget -q --https-only -O "$2" "$1"; }
else
	echo "Neither curl nor wget found (install curl)"; exit 3
fi

if [ -x "$dir/sbin/lic" ]; then
	echo "Already installed: $name ($dir)"
else
	work=$(mktemp -d) || exit 1
	trap 'rm -rf "$work"' EXIT
	echo "Downloading $name from $(echo "$url" | cut -d/ -f3)"
	fetch "$url" "$work/installer.bin" || { echo "Download failed"; exit 1; }
	got=$(sha256sum "$work/installer.bin" | cut -d' ' -f1)
	if [ "$got" != "$sha" ]; then
		echo "sha256 mismatch, not run: got $got"
		exit 1
	fi
	echo "sha256 verified"
	# -y accepts the license agreement, -f skips the questions.
	out=$(sh "$work/installer.bin" -y -f 2>&1)
	rc=$?
	echo "$out" | tail -n 5
	if [ $rc -ne 0 ] || [ ! -x "$dir/sbin/lic" ]; then
		echo "Installation failed (exit $rc)"
		exit 1
	fi
	echo "Installed: $name"
fi

if [ -n "$key" ]; then
	if "$dir/sbin/lic" -k "$key" >/dev/null 2>&1; then
		echo "Activated with the given license key"
	else
		echo "Activation failed, check the key and the connection to ESET"
		exit 1
	fi
else
	echo "Not activated: set LICENSE_KEY, use ESET PROTECT or the web interface"
fi
exit 0
