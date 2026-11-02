#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Scans paths on demand with clamscan and prints a summary with the infected files. Changes nothing.
# Variables: PATHS (/home,/root,/tmp,/var/tmp) comma or newline separated, EXCLUDE ("") paths to skip,
#   MAX_FILESIZE_MB (100) larger files are skipped.
# Exit: 0 clean, 1 infection found, 2 scan finished with errors, 3 bad input or ClamAV missing.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

paths=${PATHS:-/home,/root,/tmp,/var/tmp}
exclude=${EXCLUDE:-}
max_mb=${MAX_FILESIZE_MB:-100}

case "$max_mb" in
'' | *[!0-9]*) echo "MAX_FILESIZE_MB must be a whole number"; exit 3 ;;
esac
[ "$max_mb" -ge 1 ] && [ "$max_mb" -le 4000 ] || { echo "MAX_FILESIZE_MB must be 1-4000"; exit 3; }

command -v clamscan >/dev/null 2>&1 || {
	echo "clamscan not found, run the ClamAV install script first (package clamav)"
	exit 3
}

nl='
'
# Build the argument list in "$@"; clamscan takes the exclusions as regular expressions.
set --
add_excl() {
	case "$1" in
	/*) ;;
	*) echo "Exclusion is not an absolute path: $1"; exit 3 ;;
	esac
	re=$(printf '%s' "${1%/}" | sed 's/[][\.*^$+?(){}|]/\\&/g')
	excl_args="$excl_args${nl}--exclude-dir=^$re(/|\$)${nl}--exclude=^$re\$"
}
excl_args=""
for p in /proc /sys /dev /run; do add_excl "$p"; done

old_ifs=$IFS
IFS=",$nl"
for p in $exclude; do
	p=$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
	[ -n "$p" ] && add_excl "$p"
done
targets=0
for p in $paths; do
	p=$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
	[ -n "$p" ] || continue
	case "$p" in
	/*) ;;
	*) echo "Path is not absolute: $p"; exit 3 ;;
	esac
	if [ -e "$p" ]; then
		set -- "$@" "$p"
		targets=$((targets + 1))
	else
		echo "Skipped, does not exist: $p"
	fi
done
IFS=$nl
for a in $excl_args; do set -- "$@" "$a"; done
IFS=$old_ifs

[ "$targets" -gt 0 ] || { echo "None of the paths exist: $paths"; exit 3; }

log=$(mktemp) || exit 1
trap 'rm -f "$log"' EXIT

# clamscan accepts at most 4000M for both limits.
scan_mb=$((max_mb * 4))
[ "$scan_mb" -gt 4000 ] && scan_mb=4000
prio=""
command -v nice >/dev/null 2>&1 && prio="nice -n 10"
# shellcheck disable=SC2086
$prio clamscan --recursive --infected --stdout --max-filesize="${max_mb}M" --max-scansize="${scan_mb}M" "$@" >"$log" 2>&1
rc=$?

infected=$(grep -c ' FOUND$' "$log")
scanned=$(sed -n 's/^Scanned files: //p' "$log")
errors=$(sed -n 's/^Total errors: //p' "$log")
case $rc in
0) echo "CLEAN: ${scanned:-0} files scanned, no infection found" ;;
1) echo "INFECTED: $infected file(s) found in ${scanned:-0} scanned files" ;;
*) echo "ERROR: clamscan exit $rc, ${errors:-unknown} error(s), ${scanned:-0} files scanned" ;;
esac
grep ' FOUND$' "$log" | head -n 50
[ "$infected" -gt 50 ] && echo "... $((infected - 50)) more"
if [ $rc -gt 1 ]; then
	grep -E '^(ERROR|WARNING|LibClamAV Error)' "$log" | sort | uniq | head -n 10
fi
sed -n -E '/^(Known viruses|Engine version|Data scanned|Time):/p' "$log"

case $rc in
0) exit 0 ;;
1) exit 1 ;;
*) exit 2 ;;
esac
