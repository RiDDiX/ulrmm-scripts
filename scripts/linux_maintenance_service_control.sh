#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows, starts, stops, restarts, enables or disables one service (systemd or OpenRC); agent and network services are guarded.
# Variables: SERVICE (required, unit or init script name), ACTION (status, start, stop, restart, enable, disable; default status).
# Exit codes: 0 ok (status: running), 1 failed or not running, 3 bad input or no service manager.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

svc=${SERVICE:-}
act=${ACTION:-status}
[ -n "$svc" ] || { echo "SERVICE is required"; exit 3; }
case $svc in
-* | *[!A-Za-z0-9_.@:-]*) echo "SERVICE has characters that are not allowed"; exit 3 ;;
esac
[ ${#svc} -le 100 ] || { echo "SERVICE is too long"; exit 3; }
case $act in status | start | stop | restart | enable | disable) ;; *) echo "ACTION must be status, start, stop, restart, enable or disable"; exit 3 ;; esac
case $svc in
ulrmm-agent* | ulrmm-mesh* | meshagent* | 'Mesh Agent')
  case $act in stop | restart | disable)
    echo "Refusing to $act $svc: it would cut the management connection"
    exit 3
    ;;
  esac
  ;;
NetworkManager | NetworkManager.service | systemd-networkd | systemd-networkd.service | networking | networking.service | network | network.service | wicked | wicked.service)
  case $act in stop | disable)
    echo "Refusing to $act $svc: the machine would lose its network and the management connection (use restart)"
    exit 3
    ;;
  esac
  ;;
esac

if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
  systemctl cat "$svc" >/dev/null 2>&1 || { echo "Service $svc not found"; exit 1; }
  case $act in
  status) ;;
  start | stop | restart) systemctl "$act" "$svc" >/dev/null 2>&1 || { echo "systemctl $act $svc failed"; exit 1; } ;;
  enable | disable)
    systemctl "$act" "$svc" >/dev/null 2>&1 || { echo "systemctl $act $svc failed"; exit 1; }
    ;;
  esac
  active=$(systemctl is-active "$svc" 2>&1)
  enabled=$(systemctl is-enabled "$svc" 2>&1 | head -1)
  echo "$svc: $active, $enabled"
  case $act in
  status | restart | start) [ "$active" = active ] || exit 1 ;;
  stop) [ "$active" != active ] || exit 1 ;;
  enable) case $enabled in enabled | static | alias | indirect) ;; *) exit 1 ;; esac ;;
  disable) [ "$enabled" != enabled ] || exit 1 ;;
  esac
  exit 0
elif command -v rc-service >/dev/null 2>&1; then
  [ -f "/etc/init.d/$svc" ] || { echo "Service $svc not found"; exit 1; }
  case $act in
  status) ;;
  start | restart) rc-service "$svc" "$act" >/dev/null 2>&1 || { echo "rc-service $svc $act failed"; exit 1; } ;;
  stop) rc-service "$svc" stop >/dev/null 2>&1 ;;
  enable) rc-update add "$svc" default >/dev/null 2>&1 || { echo "rc-update add failed"; exit 1; } ;;
  disable) rc-update del "$svc" default >/dev/null 2>&1 || true ;;
  esac
  state=$(rc-service "$svc" status 2>&1 | head -1 | sed 's/^[ *]*status: *//')
  if rc-update show default 2>/dev/null | awk '{print $1}' | grep -qx "$svc"; then en=enabled; else en=disabled; fi
  echo "$svc: $state, $en"
  case $act in
  status | start | restart) rc-service "$svc" status >/dev/null 2>&1 || exit 1 ;;
  stop) rc-service "$svc" status >/dev/null 2>&1 && exit 1 ;;
  enable) [ "$en" = enabled ] || exit 1 ;;
  disable) [ "$en" = disabled ] || exit 1 ;;
  esac
  exit 0
fi
echo "Neither systemd nor OpenRC found"
exit 3
