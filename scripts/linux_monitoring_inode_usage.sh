#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks inode usage on local filesystems against warning and error thresholds.
# Variables: WARN_PERCENT (85), ERROR_PERCENT (95), EXCLUDE (mount points, comma or line separated, optional)
# Exit: 0 ok, 1 error threshold reached, 2 warning threshold reached, 3 bad input or unsupported system
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

int() {
  case $2 in '' | *[!0-9]*) echo "$1 must be a whole number"; exit 3 ;; esac
  { [ "${#2}" -le 3 ] && [ "$2" -ge 1 ] && [ "$2" -le 100 ]; } || { echo "$1 must be between 1 and 100"; exit 3; }
}
WARN=${WARN_PERCENT:-85}
ERR=${ERROR_PERCENT:-95}
int WARN_PERCENT "$WARN"
int ERROR_PERCENT "$ERR"
[ "$WARN" -lt "$ERR" ] || { echo "WARN_PERCENT must be lower than ERROR_PERCENT"; exit 3; }
EXC=$(printf '%s\n' "${EXCLUDE:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d')
case $(printf %s "$EXC" | tr -d "\n") in *[!A-Za-z0-9/._+@-]*) echo "EXCLUDE has characters that are not allowed in a mount point"; exit 3 ;; esac
[ -r /proc/mounts ] || { echo "Unsupported: /proc/mounts not readable"; exit 3; }

nl='
'
seen='|' detail='' worst=0 n=0 status=0 bad=''
while read -r dev mp fs _; do
  case $fs in ext2 | ext3 | ext4 | xfs | f2fs | jfs | reiserfs | ufs) ;; *) continue ;; esac
  case $seen in *"|$dev|"*) continue ;; esac
  seen="$seen$dev|"
  mp=$(printf '%b' "$mp")
  printf '%s\n' "$EXC" | grep -qxF -- "$mp" && continue
  line=$(df -P -i "$mp" 2>/dev/null | tail -n 1)
  pct=''
  read -r _ _ _ _ pct _ <<EOT
$line
EOT
  pct=${pct%\%}
  case $pct in '' | *[!0-9]*) continue ;; esac
  n=$((n + 1))
  [ "$pct" -gt "$worst" ] && worst=$pct
  mark=ok
  if [ "$pct" -ge "$ERR" ]; then mark=ERROR; status=1
  elif [ "$pct" -ge "$WARN" ]; then mark=WARN; [ $status -eq 0 ] && status=2; fi
  [ $mark != ok ] && bad="$bad $mp:$pct%"
  detail="$detail$(printf '%-5s %3s%%  %s (%s, %s)' "$mark" "$pct" "$mp" "$fs" "$dev")$nl"
done </proc/mounts

[ $n -gt 0 ] || { echo "No filesystems with inode accounting to check (btrfs, zfs and vfat have none)"; exit 3; }
case $status in
0) echo "OK: $n filesystems, highest inode use $worst%" ;;
1) echo "ERROR: inodes at or above $ERR%:$bad" ;;
2) echo "WARNING: inodes at or above $WARN%:$bad" ;;
esac
printf '%s' "$detail"
exit $status
