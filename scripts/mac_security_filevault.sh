#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# FileVault status. No variables.
# Exit: 0 on, 1 off, 2 encryption or decryption in progress, 3 not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }

out=$(fdesetup status 2>&1)
rc=$?
if [ $rc -ne 0 ] && [ -z "$out" ]; then
  echo "fdesetup failed with exit code $rc."
  exit 1
fi

case "$out" in
*"Decryption in progress"* | *"Encryption in progress"*)
  echo "FileVault is changing state."
  echo "$out"
  exit 2
  ;;
*"FileVault is On"*)
  echo "FileVault is on."
  echo "$out" | sed -n '2,$p'
  exit 0
  ;;
*"FileVault is Off"*)
  echo "FileVault is off."
  echo "$out" | sed -n '2,$p'
  exit 1
  ;;
esac
echo "FileVault state could not be read."
echo "$out"
exit 3
