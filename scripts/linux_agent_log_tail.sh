#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows the last lines of the ULRMM agent log (journald unit, else log file under the agent directory or syslog).
# Variables: LINES (100, 1-2000)
# Exit: 0 log shown, 3 bad input or no agent log found
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

N=${LINES:-100}
case $N in '' | *[!0-9]*) echo "LINES must be a whole number"; exit 3 ;; esac
{ [ "${#N}" -le 4 ] && [ "$N" -ge 1 ] && [ "$N" -le 2000 ]; } || { echo "LINES must be between 1 and 2000"; exit 3; }

if [ -d /run/systemd/system ] && command -v journalctl >/dev/null 2>&1 && systemctl cat ulrmm-agent >/dev/null 2>&1; then
  echo "== journal, unit ulrmm-agent, last $N lines"
  journalctl -u ulrmm-agent -n "$N" --no-pager -q 2>/dev/null | cut -c1-400
  exit 0
fi
for f in /opt/ulrmm-agent/*.log /opt/ulrmm-agent/logs/*.log /var/log/ulrmm-agent.log /var/log/ulrmm-agent/*.log; do
  [ -f "$f" ] || continue
  echo "== $f, last $N lines"
  tail -n "$N" "$f" | cut -c1-400
  exit 0
done
for f in /var/log/messages /var/log/syslog; do
  [ -r "$f" ] || continue
  out=$(grep -i 'ulrmm-agent' "$f" | tail -n "$N")
  [ -n "$out" ] || continue
  echo "== $f, last $N agent lines"
  printf '%s\n' "$out" | cut -c1-400
  exit 0
done
echo "No agent log found: no journal unit ulrmm-agent, no log file under /opt/ulrmm-agent or /var/log, no syslog entries"
exit 3
