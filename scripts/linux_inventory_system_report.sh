#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Prints a system summary: distribution, kernel, uptime, virtualization, CPU, memory, disks, addresses, routes.
# Variables: none
# Exit: 0 always (missing details are shown as unknown)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u
command -v awk >/dev/null 2>&1 || { echo "awk is not installed (install gawk or mawk)"; exit 3; }

osr() { sed -n "s/^$1=//p" /etc/os-release /usr/lib/os-release 2>/dev/null | head -n 1 | tr -d '"'; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "Host:           $(hostname 2>/dev/null || cat /proc/sys/kernel/hostname)"
echo "Distribution:   $(osr PRETTY_NAME)"
echo "Kernel:         $(uname -sr) $(uname -m)"
if [ -r /proc/uptime ]; then
  read -r up _ </proc/uptime
  echo "Uptime:         $((${up%%.*} / 86400)) days $((${up%%.*} % 86400 / 3600)) h"
fi

virt=''
have systemd-detect-virt && virt=$(systemd-detect-virt 2>/dev/null)
if [ -z "$virt" ] || [ "$virt" = none ]; then
  if [ -e /.dockerenv ]; then virt=docker
  elif grep -qs 'container=' /proc/1/environ 2>/dev/null; then virt=container
  elif grep -qs ' hypervisor' /proc/cpuinfo 2>/dev/null; then virt="vm ($(cat /sys/class/dmi/id/sys_vendor 2>/dev/null))"
  else virt=none; fi
fi
echo "Virtualization: $virt"

cpu=$(sed -n 's/^model name[[:space:]]*: *//p' /proc/cpuinfo 2>/dev/null | head -n 1)
[ -n "$cpu" ] || cpu=$(sed -n 's/^\(Hardware\|Model\)[[:space:]]*: *//p' /proc/cpuinfo 2>/dev/null | head -n 1)
echo "CPU:            ${cpu:-unknown}, $(grep -c '^processor' /proc/cpuinfo 2>/dev/null) logical"
mt=$(awk '$1 == "MemTotal:" {print int($2 / 1024)}' /proc/meminfo)
ma=$(awk '$1 == "MemAvailable:" {print int($2 / 1024)}' /proc/meminfo)
st=$(awk '$1 == "SwapTotal:" {print int($2 / 1024)}' /proc/meminfo)
echo "Memory:         ${mt:-?} MB total, ${ma:-?} MB available, swap ${st:-0} MB"

pm=''
for p in apt-get dnf yum zypper pacman apk; do have $p && { pm="$pm $p"; }; done
echo "Package mgr:   ${pm:- none found}"
if [ -d /run/systemd/system ]; then sm=systemd
elif [ -d /run/openrc ] || have rc-service; then sm=OpenRC
elif [ "$(cat /proc/1/comm 2>/dev/null)" = runit ]; then sm=runit
else sm="other ($(cat /proc/1/comm 2>/dev/null))"; fi
echo "Service mgr:    $sm"

rb=no
if [ -e /var/run/reboot-required ]; then rb=yes
elif have needs-restarting; then needs-restarting -r >/dev/null 2>&1; [ $? -eq 1 ] && rb=yes
elif have zypper; then zypper -q needs-rebooting >/dev/null 2>&1; [ $? -eq 102 ] && rb=yes
fi
echo "Reboot pending: $rb"

echo
echo "Disks:"
if have lsblk; then lsblk -d -n -o NAME,SIZE,TYPE,MODEL 2>/dev/null | sed 's/^/  /'
else awk 'NR > 2 && $4 !~ /[0-9]$/ {printf "  %s %.1f GB\n", $4, $3 / 1048576}' /proc/partitions; fi
echo "Filesystems:"
df -P -k 2>/dev/null | awk 'NR > 1 && $1 ~ /^\// {printf "  %-28s %8.1f GB %4s used  %s\n", $1, $2 / 1048576, $5, $6}'

echo
echo "Addresses:"
if have ip; then ip -o addr show 2>/dev/null | awk '$3 ~ /^inet/ && $2 != "lo" {print "  " $2 " " $4}'
elif have ifconfig; then ifconfig 2>/dev/null | awk '/^[a-z]/ {i = $1} /inet addr|inet / {print "  " i " " $0}'
else echo "  unknown (no ip or ifconfig)"; fi
echo "Default route:"
if have ip; then ip route show default 2>/dev/null | sed 's/^/  /'
else awk 'NR > 1 && $2 == "00000000" {printf "  via %s dev %s (hex, little endian)\n", $3, $1}' /proc/net/route; fi
exit 0
