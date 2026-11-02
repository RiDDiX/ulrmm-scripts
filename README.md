# UniversalLocal RMM script library

[![Checks](https://github.com/RiDDiX/ulrmm-scripts/actions/workflows/ci.yml/badge.svg)](https://github.com/RiDDiX/ulrmm-scripts/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-FSL--1.1--ALv2-blue)](LICENSE.md)
[![Security policy](https://img.shields.io/badge/security-policy-informational)](SECURITY.md)

The community scripts of UniversalLocal RMM: checks, maintenance actions, collectors and
installers for Windows, Linux and macOS. The server clones this repository to
`/opt/ulrmm-community-scripts` and loads `community_scripts.json` into the dashboard, where the
scripts show up as read-only community scripts that can be run, scheduled, used as checks or
cloned and edited.

The server is at https://github.com/RiDDiX/ulrmm.

![Script manager](https://raw.githubusercontent.com/RiDDiX/ulrmm/main/docs/showcase/script-manager.png)

More screenshots of the dashboard: [SHOWCASE.md](https://github.com/RiDDiX/ulrmm/blob/main/docs/SHOWCASE.md).

## What is in the library

`community_scripts.json` holds 216 entries: 109 for Windows (PowerShell), 74 for Linux and 33
for macOS (shell). They point at 198 script files; several entries share one file and differ
only in `env`, see below.

The entries are sorted into 40 categories of the form `<platform> / <area>`. The areas are
Active Directory, Agent, Antivirus, Inventory, Maintenance, Monitoring, Network, Power,
Remote Access, Security, Server Roles, Software, Storage, System, Updates and Users. Active
Directory and Server Roles exist for Windows only; Power, Remote Access, Storage and Updates
exist for Windows and Linux.

- Antivirus: 32 entries (19 Windows, 6 Linux, 7 macOS) that install, update, scan or report
  on antivirus products. [docs/ANTIVIRUS.md](docs/ANTIVIRUS.md) lists per product what the
  script does, with sources, and which steps cannot run unattended.
- Activation: `scripts/win_system_kms_activation.ps1` points Windows and volume-licensed Office
  at a KMS host and activates them. It is meant for devices covered by a Microsoft volume license
  agreement, activated against your own licensed KMS host. It provides no license and bypasses
  nothing; using a KMS service you are not licensed for breaks Microsoft's license terms.

## Using the library

The server already holds a copy of this repository. Two ways to refresh it:

- `update.sh` fetches this repository on every run.
- In the dashboard, Script manager > Sync library fetches it without a server update.

A script that disappears from the manifest is removed from the server. If a check, a task or an
alert template still uses it, the server keeps it as a normal script in the category
"Retired community scripts" instead.

## Layout

```
community_scripts.json   the manifest the server reads
scripts/                 one file per script
docs/ANTIVIRUS.md        what the antivirus installers do per product, with sources
tests/validate.py        manifest and file rules
tests/lint.sh            shellcheck, dash, busybox sh, bash 3.2, PowerShell parser and PSScriptAnalyzer
tests/run-linux.sh       runs Linux scripts in a matrix of distribution containers
```

## Manifest entry

```json
{
  "guid": "0b0a3c1e-6c0f-4a53-9d0c-0f6b1a2c3d4e",
  "filename": "linux_monitoring_disk_space.sh",
  "name": "Disk space check",
  "description": "What it does, what it changes, what the exit code means.",
  "shell": "shell",
  "category": "Linux / Monitoring",
  "supported_platforms": ["linux"],
  "default_timeout": 60,
  "syntax": "optional note shown next to the script in run dialogs",
  "run_as_user": false,
  "env": ["OPTIONAL_FIXED=value"],
  "variables": [
    {"name": "WARN_PERCENT", "label": "Warn above (%)", "type": "integer",
     "required": false, "default": "85", "help": "Used space that counts as a warning."}
  ]
}
```

- `guid` is a new lowercase uuid4 and never changes afterwards; the server recognises a script by it.
- File names are `win_<area>_<what>.ps1`, `linux_<area>_<what>.sh` and `mac_<area>_<what>.sh`.
- `category` is `Windows / <Area>`, `Linux / <Area>` or `macOS / <Area>`. The areas are fixed, see
  `AREAS` in `tests/validate.py`.
- Several entries can point at the same file and differ in `env`. The antivirus installer does
  that: one script, one entry per product.

## Variables

A script takes its input only from environment variables. Each one is declared in `variables`;
the dashboard builds a form from the list and passes `NAME=value` for every field that is
filled in. Types: `string`, `text`, `integer`, `decimal`, `checkbox` (`true`/`false`), `select`
(with `options`), `ip`, `date`, `datetime`, `password` (masked, no default).

- An optional field that is left empty is not sent. The script falls back to its default itself.
- A script checks every value it uses and ends with exit code 3 when one is wrong. Scheduled
  tasks and checks pass the same variables as hand-typed `NAME=value` lines.
- Lists take one item per line or comma separated.
- Names that every process already has in its environment (`USERNAME`, `PATH`, `HOSTNAME`,
  `TEMP`, ...) are not allowed: an empty field would read the inherited value.
- A value can be a placeholder such as `{{client.name}}` or `{{global.KMS_HOST}}`; the server
  fills it in before the run.

## Conventions

- Exit codes: `0` ok, `1` failed or the check is failing, `2` warning, `3` wrong input or a
  system the script does not support.
- A check prints its verdict on the first line and details after it. A collector prints the
  value alone on the last line.
- Scripts are written so that a second run does no harm. Cleanup scripts have a `DRY_RUN`
  checkbox.
- Scripts do not print secrets. Downloads use https and are verified before use.
- The header comment says what the script does, lists the variables with defaults and the exit
  codes. Nothing else.

Windows scripts run under Windows PowerShell 5.1 as SYSTEM (unless `run_as_user` is set), are
plain ASCII and use no modules that Windows does not ship.

Linux scripts start with `#!/bin/sh` and stay within POSIX sh. They run as root on Debian,
Ubuntu, the RHEL family, Fedora, openSUSE, Arch and Alpine, with apt, dnf, yum, zypper, pacman
or apk and with systemd or OpenRC. Where a script cannot work on a system it says why and ends
with exit code 3.

macOS scripts start with `#!/bin/bash`, work with bash 3.2 and run as root on macOS 13 and later.
Steps that need Full Disk Access, an MDM profile or the user's approval are reported, not faked.

## Checks before a commit

```
python3 tests/validate.py
tests/lint.sh
tests/run-linux.sh -P scripts/linux_monitoring_disk_space.sh
```

`tests/lint.sh` needs docker. It builds a small image with PSScriptAnalyzer on first use and
checks PowerShell files against the Windows PowerShell 5.1 profiles. `tests/run-linux.sh` runs
the given scripts as root in containers of ten distributions and prints one result line per
image; `-e NAME=value` passes variables, `-t <container>` targets a running systemd container.

Windows and macOS scripts cannot be executed by these checks. Try a new or changed one on a
test device before relying on it.

## Third-party software

The library ships no third-party code or binaries. Scripts that install software (antivirus
products, winget and Homebrew packages, ClamAV and others) download it at run time from its
vendor or from a URL you set, and check its signature or SHA-256. That software comes under the vendor's license and
terms, and the silent install switches accept the vendor's license agreement and privacy policy
on the device. Use these scripts only where you may accept those terms and hold the licenses;
free and home editions are often licensed for private use only.

## Use at your own risk

The scripts run as SYSTEM or root and change the systems they run on. Read a script before you
use it, try it on a test device and keep backups. They are provided as is, without warranty,
see LICENSE.md. Product names in this library are trademarks of their owners; the project is
not affiliated with or endorsed by them.

## License

Licensed under the Functional Source License, Version 1.1, ALv2 Future License
([LICENSE.md](LICENSE.md)); two years after a version is made available it is also licensed
under Apache-2.0. If you redistribute copies, modifications or derivatives, include LICENSE.md
or a link to it and keep the copyright notices, [NOTICE.md](NOTICE.md) included.
