#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows install, enable and run state of the ULRMM agent and the MeshCentral agent, plus the agent version.
# Variables: none
# Exit: 0 agent running, 1 agent installed but not running, 2 only the MeshCentral agent is stopped, 3 agent not installed or no service manager
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then mgr=systemd
elif command -v rc-service >/dev/null 2>&1; then mgr=openrc
else echo "Unsupported: neither systemd nor OpenRC found"; exit 3; fi

# state <service> <binary>: prints "installed|enabled|running"
state() {
  inst=no en=no run=no
  [ -x "$2" ] && inst=yes
  if [ $mgr = systemd ]; then
    systemctl cat "$1" >/dev/null 2>&1 && inst=yes
    systemctl is-enabled "$1" >/dev/null 2>&1 && en=yes
    systemctl is-active "$1" >/dev/null 2>&1 && run=yes
  else
    [ -e "/etc/init.d/$1" ] && inst=yes
    rc-update show 2>/dev/null | grep -qw "^ *$1" && en=yes
    rc-service "$1" status >/dev/null 2>&1 && run=yes
  fi
  echo "$inst|$en|$run"
}
agent=/opt/ulrmm-agent/ulrmm-agent
mesh=/opt/ulrmm-mesh/meshagent
a=$(state ulrmm-agent "$agent")
m=$(state meshagent "$mesh")
case $a in no*) echo "ULRMM agent is not installed on this system"; echo "mesh agent: installed=${m%%|*}"; exit 3 ;; esac
ver=''
if [ -x "$agent" ]; then
  if command -v timeout >/dev/null 2>&1; then ver=$(timeout 10 "$agent" -version 2>&1 </dev/null | head -n 1)
  else ver=$("$agent" -version 2>&1 </dev/null | head -n 1); fi
fi
mtime=''
[ -f "$mesh" ] && mtime=$(date -r "$mesh" '+%Y-%m-%d' 2>/dev/null)
ai=${a%%|*}; r=${a#*|}; ae=${r%%|*}; ar=${r#*|}
mi=${m%%|*}; r=${m#*|}; me=${r%%|*}; mr=${r#*|}
rc=0
[ "$ar" = yes ] || rc=1
[ $rc -eq 0 ] && [ "$mi" = yes ] && [ "$mr" != yes ] && rc=2
case $rc in
0) echo "OK: agent running${mi:+, mesh agent installed=$mi running=$mr}" ;;
1) echo "ERROR: agent installed but not running" ;;
2) echo "WARNING: agent running, mesh agent not running" ;;
esac
echo "ulrmm-agent: installed=$ai enabled=$ae running=$ar version=${ver:-unknown} ($mgr)"
echo "meshagent:   installed=$mi enabled=$me running=$mr binary built ${mtime:-unknown}"
exit $rc
