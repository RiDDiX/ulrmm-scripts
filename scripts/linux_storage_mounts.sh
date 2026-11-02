#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks that mount points are mounted, writable (unless marked :ro) and not hung.
# Variables: MOUNTS (one mount point per line, optional :ro suffix for read-only mounts, required)
# Exit: 0 all fine, 1 missing, wrong mode or unresponsive mount, 3 bad input
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

LIST=$(printf '%s\n' "${MOUNTS:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d')
[ -n "$LIST" ] || { echo "MOUNTS is required"; exit 3; }
for m in $LIST; do
  p=${m%:ro}
  case $p in /*) ;; *) echo "Mount point must be an absolute path: $m"; exit 3 ;; esac
  case $p in *[!A-Za-z0-9/._+@-]*) echo "Mount point has characters that are not allowed: $m"; exit 3 ;; esac
done
[ -r /proc/mounts ] || { echo "Unsupported: /proc/mounts not readable"; exit 3; }

probe() {
  ( if [ "$2" = rw ]; then t=$(mktemp "$1/.ulrmm-probe.XXXXXX") && rm -f "$t"; else ls "$1" >/dev/null; fi ) >/dev/null 2>&1 &
  pid=$!
  i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$((i + 1))
    [ $i -gt 10 ] && return 9
    sleep 1
  done
  wait "$pid"
}

nl='
'
bad='' n=0
for m in $LIST; do
  n=$((n + 1))
  mp=${m%:ro}
  want=rw
  [ "$mp" != "$m" ] && want=ro
  mp=$(printf '%s' "$mp" | sed 's|//*|/|g;s|\(.\)/$|\1|')
  line=$(awk -v m="$mp" '{p = $2; gsub(/\\040/, " ", p); if (p == m) l = $0} END {print l}' /proc/mounts)
  if [ -z "$line" ]; then bad="$bad$mp: not mounted$nl"; continue; fi
  opts=$(printf '%s\n' "$line" | awk '{print $4}')
  fs=$(printf '%s\n' "$line" | awk '{print $3}')
  case ",$opts," in *,ro,*) cur=ro ;; *) cur=rw ;; esac
  if [ "$want" = rw ] && [ "$cur" = ro ]; then bad="$bad$mp: mounted read-only ($fs)$nl"; continue; fi
  if [ "$want" = ro ] && [ "$cur" = rw ]; then bad="$bad$mp: expected read-only but mounted read-write ($fs)$nl"; continue; fi
  probe "$mp" "$want"
  case $? in
  0) ;;
  9) bad="$bad$mp: no answer within 10 seconds, hung mount? ($fs)$nl" ;;
  *) bad="$bad$mp: $([ "$want" = rw ] && echo 'write test failed' || echo 'not readable') ($fs)$nl" ;;
  esac
done
if [ -z "$bad" ]; then
  echo "OK: $n mount points mounted and responding"
  exit 0
fi
echo "ERROR: $(printf '%s' "$bad" | wc -l) of $n mount points have problems"
printf '%s' "$bad"
exit 1
