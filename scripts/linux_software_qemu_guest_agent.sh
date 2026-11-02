#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Installs and starts the QEMU guest agent on a KVM/QEMU virtual machine.
# Variables: none. Exit codes: 0 agent running, 1 install or start failed, 3 not a QEMU/KVM guest or unsupported system.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

if [ -f /.dockerenv ] || grep -qaE 'docker|lxc|containerd|kubepods' /proc/1/cgroup 2>/dev/null; then
  echo "This is a container, not a virtual machine"
  exit 3
fi
vm=
if command -v systemd-detect-virt >/dev/null 2>&1; then
  case $(systemd-detect-virt 2>/dev/null) in kvm | qemu) vm=1 ;; esac
fi
grep -qiE 'qemu|kvm' /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name 2>/dev/null && vm=1
[ -e /dev/virtio-ports/org.qemu.guest_agent.0 ] && vm=1
[ -n "$vm" ] || { echo "This is not a QEMU/KVM guest"; exit 3; }

if ! command -v qemu-ga >/dev/null 2>&1 && [ ! -x /usr/sbin/qemu-ga ]; then
  export DEBIAN_FRONTEND=noninteractive
  if command -v apt-get >/dev/null 2>&1; then apt-get update >/dev/null 2>&1; apt-get install -y qemu-guest-agent >/dev/null 2>&1
  elif command -v dnf >/dev/null 2>&1; then dnf -y install qemu-guest-agent >/dev/null 2>&1
  elif command -v yum >/dev/null 2>&1; then yum -y install qemu-guest-agent >/dev/null 2>&1
  elif command -v zypper >/dev/null 2>&1; then zypper -n install qemu-guest-agent >/dev/null 2>&1
  elif command -v pacman >/dev/null 2>&1; then pacman -S --needed --noconfirm qemu-guest-agent >/dev/null 2>&1 || echo "pacman failed; if the package databases are stale, run a full upgrade (pacman -Syu) first"
  elif command -v apk >/dev/null 2>&1; then apk add qemu-guest-agent >/dev/null 2>&1
  else echo "No supported package manager found"; exit 3; fi
  command -v qemu-ga >/dev/null 2>&1 || [ -x /usr/sbin/qemu-ga ] || { echo "Installing qemu-guest-agent failed"; exit 1; }
  echo "qemu-guest-agent installed"
fi
if [ -d /run/systemd/system ]; then
  unit=qemu-guest-agent
  systemctl enable "$unit" >/dev/null 2>&1
  systemctl start "$unit" >/dev/null 2>&1
  systemctl is-active "$unit" >/dev/null 2>&1 || { echo "qemu-guest-agent is not running (the host must expose the virtio channel org.qemu.guest_agent.0)"; exit 1; }
elif command -v rc-service >/dev/null 2>&1; then
  rc-update add qemu-guest-agent default >/dev/null 2>&1
  rc-service qemu-guest-agent start >/dev/null 2>&1
  rc-service qemu-guest-agent status >/dev/null 2>&1 || { echo "qemu-guest-agent is not running"; exit 1; }
else
  echo "Neither systemd nor OpenRC found"
  exit 3
fi
echo "qemu-guest-agent installed, enabled and running"
exit 0
