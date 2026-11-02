#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Requests a URL (no redirects followed with curl) and compares the HTTP status.
# Variables: URL (http or https, required), EXPECT_STATUS (200), TIMEOUT (10, seconds)
# Exit: 0 status as expected, 1 other status or no answer, 3 bad input or neither curl nor wget installed
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

U=${URL:-}
[ -n "$U" ] || { echo "URL is required"; exit 3; }
case $U in http://* | https://*) ;; *) echo "URL must start with http:// or https://"; exit 3 ;; esac
case $U in *[!A-Za-z0-9._~:/?#@!\&=+,\;%-]*) echo "URL contains characters that are not allowed (spaces, quotes, \$, backslash...)"; exit 3 ;; esac
E=${EXPECT_STATUS:-200}
case $E in [1-5][0-9][0-9]) ;; *) echo "EXPECT_STATUS must be a 3 digit HTTP status"; exit 3 ;; esac
T=${TIMEOUT:-10}
case $T in '' | *[!0-9]*) echo "TIMEOUT must be a whole number"; exit 3 ;; esac
{ [ "${#T}" -le 3 ] && [ "$T" -ge 1 ] && [ "$T" -le 300 ]; } || { echo "TIMEOUT must be between 1 and 300"; exit 3; }

if command -v curl >/dev/null 2>&1; then
  r=$(curl -sS -o /dev/null -w '%{http_code} %{time_total}' --max-time "$T" -- "$U" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then echo "ERROR: $U no answer: $(printf '%s' "$r" | head -n 1 | cut -c1-150)"; exit 1; fi
  code=${r%% *}; secs=${r#* }
elif command -v wget >/dev/null 2>&1; then
  mr=''
  wget --help 2>&1 | grep -q 'max-redirect' && mr=--max-redirect=0
  # shellcheck disable=SC2086
  r=$(wget -S -q -O /dev/null -T "$T" $mr "$U" 2>&1) || true
  code=$(printf '%s\n' "$r" | sed -n 's/^ *HTTP\/[0-9.]* \([0-9][0-9][0-9]\).*/\1/p' | tail -n 1)
  if [ -z "$code" ]; then
    m=$(printf '%s' "$r" | tail -n 1 | cut -c1-150)
    echo "ERROR: $U no answer: ${m:-connection failed or timed out}"
    exit 1
  fi
  secs='?'
else
  echo "Unsupported: neither curl nor wget is installed (install curl)"
  exit 3
fi
if [ "$code" = "$E" ]; then echo "OK: $U returned $code in ${secs}s"; exit 0; fi
echo "ERROR: $U returned $code, expected $E (${secs}s)"
exit 1
