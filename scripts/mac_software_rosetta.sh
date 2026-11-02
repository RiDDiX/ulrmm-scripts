#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Install Rosetta 2 on Apple silicon. No variables.
# Exit: 0 installed or already present, 1 install failed, 3 Intel Mac, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }
# uname -m lies when this shell runs under Rosetta itself
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" != 1 ]; then
  echo "Not an Apple silicon Mac, Rosetta does not apply."
  exit 3
fi

if [ -f /Library/Apple/usr/libexec/oah/libRosettaRuntime ] || pgrep -qx oahd; then
  echo "Rosetta is already installed."
  exit 0
fi

if softwareupdate --install-rosetta --agree-to-license 2>&1 | tail -n 5; then
  if [ -f /Library/Apple/usr/libexec/oah/libRosettaRuntime ]; then
    echo "Rosetta installed."
    exit 0
  fi
fi
echo "Rosetta is not installed. Check the network and that no profile blocks Apple software downloads."
exit 1
