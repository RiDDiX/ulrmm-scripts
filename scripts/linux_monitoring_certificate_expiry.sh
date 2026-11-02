#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks when the TLS certificates of files (PEM) or host:port endpoints expire.
# Variables: TARGETS (one per line: /path/cert.pem or host:port, required), WARN_DAYS (30), ERROR_DAYS (7)
# Exit: 0 all fine, 1 expired, unreachable or inside ERROR_DAYS, 2 inside WARN_DAYS, 3 bad input or openssl missing
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

int() {
  case $2 in '' | *[!0-9]*) echo "$1 must be a whole number"; exit 3 ;; esac
  { [ "${#2}" -le 4 ] && [ "$2" -ge 1 ] && [ "$2" -le 3650 ]; } || { echo "$1 must be between 1 and 3650"; exit 3; }
}
WD=${WARN_DAYS:-30}
ED=${ERROR_DAYS:-7}
int WARN_DAYS "$WD"
int ERROR_DAYS "$ED"
[ "$ED" -lt "$WD" ] || { echo "ERROR_DAYS must be lower than WARN_DAYS"; exit 3; }
LIST=$(printf '%s\n' "${TARGETS:-}" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d')
[ -n "$LIST" ] || { echo "TARGETS is required"; exit 3; }
command -v openssl >/dev/null 2>&1 || { echo "openssl is not installed (install the openssl package)"; exit 3; }

# validate everything before touching anything
printf '%s\n' "$LIST" | while IFS= read -r t; do
  case $t in
  /*) case $t in *[!A-Za-z0-9/._+@-]*) echo "Bad file path: $t"; exit 1 ;; esac ;;
  *:*)
    h=${t%:*} p=${t##*:}
    case $h in '' | -* | *[!A-Za-z0-9.-]*) echo "Bad host: $t"; exit 1 ;; esac
    case $p in '' | *[!0-9]*) echo "Bad port: $t"; exit 1 ;; esac
    [ "${#p}" -le 5 ] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ] || { echo "Bad port: $t"; exit 1; } ;;
  *) echo "Target must be an absolute file path or host:port: $t"; exit 1 ;;
  esac
done || exit 3
tmo=''
command -v timeout >/dev/null 2>&1 && tmo='timeout 20'

nl='
'
rc=0 detail='' n=0
for t in $LIST; do
  n=$((n + 1))
  case $t in
  /*)
    [ -r "$t" ] || { detail="${detail}ERROR $t: not readable$nl"; rc=1; continue; }
    cert=$(openssl x509 -in "$t" 2>/dev/null) ;;
  *)
    h=${t%:*}
    cert=$($tmo openssl s_client -connect "$t" -servername "$h" </dev/null 2>/dev/null | openssl x509 2>/dev/null) ;;
  esac
  [ -n "$cert" ] || { detail="${detail}ERROR $t: no certificate (unreachable, no TLS or not PEM)$nl"; rc=1; continue; }
  end=$(printf '%s\n' "$cert" | openssl x509 -noout -enddate | sed 's/^notAfter=//')
  if ! printf '%s\n' "$cert" | openssl x509 -noout -checkend 0 >/dev/null; then
    detail="${detail}ERROR $t: expired on $end$nl"; rc=1
  elif ! printf '%s\n' "$cert" | openssl x509 -noout -checkend $((ED * 86400)) >/dev/null; then
    detail="${detail}ERROR $t: expires $end (within $ED days)$nl"; rc=1
  elif ! printf '%s\n' "$cert" | openssl x509 -noout -checkend $((WD * 86400)) >/dev/null; then
    detail="${detail}WARN  $t: expires $end (within $WD days)$nl"; [ $rc -eq 0 ] && rc=2
  else
    detail="${detail}ok    $t: expires $end$nl"
  fi
done
case $rc in
0) echo "OK: $n certificates valid for more than $WD days" ;;
1) echo "ERROR: certificate problem, see below" ;;
2) echo "WARNING: a certificate expires within $WD days" ;;
esac
printf '%s' "$detail"
exit $rc
