#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Installs OpenSSH server if missing, enables and starts it, and optionally opens the port in ufw or firewalld.
# Variables: OPEN_FIREWALL (default false).
# Exit codes: 0 sshd running, 1 failed, 3 bad input or unsupported system.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }

fw=${OPEN_FIREWALL:-false}
case $fw in true | false) ;; *) echo "OPEN_FIREWALL must be true or false"; exit 3 ;; esac
did=
if ! command -v sshd >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  if command -v apt-get >/dev/null 2>&1; then apt-get update >/dev/null 2>&1; apt-get install -y openssh-server >/dev/null 2>&1
  elif command -v dnf >/dev/null 2>&1; then dnf -y install openssh-server >/dev/null 2>&1
  elif command -v yum >/dev/null 2>&1; then yum -y install openssh-server >/dev/null 2>&1
  elif command -v zypper >/dev/null 2>&1; then zypper -n install openssh-server >/dev/null 2>&1 || zypper -n install openssh >/dev/null 2>&1
  elif command -v pacman >/dev/null 2>&1; then pacman -S --needed --noconfirm openssh >/dev/null 2>&1 || { echo "pacman could not install openssh; if the package databases are stale, run a full upgrade (pacman -Syu) first"; exit 1; }
  elif command -v apk >/dev/null 2>&1; then apk add openssh-server >/dev/null 2>&1
  else echo "No supported package manager found"; exit 3; fi
  command -v sshd >/dev/null 2>&1 || [ -x /usr/sbin/sshd ] || { echo "Installing the OpenSSH server failed"; exit 1; }
  did="installed"
fi
if ! ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then ssh-keygen -A >/dev/null 2>&1; fi
mkdir -p /run/sshd 2>/dev/null
if [ -d /run/systemd/system ]; then
  unit=sshd
  systemctl cat ssh >/dev/null 2>&1 && unit=ssh
  systemctl cat "$unit" >/dev/null 2>&1 || { echo "No ssh or sshd unit found"; exit 1; }
  systemctl enable "$unit" >/dev/null 2>&1
  systemctl is-active "$unit" >/dev/null 2>&1 || { systemctl start "$unit" >/dev/null 2>&1 && did="${did:+$did, }started"; }
  systemctl is-active "$unit" >/dev/null 2>&1 || { echo "$unit is not running"; exit 1; }
elif command -v rc-service >/dev/null 2>&1; then
  rc-update add sshd default >/dev/null 2>&1
  rc-service sshd status >/dev/null 2>&1 || { rc-service sshd start >/dev/null 2>&1 && did="${did:+$did, }started"; }
  rc-service sshd status >/dev/null 2>&1 || { echo "sshd is not running"; exit 1; }
else
  echo "Neither systemd nor OpenRC found"
  exit 3
fi
port=$(sshd -T 2>/dev/null | awk '$1=="port" {print $2; exit}')
port=${port:-22}
if [ "$fw" = true ]; then
  fwd=
  command -v firewall-cmd >/dev/null 2>&1 && [ "$(firewall-cmd --state 2>/dev/null)" = running ] && fwd=1
  if command -v ufw >/dev/null 2>&1 && { [ -z "$fwd" ] || ufw status 2>/dev/null | grep -q '^Status: active'; }; then
    ufw allow "$port/tcp" >/dev/null 2>&1 && did="${did:+$did, }ufw port $port open"
  elif [ -n "$fwd" ]; then
    firewall-cmd --permanent --add-port="$port/tcp" >/dev/null 2>&1
    firewall-cmd --add-port="$port/tcp" >/dev/null 2>&1 && did="${did:+$did, }firewalld port $port open"
  else
    echo "Note: no active ufw or firewalld found, no firewall rule added"
  fi
fi
echo "SSH server running on port $port${did:+ ($did)}"
exit 0
