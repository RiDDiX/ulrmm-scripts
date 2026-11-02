#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Removes stopped containers, dangling images and unused networks of docker or podman.
# Variables: DRY_RUN (default true), ALL_IMAGES (default false, also unused tagged images), VOLUMES (default false, also unused volumes).
# Exit codes: 0 done, 1 prune failed, 3 bad input or no container runtime.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

flag() {
  case $1 in true) echo 1 ;; false) echo 0 ;; *) echo "$2 must be true or false" >&2; exit 3 ;; esac
}
dry=$(flag "${DRY_RUN:-true}" DRY_RUN) || exit 3
all=$(flag "${ALL_IMAGES:-false}" ALL_IMAGES) || exit 3
vols=$(flag "${VOLUMES:-false}" VOLUMES) || exit 3
for r in docker podman; do
  command -v "$r" >/dev/null 2>&1 && rt=$r && break
done
[ -n "${rt:-}" ] || { echo "Neither docker nor podman is installed"; exit 3; }
"$rt" info >/dev/null 2>&1 || { echo "$rt is installed but its daemon is not reachable"; exit 3; }

echo "Before:"
"$rt" system df
if [ "$dry" = 1 ]; then
  echo "Dry run, would remove:"
  "$rt" ps -a --filter status=exited --filter status=created --format 'container {{.Names}} ({{.Image}})'
  if [ "$all" = 1 ]; then
    "$rt" images --filter dangling=false --format 'image {{.Repository}}:{{.Tag}} (all unused ones)'
  else
    "$rt" images --filter dangling=true --format 'dangling image {{.ID}}'
  fi
  [ "$vols" = 1 ] && "$rt" volume ls --filter dangling=true --format 'volume {{.Name}}'
  exit 0
fi
set -- system prune -f
[ "$all" = 1 ] && set -- "$@" -a
[ "$vols" = 1 ] && set -- "$@" --volumes
"$rt" "$@" >/dev/null 2>&1 || { echo "$rt prune failed"; exit 1; }
echo "After:"
"$rt" system df
exit 0
