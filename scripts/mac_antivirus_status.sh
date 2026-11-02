#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks the built-in macOS malware protection: Gatekeeper, System Integrity Protection and XProtect age;
#   lists active antivirus system extensions.
# Variables: WARN_DAYS (45) XProtect older than this many days is a warning.
# Exit: 0 ok, 1 Gatekeeper or SIP off or XProtect missing, 2 XProtect old, 3 bad input or unsupported system.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

warn_days=${WARN_DAYS:-45}
case "$warn_days" in
'' | *[!0-9]*) echo "WARN_DAYS must be a whole number"; exit 3 ;;
esac
major=$(sw_vers -productVersion | cut -d. -f1)
[ "$major" -ge 13 ] 2>/dev/null || { echo "macOS 13 or later is required"; exit 3; }

gk=$(spctl --status 2>&1)
sip=$(csrutil status 2>&1)

# macOS 15 and later keep the active XProtect bundle under /var/protected.
xp_version=""
xp_mtime=0
for b in /private/var/protected/xprotect/XProtect.bundle /Library/Apple/System/Library/CoreServices/XProtect.bundle; do
	plist="$b/Contents/Info.plist"
	[ -f "$plist" ] || continue
	t=$(stat -f %m "$plist" 2>/dev/null || echo 0)
	if [ "$t" -gt "$xp_mtime" ]; then
		xp_mtime=$t
		xp_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null)
	fi
done
if command -v xprotect >/dev/null 2>&1; then
	v=$(xprotect version 2>/dev/null | head -n 1)
	[ -n "$v" ] && xp_version=$v
fi

rc=0
verdict=""
case "$gk" in
*"assessments enabled"*) ;;
*) rc=1; verdict="Gatekeeper is off" ;;
esac
case "$sip" in
*"status: enabled"*) ;;
*) rc=1; verdict="${verdict:+$verdict, }SIP is not fully enabled" ;;
esac
age=-1
if [ "$xp_mtime" -eq 0 ]; then
	rc=1
	verdict="${verdict:+$verdict, }XProtect not found"
else
	age=$((($(date +%s) - xp_mtime) / 86400))
	if [ "$age" -gt "$warn_days" ] && [ $rc -eq 0 ]; then
		rc=2
		verdict="XProtect is $age days old"
	fi
fi

case $rc in
0) echo "OK: Gatekeeper on, SIP on, XProtect $xp_version ($age days old)" ;;
1) echo "FAIL: $verdict" ;;
2) echo "WARNING: $verdict" ;;
esac
echo "Gatekeeper: $gk"
echo "$sip" | head -n 1
echo "XProtect: ${xp_version:-unknown}, updated $([ "$xp_mtime" -gt 0 ] && date -r "$xp_mtime" '+%Y-%m-%d')"
ext=$(systemextensionsctl list 2>/dev/null | grep 'activated enabled' | grep -iE 'eset|bitdefender|kaspersky|avast|avg|malwarebytes|sophos|symantec|norton|wdav|intego|mcafee|trendmicro|f-secure|withsecure')
if [ -n "$ext" ]; then
	echo "Antivirus system extensions:"
	echo "$ext" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /\./ && $i !~ /^[0-9.()]+$/) { print "  " $i; break } }'
else
	echo "Antivirus system extensions: none active"
fi
exit $rc
