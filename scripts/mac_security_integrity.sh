#!/bin/bash
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# System integrity report: SIP, authenticated root volume, Gatekeeper. No variables.
# Exit: 0 all protections on, 1 SIP or Gatekeeper off, 2 custom SIP configuration, 3 not macOS.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
set -u

[ "$(uname -s)" = Darwin ] || { echo "Not macOS."; exit 3; }

sip=$(csrutil status 2>&1 | head -n 3 | tr '\n' ' ')
gk=$(spctl --status 2>&1 | head -n 1)
authroot=$(csrutil authenticated-root status 2>&1 | head -n 1)

rc=0
case "$sip" in
*"(Custom Configuration)"*) rc=2 ;;
*"status: enabled"*) ;;
*) rc=1 ;;
esac
case "$gk" in
*"assessments enabled"*) ;;
*) rc=1 ;;
esac

case $rc in
0) echo "System integrity protections are on." ;;
2) echo "SIP is on with a custom configuration." ;;
*) echo "SIP or Gatekeeper is off or unreadable." ;;
esac
echo "SIP: $sip"
echo "Gatekeeper: $gk"
echo "Authenticated root volume: $authroot"
echo "Secure boot level: not read (Apple silicon needs recoveryOS, Intel the Startup Security Utility)."
exit $rc
