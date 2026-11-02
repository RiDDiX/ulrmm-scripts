#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Installs a macOS antivirus package after checking its Developer ID Installer Team ID and Gatekeeper assessment.
# Variables: PRODUCT (required) defender, malwarebytes, avast, avg, eset-endpoint, clamav;
#   INSTALLER_URL ("" = vendor default, https only); ALLOW_EXISTING (false).
# Exit: 0 installed or already installed, 1 failed, 3 bad input, unsupported system or another antivirus present.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

result() {
	echo "RESULT: $2"
	exit "$1"
}

product=$(printf '%s' "${PRODUCT:-}" | tr '[:upper:]' '[:lower:]')
url_override=${INSTALLER_URL:-}
allow_existing=${ALLOW_EXISTING:-false}

# team: Apple Team ID of the installer signature, receipt: pkgutil id that proves the install,
# own: system extension prefix of the product itself.
case "$product" in
defender)
	name="Microsoft Defender for Endpoint"; team=UBF8T346G9; own='com\.microsoft\.wdav'
	url='https://go.microsoft.com/fwlink/?linkid=2097502'; receipt='^com\.microsoft\.wdav$'
	approve="onboarding profile WindowsDefenderATPOnboarding.mobileconfig, system extensions com.microsoft.wdav.epsext and .netext, Full Disk Access" ;;
malwarebytes)
	name="Malwarebytes for Mac"; team=GVZRY6KDKR; own='com\.malwarebytes'
	url='https://downloads.malwarebytes.com/file/mb-mac'; receipt='^com\.malwarebytes\.mbam\.installer$'
	approve="Full Disk Access for the real-time protection daemon, system extension for web protection" ;;
avast)
	name="Avast Security"; team=6H4HRTU5E3; own='com\.avast'
	url='https://www.avast.com/en-us/download-thank-you.php?product=MAC-FREE-ONLINE&direct=1'; receipt='^com\.avast\.avast$'
	approve="system extension com.avast.Antivirus.SystemExtension, Full Disk Access, content filter" ;;
avg)
	name="AVG AntiVirus"; team=XSJ59WMJBM; own='com\.avg'
	url='https://bits.avcdn.net/productfamily_ANTIVIRUS/insttype_FREE/platform_MAC_AVG/installertype_ONLINE/build_RELEASE'
	receipt='^com\.avg\.avg$'; approve="system extension and Full Disk Access" ;;
eset-endpoint)
	name="ESET Endpoint Security"; team=P8DQRXPVLP; own='com\.eset'
	url='https://download.eset.com/com/eset/apps/business/ees/mac/g2/latest/ees_osx.dmg'; receipt='^com\.eset\.'
	approve="system extensions com.eset.endpoint, com.eset.network, com.eset.firewall, Full Disk Access, license in the product or ESET PROTECT" ;;
clamav)
	name="ClamAV"; team=DE8Y96K9QP; own='-'; url=''; receipt='^com\.cisco\.ClamAV\.programs$'
	approve="Full Disk Access for the process that runs clamscan, otherwise protected folders are skipped" ;;
*) result 3 "failed PRODUCT must be one of: defender, malwarebytes, avast, avg, eset-endpoint, clamav" ;;
esac
case "$allow_existing" in true | false) ;; *) result 3 "failed ALLOW_EXISTING must be true or false" ;; esac
if [ -n "$url_override" ]; then
	case "$url_override" in
	https://*) ;;
	*) result 3 "failed INSTALLER_URL must start with https://" ;;
	esac
	case "$url_override" in *[[:space:]\"\'\`]*) result 3 "failed INSTALLER_URL contains spaces or quotes" ;; esac
	url=$url_override
fi

[ "$(id -u)" -eq 0 ] || result 3 "failed must run as root"
major=$(sw_vers -productVersion | cut -d. -f1)
[ "$major" -ge 13 ] 2>/dev/null || result 3 "failed macOS 13 or later is required"

have=$(pkgutil --pkgs | grep -E "$receipt" | head -n 1)
if [ -n "$have" ]; then
	v=$(pkgutil --pkg-info "$have" | sed -n 's/^version: //p')
	echo "Already installed: $have $v"
	result 0 "installed $name $v"
fi

if [ "$product" != clamav ]; then
	others=$(systemextensionsctl list 2>/dev/null | grep 'activated enabled' |
		grep -iE 'com\.(eset|bitdefender|kaspersky|avast|avg|malwarebytes|sophos|symantec|norton|microsoft\.wdav|intego|mcafee|trendmicro|f-secure|withsecure)' |
		grep -viE "$own" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^com\./) { print $i; break } }' | sort -u | tr '\n' ' ')
	if [ -n "$others" ]; then
		[ "$allow_existing" = true ] || result 3 "failed another antivirus is active: $others- remove it first or set ALLOW_EXISTING"
		echo "Continuing although another antivirus is active: $others"
	fi
fi

work=$(mktemp -d /private/tmp/ulrmm-av.XXXXXX) || result 1 "failed cannot create a working directory"
mnt="$work/mnt"
trap '[ -d "$mnt" ] && hdiutil detach -quiet -force "$mnt" >/dev/null 2>&1; rm -rf "$work"' EXIT

if [ -z "$url" ]; then
	url=$(curl -fsSL --proto '=https' --tlsv1.2 --max-time 60 https://api.github.com/repos/Cisco-Talos/clamav/releases/latest |
		sed -n 's/.*"browser_download_url": *"\(https:[^"]*macos\.universal\.pkg\)".*/\1/p' | head -n 1)
	[ -n "$url" ] || result 1 "failed cannot find the latest ClamAV macOS package on GitHub"
fi

echo "Downloading $name from $(echo "$url" | cut -d/ -f3)"
curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 --max-time 3600 -A 'Mozilla/5.0' -o "$work/download" "$url" ||
	result 1 "failed download"

pkg="$work/download"
if [ "$(head -c 4 "$work/download")" != "xar!" ]; then
	mkdir "$mnt"
	# Disk images with a license agreement wait for an answer on stdin.
	yes | hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$work/download" >/dev/null 2>&1 ||
		result 1 "failed the download is neither a package nor a disk image"
	pkg=$(find "$mnt" -maxdepth 3 -name '*.pkg' 2>/dev/null | head -n 1)
	[ -n "$pkg" ] || result 1 "failed no installer package in the disk image"
fi

sig=$(pkgutil --check-signature "$pkg" 2>&1)
signer=$(echo "$sig" | sed -n 's/^ *1\. //p' | head -n 1)
case "$sig" in
*"signed by a developer certificate issued by Apple for distribution"*) ;;
*) result 1 "failed package is not signed with a Developer ID certificate, not installed" ;;
esac
case "$signer" in
"Developer ID Installer: "*"($team)") ;;
*) result 1 "failed signed by '$signer', expected Team ID $team, not installed" ;;
esac
spctl --assess --type install "$pkg" >/dev/null 2>&1 || result 1 "failed Gatekeeper rejects the package, not installed"
echo "Signature valid: $signer"

out=$(installer -pkg "$pkg" -target / 2>&1)
irc=$?
echo "$out" | tail -n 3
[ $irc -eq 0 ] || result 1 "failed installer exit code $irc"

have=$(pkgutil --pkgs | grep -E "$receipt" | head -n 1)
[ -n "$have" ] || result 1 "failed installer finished but no receipt matches $receipt"
v=$(pkgutil --pkg-info "$have" | sed -n 's/^version: //p')

if [ "$product" = clamav ]; then
	conf=/usr/local/clamav/etc/freshclam.conf
	if [ ! -f "$conf" ] && [ -f "$conf.sample" ]; then
		sed 's/^Example/#Example/' "$conf.sample" >"$conf" && echo "Created $conf; run freshclam once before the first scan"
	fi
fi
echo "Needs approval by the user or an MDM profile (root cannot grant it): $approve"
if [ "$product" != clamav ]; then
	state=$(systemextensionsctl list 2>/dev/null | grep "$team" | awk -F'\t' '{ print $4, $NF }')
	[ -n "$state" ] && echo "System extensions now: $state"
fi
result 0 "installed $name $v"
