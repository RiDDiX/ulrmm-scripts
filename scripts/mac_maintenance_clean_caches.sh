#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Clean old caches and logs. DRY_RUN (true): only count. MAX_AGE_DAYS (30): files not modified for this long.
# Covers /Library/Caches, /Library/Logs, rotated archives in /var/log and the Caches and Logs folders of
# local users. Apple caches (com.apple.*) and app containers are never touched.
# Exit: 0 done or counted, 3 bad input, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

dry=${DRY_RUN:-true}
days=${MAX_AGE_DAYS:-30}

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }
case "$dry" in true | false) ;; *) echo "DRY_RUN must be true or false."; exit 3 ;; esac
case "$days" in '' | *[!0-9]*) echo "MAX_AGE_DAYS must be a whole number."; exit 3 ;; esac
[ "$days" -ge 1 ] && [ "$days" -le 3650 ] || { echo "MAX_AGE_DAYS must be 1-3650."; exit 3; }

total_files=0
total_bytes=0

# A user's folders are walked as that user, so a path swapped under the walk gains nothing.
owner=''
as_owner() {
  if [ -n "$owner" ]; then sudo -n -u "#$owner" "$@"; else "$@"; fi
}

# $1 root, remaining args: extra find tests
clean() {
  local root=$1 n b
  shift
  [ -d "$root" ] && [ ! -L "$root" ] || return 0
  set -- "$root" -xdev -type f -mtime "+$days" ! -path '*/com.apple.*' ! -path '*/Containers/*' "$@"
  b=$(as_owner find "$@" -exec stat -f '%z' {} + 2>/dev/null | awk '{ n++; s += $1 } END { printf "%d %d", n, s }')
  n=${b% *}
  b=${b#* }
  [ "${n:-0}" -gt 0 ] || return 0
  total_files=$((total_files + n))
  total_bytes=$((total_bytes + b))
  printf '%s: %s files, %s KB\n' "$root" "$n" "$((b / 1024))"
  [ "$dry" = true ] || as_owner find "$@" -delete 2>/dev/null
  return 0
}

clean /Library/Caches
clean /Library/Logs
clean /var/log \( -name '*.gz' -o -name '*.bz2' -o -name '*.[0-9]' \)
for home in /Users/*; do
  [ -d "$home" ] && [ ! -L "$home" ] && [ ! -L "$home/Library" ] || continue
  owner=$(stat -f '%u' "$home" 2>/dev/null) || continue
  case "$owner" in '' | 0 | *[!0-9]*) continue ;; esac
  clean "$home/Library/Caches"
  clean "$home/Library/Logs"
done
owner=''

mode="Removed"
[ "$dry" = true ] && mode="Would remove (dry run)"
echo "$mode $total_files files, $((total_bytes / 1048576)) MB older than $days days."
echo "Folders protected by privacy rules may be skipped when the agent lacks Full Disk Access."
exit 0
