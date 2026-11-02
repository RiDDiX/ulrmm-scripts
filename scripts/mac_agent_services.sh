#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Status of the agent launch daemon (ulrmm-agent), its self-healing job and the MeshCentral agent. No variables.
# Exit: 0 all running, 1 agent not running, 2 self-healing job or mesh agent missing or not running, 3 not macOS or not root.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

{ [ "$(uname -s)" = Darwin ] && [ "$(id -u)" -eq 0 ]; } || { echo "Needs macOS and root."; exit 3; }

# prints "running pid N", "loaded (not running)" or "not loaded"
svc() {
  local out pid
  out=$(launchctl print "system/$1" 2>/dev/null) || { echo "not loaded"; return; }
  pid=$(echo "$out" | sed -n 's/^[[:space:]]*pid = \([0-9]*\)$/\1/p' | head -n 1)
  if [ -n "$pid" ]; then echo "running pid $pid"; else echo "loaded (not running)"; fi
}
file() { if [ -e "$2" ]; then echo "  $1: $2"; else echo "  $1: $2 MISSING"; fi; }

rc=0
a=$(svc ulrmm-agent)
h=$(svc ulrmm-agent.selfheal)
m=$(svc meshagent)
case "$a" in running*) ;; *) rc=1 ;; esac
# the self-healing job runs on an interval, so loaded between runs is normal
[ "$h" = "not loaded" ] && [ $rc -eq 0 ] && rc=2
case "$m" in running*) ;; *) [ $rc -eq 0 ] && rc=2 ;; esac

case $rc in
0) echo "OK: agent, self-healing job and mesh agent are up" ;;
1) echo "FAILING: the agent service is not running" ;;
*) echo "WARNING: self-healing job or mesh agent is not up" ;;
esac
echo "Agent service ulrmm-agent: $a"
file plist /Library/LaunchDaemons/ulrmm-agent.plist
file binary /opt/ulrmm-agent/ulrmm-agent
file log /var/log/ulrmm-agent.log
echo "Self-healing job ulrmm-agent.selfheal: $h"
file plist /Library/LaunchDaemons/ulrmm-agent.selfheal.plist
echo "MeshCentral agent meshagent: $m"
if [ -x /opt/ulrmm-mesh/meshagent ]; then
  echo "  binary: /opt/ulrmm-mesh/meshagent"
elif [ -x /usr/local/mesh_services/meshagent/meshagent ]; then
  echo "  binary: /usr/local/mesh_services/meshagent/meshagent"
else
  echo "  binary: not found under /opt/ulrmm-mesh or /usr/local/mesh_services"
fi
exit $rc
