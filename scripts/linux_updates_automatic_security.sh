#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows, enables or disables automatic security updates (unattended-upgrades on apt, dnf-automatic on dnf).
# Variables: STATE (status, enable, disable; default status).
# Exit codes: 0 ok (status: enabled), 1 failed or status disabled, 3 bad input or unsupported package manager.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

st=${STATE:-status}
case $st in status | enable | disable) ;; *) echo "STATE must be status, enable or disable"; exit 3 ;; esac
sysd=
[ -d /run/systemd/system ] && sysd=1

if command -v apt-get >/dev/null 2>&1; then
  conf=/etc/apt/apt.conf.d/20auto-upgrades
  have() { dpkg -s unattended-upgrades 2>/dev/null | grep -q '^Status: install ok installed'; }
  val() { apt-config shell v APT::Periodic::Unattended-Upgrade 2>/dev/null | sed "s/^v='\(.*\)'/\1/"; }
  if [ "$st" = status ]; then
    # a disabled or masked apt-daily-upgrade.timer means unattended-upgrades never runs
    if have && [ "$(val)" = 1 ] && { [ -z "$sysd" ] || systemctl is-enabled apt-daily-upgrade.timer >/dev/null 2>&1; }; then echo "Automatic security updates: enabled (unattended-upgrades)"; exit 0; fi
    echo "Automatic security updates: disabled"
    exit 1
  fi
  if [ "$st" = enable ]; then
    have || { DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1; DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades >/dev/null 2>&1 || { echo "Could not install unattended-upgrades"; exit 1; }; }
    printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' >"$conf"
    [ -n "$sysd" ] && systemctl enable --now apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1
    [ "$(val)" = 1 ] && have && { echo "Automatic security updates enabled (unattended-upgrades, $conf)"; exit 0; }
    echo "Enabling did not take effect"
    exit 1
  fi
  if [ -f "$conf" ] || have; then
    printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "0";\n' >"$conf"
  fi
  [ "$(val)" = 1 ] && { echo "Could not disable, another apt.conf.d file sets it"; exit 1; }
  echo "Automatic security updates disabled"
  exit 0
fi

if command -v dnf >/dev/null 2>&1; then
  if dnf --version 2>/dev/null | head -1 | grep -q '^dnf5'; then pkg=dnf5-plugin-automatic timer=dnf5-automatic.timer
  else pkg=dnf-automatic timer=dnf-automatic-install.timer; fi
  timers="$timer dnf-automatic.timer"
  conf=/etc/dnf/automatic.conf
  # the -install timer always applies updates, the plain ones only with apply_updates = yes
  on() {
    [ -n "$sysd" ] || return 1
    for t in $timers; do
      systemctl is-enabled "$t" >/dev/null 2>&1 || continue
      [ "$t" = dnf-automatic-install.timer ] && return 0
      grep -Eq '^[[:space:]]*apply_updates[[:space:]]*=[[:space:]]*(yes|True|true)' "$conf" 2>/dev/null && return 0
    done
    return 1
  }
  if [ "$st" = status ]; then
    if on; then echo "Automatic security updates: enabled ($timer)"; exit 0; fi
    echo "Automatic security updates: disabled"
    exit 1
  fi
  if [ "$st" = enable ]; then
    [ -n "$sysd" ] || { echo "systemd is not running, cannot schedule $timer"; exit 3; }
    [ -f "$conf" ] || dnf -y install "$pkg" >/dev/null 2>&1 || { echo "Could not install $pkg"; exit 1; }
    command -v dnf-automatic >/dev/null 2>&1 || [ -f "$conf" ] || { echo "$pkg did not install"; exit 1; }
    [ -f "$conf" ] || printf '[commands]\n' >"$conf"
    for kv in "upgrade_type = security" "apply_updates = yes"; do
      k=${kv%% *}
      if grep -Eq "^[[:space:]]*${k}[[:space:]]*=" "$conf"; then sed -i "s/^[[:space:]]*${k}[[:space:]]*=.*/$kv/" "$conf"
      else sed -i "/^\[commands\]/a $kv" "$conf"; fi
    done
    systemctl enable --now "$timer" >/dev/null 2>&1
    on && { echo "Automatic security updates enabled ($timer, security only, $conf)"; exit 0; }
    echo "Enabling did not take effect"
    exit 1
  fi
  # shellcheck disable=SC2086
  [ -n "$sysd" ] && systemctl disable --now $timers >/dev/null 2>&1
  on && { echo "Could not disable $timers"; exit 1; }
  echo "Automatic security updates disabled"
  exit 0
fi

for pm in zypper pacman apk; do
  command -v "$pm" >/dev/null 2>&1 || continue
  case $pm in
  zypper) why="openSUSE has no supported unattended security update tool (use a transactional-update timer or a maintenance script)" ;;
  pacman) why="Arch must not update unattended: partial or blind upgrades break the system" ;;
  apk) why="Alpine has no unattended upgrade tool; run apk upgrade from a scheduled task" ;;
  esac
  echo "Not supported with $pm: $why"
  exit 3
done
echo "No supported package manager found"
exit 3
