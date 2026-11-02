#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Homebrew outdated report for /opt/homebrew and /usr/local, run as the owner of each installation. Report only.
# Exit: 0 report printed, 3 no usable Homebrew, not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }

found=0
for prefix in /opt/homebrew /usr/local; do
  brew=$prefix/bin/brew
  [ -x "$brew" ] || continue
  owner=$(stat -Lf%Su "$brew" 2>/dev/null)
  case "$owner" in '' | root)
    echo "$prefix: owned by root, Homebrew refuses to run as root, skipped."
    continue
    ;;
  esac
  found=1
  echo "== $prefix (user $owner)"
  out=$(cd / && sudo -u "$owner" -H env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$(dscl . -read "/Users/$owner" NFSHomeDirectory 2>/dev/null | sed 's/^NFSHomeDirectory: //')" \
    HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 "$brew" outdated --verbose 2>&1)
  rc=$?
  if [ $rc -ne 0 ] && [ -z "$out" ]; then
    echo "brew failed with exit code $rc."
  elif [ -z "$out" ]; then
    echo "Nothing outdated."
  else
    echo "$out" | head -n 200
  fi
done

if [ $found -eq 0 ]; then
  echo "No Homebrew installation owned by a user was found."
  exit 3
fi
echo "Based on the last brew update of each user; this report does not run brew update."
exit 0
