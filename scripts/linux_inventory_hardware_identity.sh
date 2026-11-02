#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Collects vendor, model and serial number (sysfs DMI, dmidecode, device tree). The last line is the serial.
# Variables: none
# Exit: 0 serial found, 3 no usable serial on this system (virtual machine, container or board without one)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH LC_ALL=C
set -u

dmi() {
  v=$(cat "/sys/class/dmi/id/$1" 2>/dev/null)
  if [ -z "$v" ] && command -v dmidecode >/dev/null 2>&1; then v=$(dmidecode -s "$2" 2>/dev/null | head -n 1); fi
  printf '%s' "$v" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
junk() {
  case $(printf '%s' "$1" | tr '[:upper:]' '[:lower:]') in
  '' | 0 | none | 'not specified' | 'not available' | 'to be filled by o.e.m.' | 'default string' | 'system serial number' | 'unknown' | 'n/a' | '0123456789' | '123456789' | 'chassis serial number') return 0 ;;
  esac
  return 1
}
vendor=$(dmi sys_vendor system-manufacturer)
model=$(dmi product_name system-product-name)
serial=$(dmi product_serial system-serial-number)
junk "$serial" && serial=$(dmi board_serial baseboard-serial-number)
junk "$serial" && serial=$(dmi chassis_serial chassis-serial-number)
if junk "$serial"; then
  serial=$(tr -d '\0' 2>/dev/null </proc/device-tree/serial-number)
  [ -n "$serial" ] || serial=$(sed -n 's/^Serial[[:space:]]*: *//p' /proc/cpuinfo 2>/dev/null | head -n 1)
fi
[ -n "$vendor" ] || vendor=$(tr -d '\0' 2>/dev/null </proc/device-tree/model)
echo "Vendor: ${vendor:-unknown}"
echo "Model: ${model:-unknown}"
echo "BIOS: $(dmi bios_vendor bios-vendor) $(dmi bios_version bios-version)"
if junk "$serial"; then
  echo "No serial number available (virtual machine, container or firmware without one)"
  exit 3
fi
echo "$serial"
