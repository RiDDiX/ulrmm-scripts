#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Runs Linux scripts as root in containers, one result line per image.
#   tests/run-linux.sh [-P] [-e NAME=value]... [-i img1,img2] [-t systemd-container] script...
# -P installs curl, openssl, nc, ping and procps first (slim images lack them).
# -t runs the scripts inside an already running container instead of the image matrix.
set -u
cd "$(dirname "$0")/.." || exit 1
IMAGES="debian:12 debian:13 ubuntu:22.04 ubuntu:24.04 almalinux:9 fedora:44 opensuse/leap:15.6 opensuse/tumbleweed archlinux alpine:3.22"
envs=() target="" pre=""
while getopts "Pe:i:t:" o; do
  case $o in
  P) pre=1 ;;
  e) envs+=(-e "$OPTARG") ;;
  i) IMAGES=${OPTARG//,/ } ;;
  t) target=$OPTARG ;;
  *) exit 2 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || { echo "usage: $0 [-P] [-e N=v] [-i imgs] [-t container] script..." >&2; exit 2; }
# shellcheck disable=SC2016
prelude='if command -v apt-get >/dev/null; then apt-get update -qq >/dev/null 2>&1; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl openssl netcat-openbsd iputils-ping procps >/dev/null 2>&1
elif command -v dnf >/dev/null; then dnf install -y -q --allowerasing curl openssl nmap-ncat iputils procps-ng >/dev/null 2>&1
elif command -v zypper >/dev/null; then zypper -q -n install curl openssl netcat-openbsd iputils procps >/dev/null 2>&1
elif command -v pacman >/dev/null; then pacman -Sy --noconfirm curl openssl openbsd-netcat iputils procps-ng >/dev/null 2>&1
elif command -v apk >/dev/null; then apk add -q curl openssl iputils procps >/dev/null 2>&1; fi
exec sh "$1"'
# shellcheck disable=SC2016
plain='exec sh "$1"'
[ -n "$pre" ] && wrap=$prelude || wrap=$plain
for s in "$@"; do
  echo "### $s"
  if [ -n "$target" ]; then
    out=$(docker exec -i "${envs[@]}" "$target" sh "/r/$s" </dev/null 2>&1)
    printf '%-24s rc=%-3s %s\n' "$target" $? "$(printf '%s\n' "$out" | head -n1 | cut -c1-90)"
    continue
  fi
  for img in $IMAGES; do
    out=$(timeout 120 docker run --rm --name "ulrmm-scripts-la-$$-$RANDOM" -v "$PWD:/r:ro" "${envs[@]}" "$img" sh -c "$wrap" sh "/r/$s" </dev/null 2>&1)
    printf '%-24s rc=%-3s %s\n' "$img" $? "$(printf '%s\n' "$out" | head -n1 | cut -c1-90)"
  done
done
