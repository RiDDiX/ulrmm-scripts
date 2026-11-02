#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Finds unhealthy, restarting and non-zero-exited containers (docker or podman).
# Variables: IGNORE (container names to skip, comma or line separated, optional)
# Exit: 0 all fine, 1 problem containers found, 3 bad input or no container engine
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

IGN=$(printf '%s\n' "${IGNORE:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d')
case $(printf %s "$IGN" | tr -d "\n") in *[!A-Za-z0-9_.-]* | -*) echo "IGNORE has characters that are not allowed in a container name"; exit 3 ;; esac

eng=''
for e in docker podman; do command -v $e >/dev/null 2>&1 && { eng=$e; break; }; done
[ -n "$eng" ] || { echo "Unsupported: neither docker nor podman is installed"; exit 3; }
list=$($eng ps -a --format '{{.Names}}|{{.State}}|{{.Status}}' 2>&1) || { echo "Cannot reach $eng: $(printf '%s' "$list" | head -n 1)"; exit 3; }

nl='
'
bad='' n=0
while IFS='|' read -r name state status; do
  [ -n "$name" ] || continue
  n=$((n + 1))
  [ -n "$IGN" ] && printf '%s\n' "$IGN" | grep -qxF -- "$name" && continue
  case $status in
  *unhealthy*) bad="$bad$name: unhealthy ($status)$nl" ;;
  *) case $state in
     restarting) bad="$bad$name: restarting ($status)$nl" ;;
     exited | stopped) case $status in 'Exited (0)'*) ;; *) bad="$bad$name: $status$nl" ;; esac ;;
     esac ;;
  esac
done <<EOT
$list
EOT
if [ -z "$bad" ]; then
  echo "OK: $n containers, none unhealthy, restarting or failed ($eng)"
  exit 0
fi
echo "ERROR: $(printf '%s' "$bad" | wc -l) of $n containers need attention ($eng)"
printf '%s' "$bad"
exit 1
