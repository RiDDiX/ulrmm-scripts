#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Creates and activates a swap file and adds it to /etc/fstab; nothing changes when it already exists with that size.
# Variables: SIZE_MB (required, 64-1048576), SWAP_PATH (default /swapfile).
# Exit codes: 0 swap in place, 1 failed, 3 bad input or the file system cannot hold swap.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

size=${SIZE_MB:-}
sp=${SWAP_PATH:-/swapfile}
case $size in '' | *[!0-9]*) echo "SIZE_MB must be a whole number"; exit 3 ;; esac
[ ${#size} -le 7 ] && [ "$size" -ge 64 ] && [ "$size" -le 1048576 ] || { echo "SIZE_MB must be 64-1048576"; exit 3; }
case $sp in /*) ;; *) echo "SWAP_PATH must be an absolute path"; exit 3 ;; esac
case $sp in *..* | *//* | *[!A-Za-z0-9._/-]*) echo "SWAP_PATH has characters that are not allowed"; exit 3 ;; esac
dir=$(dirname "$sp")
[ -d "$dir" ] || { echo "Directory $dir does not exist"; exit 3; }
[ -L "$sp" ] && { echo "$sp is a symlink"; exit 3; }
for t in mkswap swapon; do command -v "$t" >/dev/null 2>&1 || { echo "$t not found: install util-linux"; exit 3; }; done

fs=$(stat -f -c %T "$dir" 2>/dev/null)
case $fs in
tmpfs | overlay* | nfs* | smb* | cifs | zfs | ramfs | fuse*) echo "A swap file cannot live on the $fs file system"; exit 3 ;;
btrfs) command -v chattr >/dev/null 2>&1 || { echo "btrfs needs chattr (e2fsprogs) to disable copy-on-write for the swap file"; exit 3; } ;;
esac
active() { awk -v p="$sp" -v kb=$((size * 1024)) 'NR>1 && $1==p && $3>=kb-64 && $3<=kb {f=1} END {exit !f}' /proc/swaps; }
bytes=$((size * 1048576))
if [ -e "$sp" ]; then
  [ -f "$sp" ] || { echo "$sp exists and is not a regular file"; exit 3; }
  have=$(stat -c %s "$sp" 2>/dev/null)
  if [ "$have" != "$bytes" ]; then echo "$sp exists with a different size ($((have / 1048576)) MB); remove it first"; exit 3; fi
  chmod 600 "$sp"
  created=
else
  avail=$(df -Pm "$dir" | awk 'NR==2 {print $4}')
  [ "${avail:-0}" -ge $((size + 256)) ] || { echo "Not enough free space on $dir: ${avail:-0} MB free, need $((size + 256)) MB"; exit 3; }
  : >"$sp" && chmod 600 "$sp" || exit 1
  created=1
  if [ "$fs" = btrfs ]; then chattr +C "$sp" >/dev/null 2>&1 || { rm -f "$sp"; echo "chattr +C failed"; exit 1; }; fi
  case $fs in ext4 | xfs) command -v fallocate >/dev/null 2>&1 && fallocate -l "${size}M" "$sp" >/dev/null 2>&1 ;; *) false ;; esac ||
    dd if=/dev/zero of="$sp" bs=1M count="$size" >/dev/null 2>&1 || { rm -f "$sp"; echo "Creating $sp failed"; exit 1; }
  chmod 600 "$sp"
  mkswap "$sp" >/dev/null 2>&1 || { rm -f "$sp"; echo "mkswap failed"; exit 1; }
fi
did=
if ! active; then
  if ! swapon "$sp" >/dev/null 2>&1; then
    [ -n "$created" ] && rm -f "$sp"
    echo "swapon failed (insufficient privileges, as in a container, or a file system without swap support)"
    exit 1
  fi
  did="activated"
fi
if ! awk -v p="$sp" '$1==p && $3=="swap" {f=1} END {exit !f}' /etc/fstab 2>/dev/null; then
  # a last line without newline would swallow the new entry
  [ -s /etc/fstab ] && [ -n "$(tail -c1 /etc/fstab)" ] && printf '\n' >>/etc/fstab
  printf '%s none swap sw 0 0\n' "$sp" >>/etc/fstab && did="${did:+$did, }fstab entry added"
fi
active || { echo "$sp is not active after the change"; exit 1; }
if [ -n "$did" ]; then echo "Swap file $sp (${size} MB): ${created:+created, }$did"; else echo "Swap file $sp (${size} MB) already in place"; fi
exit 0
