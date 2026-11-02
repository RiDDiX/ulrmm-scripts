#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Install the Command Line Tools through softwareupdate. No variables.
# Exit: 0 installed or already present, 1 install failed or no package offered, 3 not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }

if [ -x /Library/Developer/CommandLineTools/usr/bin/git ] && pkgutil --pkg-info=com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then
  echo "Command Line Tools already installed ($(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | sed -n 's/^version: //p'))."
  exit 0
fi

# The placeholder makes softwareupdate list the tools as an update.
flag=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
trap 'rm -f "$flag"' EXIT
touch "$flag"

list=$(softwareupdate -l 2>&1)
label=$(echo "$list" | sed -n 's/^[[:space:]]*\* \(Label: \)\{0,1\}\(Command Line Tools.*\)$/\2/p' | tail -n 1)
if [ -z "$label" ]; then
  echo "softwareupdate offers no Command Line Tools package."
  echo "$list" | tail -n 3
  exit 1
fi
echo "Installing: $label"
if softwareupdate -i "$label" 2>&1 | tail -n 5; then
  if [ -x /Library/Developer/CommandLineTools/usr/bin/git ]; then
    echo "Command Line Tools installed."
    exit 0
  fi
fi
echo "Command Line Tools are not installed."
exit 1
