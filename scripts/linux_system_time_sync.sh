#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Makes sure time synchronisation runs (systemd-timesyncd or chrony); installs chrony only when asked.
# Variables: INSTALL (default false, install chrony when no time service exists).
# Exit codes: 0 time sync running, 1 failed, 3 bad input or no time service and INSTALL is false.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

inst=${INSTALL:-false}
case $inst in true | false) ;; *) echo "INSTALL must be true or false"; exit 3 ;; esac
svc=
if [ -d /run/systemd/system ]; then
  for u in chrony chronyd systemd-timesyncd ntpsec ntp ntpd; do
    systemctl cat "$u" >/dev/null 2>&1 && svc=$u && break
  done
  if [ -z "$svc" ] && [ "$inst" = true ]; then
    export DEBIAN_FRONTEND=noninteractive
    if command -v apt-get >/dev/null 2>&1; then apt-get update >/dev/null 2>&1; apt-get install -y chrony >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then dnf -y install chrony >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then yum -y install chrony >/dev/null 2>&1
    elif command -v zypper >/dev/null 2>&1; then zypper -n install chrony >/dev/null 2>&1
    elif command -v pacman >/dev/null 2>&1; then pacman -S --needed --noconfirm chrony >/dev/null 2>&1 || echo "pacman failed; if the package databases are stale, run a full upgrade (pacman -Syu) first"
    fi
    for u in chrony chronyd; do systemctl cat "$u" >/dev/null 2>&1 && svc=$u && break; done
  fi
  [ -n "$svc" ] || { echo "No time service installed; set INSTALL to true to install chrony"; exit 3; }
  systemctl enable "$svc" >/dev/null 2>&1
  systemctl start "$svc" >/dev/null 2>&1
  [ "$svc" = systemd-timesyncd ] && timedatectl set-ntp true >/dev/null 2>&1
  if ! systemctl is-active "$svc" >/dev/null 2>&1; then
    if [ "$(systemctl show "$svc" -p ConditionResult --value 2>/dev/null)" = no ]; then
      echo "$svc is skipped here by its unit conditions (for example inside a container)"
      exit 3
    fi
    echo "$svc is not running"
    exit 1
  fi
elif command -v rc-service >/dev/null 2>&1; then
  for u in chronyd ntpd; do [ -f "/etc/init.d/$u" ] && svc=$u && break; done
  if [ -z "$svc" ] && [ "$inst" = true ] && command -v apk >/dev/null 2>&1; then
    apk add chrony >/dev/null 2>&1
    [ -f /etc/init.d/chronyd ] && svc=chronyd
  fi
  [ -n "$svc" ] || { echo "No time service installed; set INSTALL to true to install chrony"; exit 3; }
  rc-update add "$svc" default >/dev/null 2>&1
  rc-service "$svc" start >/dev/null 2>&1
  rc-service "$svc" status >/dev/null 2>&1 || { echo "$svc is not running"; exit 1; }
else
  echo "Neither systemd nor OpenRC found"
  exit 3
fi
echo "Time synchronisation running with $svc"
exit 0
