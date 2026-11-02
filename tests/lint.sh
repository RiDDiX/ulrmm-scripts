#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Static checks for the script files. Needs docker.
#   tests/lint.sh                 everything in scripts/
#   tests/lint.sh scripts/a.sh .. only these files
set -u
cd "$(dirname "$0")/.." || exit 1

files=("$@")
[ ${#files[@]} -gt 0 ] || files=(scripts/*)

linux=() mac=() ps=()
for f in "${files[@]}"; do
  case "$(basename "$f")" in
  linux_*.sh) linux+=("$f") ;;
  mac_*.sh) mac+=("$f") ;;
  win_*.ps1) ps+=("$f") ;;
  esac
done

rc=0
run() { "$@" || rc=1; }

if [ ${#linux[@]} -gt 0 ]; then
  echo "== shellcheck sh (${#linux[@]})"
  run docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:stable -s sh "${linux[@]}"
  echo "== dash -n, busybox sh -n"
  run docker run --rm -v "$PWD:/mnt:ro" -w /mnt debian:13-slim sh -c 'for f; do dash -n "$f" || exit 1; done' sh "${linux[@]}"
  run docker run --rm -v "$PWD:/mnt:ro" -w /mnt alpine:3.22 sh -c 'for f; do sh -n "$f" || exit 1; done' sh "${linux[@]}"
fi

if [ ${#mac[@]} -gt 0 ]; then
  echo "== shellcheck bash (${#mac[@]})"
  run docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:stable -s bash "${mac[@]}"
  echo "== bash 3.2 -n"
  run docker run --rm -v "$PWD:/mnt:ro" -w /mnt bash:3.2 bash -c 'for f; do bash -n "$f" || exit 1; done' bash "${mac[@]}"
fi

if [ ${#ps[@]} -gt 0 ]; then
  echo "== PowerShell parser and PSScriptAnalyzer (${#ps[@]})"
  docker image inspect ulrmm-scripts-pssa >/dev/null 2>&1 ||
    docker build -q -t ulrmm-scripts-pssa tests/pssa >/dev/null || exit 1
  run docker run --rm -v "$PWD:/mnt:ro" -w /mnt ulrmm-scripts-pssa \
    pwsh -NoProfile -File tests/pssa/lint.ps1 "${ps[@]}"
fi

[ $rc -eq 0 ] && echo "LINT OK" || echo "LINT FAILED"
exit $rc
