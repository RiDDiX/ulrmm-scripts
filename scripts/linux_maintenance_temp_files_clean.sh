#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Deletes files in /tmp and /var/tmp not modified, read or changed for MAX_AGE_DAYS days; open files are kept.
# Variables: DRY_RUN (default true, only lists), MAX_AGE_DAYS (default 10).
# Exit codes: 0 done, 1 cleaning failed, 3 bad input.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

dry=${DRY_RUN:-true}
case $dry in true) ;; false) dry= ;; *) echo "DRY_RUN must be true or false"; exit 3 ;; esac
age=${MAX_AGE_DAYS:-10}
case $age in '' | *[!0-9]*) echo "MAX_AGE_DAYS must be a whole number"; exit 3 ;; esac
[ ${#age} -le 5 ] && [ "$age" -ge 1 ] && [ "$age" -le 36500 ] || { echo "MAX_AGE_DAYS must be 1-36500"; exit 3; }

# files a running process holds open are kept
# shellcheck disable=SC2012
keep=$(ls -l /proc/[0-9]*/fd 2>/dev/null | awk -F' -> ' 'NF > 1 && $2 ~ /^\/(var\/)?tmp\// {print $2}' | sort -u |
  while IFS= read -r f; do i=$(stat -c %i "$f" 2>/dev/null) && printf '! -inum %s ' "$i"; done)
used_kb() { df -Pk /tmp /var/tmp 2>/dev/null | awk 'NR>1 {s+=$3} END {print s+0}'; }
# shellcheck disable=SC2086
list() {
  for d in /tmp /var/tmp; do
    [ -d "$d" ] && [ ! -L "$d" ] || continue
    find "$d" -xdev -mindepth 1 \
      \( -name 'systemd-private-*' -o -name '.X11-unix' -o -name '.ICE-unix' -o -name '.font-unix' \
      -o -name '.XIM-unix' -o -name '.Test-unix' -o -name '*ulrmm*' -o -name 'tmux-*' \) -prune -o \
      \( -type f -o -type l \) -mtime "+$age" -atime "+$age" -ctime "+$age" $keep "$@"
  done
}

tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT
list -print >"$tmp"
n=$(wc -l <"$tmp")
if [ -n "$dry" ]; then
  echo "Dry run: $n file(s) older than $age days"
  head -50 "$tmp"
  exit 0
fi
before=$(used_kb)
# -execdir works from the file's directory, so a directory swapped for a symlink cannot redirect rm
# (busybox find has no -execdir)
if find / -maxdepth 0 -execdir true {} + >/dev/null 2>&1; then
  list -execdir rm -f -- {} + 2>/dev/null
else
  list -exec rm -f -- {} + 2>/dev/null
fi
for d in /tmp /var/tmp; do
  [ -d "$d" ] && [ ! -L "$d" ] && find "$d" -xdev -mindepth 1 -type d -empty -mtime "+$age" \
    ! -path '*/systemd-private-*' ! -path '*/.*-unix*' ! -path '*ulrmm*' ! -path '*/tmux-*' -delete 2>/dev/null
done
after=$(used_kb)
echo "Removed $n file(s) older than $age days, freed about $(((before - after) / 1024)) MB"
exit 0
