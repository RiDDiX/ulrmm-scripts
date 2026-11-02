#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

"""Checks the manifest and the script files. Standard library only.

  python3 tests/validate.py                      community_scripts.json + every fragment
  python3 tests/validate.py manifest/linux.json  only these fragments
"""
import json
import re
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"

PLATFORMS = {"win": ("windows", "Windows"), "linux": ("linux", "Linux"), "mac": ("darwin", "macOS")}
SHELLS = {".ps1": "powershell", ".sh": "shell"}
SHEBANG = {"linux": "#!/bin/sh", "mac": "#!/bin/bash"}
AREAS = {
    "Active Directory",
    "Agent",
    "Antivirus",
    "Inventory",
    "Maintenance",
    "Monitoring",
    "Network",
    "Power",
    "Remote Access",
    "Security",
    "Server Roles",
    "Software",
    "Storage",
    "System",
    "Updates",
    "Users",
}
REQUIRED = {
    "guid",
    "filename",
    "name",
    "description",
    "shell",
    "category",
    "supported_platforms",
    "default_timeout",
}
OPTIONAL = {"args", "env", "syntax", "run_as_user", "variables"}
VAR_KEYS = {"name", "label", "type", "required", "default", "options", "help"}
VAR_TYPES = {
    "string",
    "text",
    "integer",
    "decimal",
    "checkbox",
    "select",
    "ip",
    "date",
    "datetime",
    "password",
}
FILENAME = re.compile(r"^(win|linux|mac)_[a-z0-9]+(_[a-z0-9]+)*\.(ps1|sh)$")
VAR_NAME = re.compile(r"^[A-Z][A-Z0-9_]{1,39}$")
# Names the agent's process already has in its environment: an empty optional
# variable would silently read the inherited value.
INHERITED = set(
    """PATH HOME USER USERNAME LOGNAME SHELL HOSTNAME PWD OLDPWD LANG LANGUAGE TERM TEMP TMP
    TMPDIR OS COMPUTERNAME USERDOMAIN USERPROFILE APPDATA LOCALAPPDATA PROGRAMDATA PROGRAMFILES
    SYSTEMROOT SYSTEMDRIVE WINDIR COMSPEC PATHEXT PSMODULEPATH PUBLIC HOMEDRIVE HOMEPATH IFS MAIL
    EDITOR DISPLAY UID EUID PPID RANDOM SECONDS LINENO OPTIND OPTARG SHLVL DRIVERDATA
    PROCESSOR_ARCHITECTURE NUMBER_OF_PROCESSORS""".split()
)

errors = []


def err(where, msg):
    errors.append(f"{where}: {msg}")


def check_variable(where, var, body, ext):
    if not isinstance(var, dict):
        return err(where, "variable is not an object")
    name = var.get("name", "")
    where = f"{where} variable {name or '?'}"
    for key in var.keys() - VAR_KEYS:
        err(where, f"unknown key {key}")
    if not VAR_NAME.match(str(name)):
        err(where, "name must be UPPER_SNAKE, 2-40 characters")
    if name in INHERITED:
        err(where, "name is an environment variable every process inherits, pick another")
    label = var.get("label")
    if not isinstance(label, str) or not 1 <= len(label) <= 60:
        err(where, "label is required, at most 60 characters")
    vtype = var.get("type")
    if vtype not in VAR_TYPES:
        return err(where, f"type {vtype!r} is not one of {sorted(VAR_TYPES)}")
    if not isinstance(var.get("required", False), bool):
        err(where, "required must be true or false")
    if len(var.get("help", "")) > 200:
        err(where, "help is longer than 200 characters")
    default = var.get("default", "")
    if not isinstance(default, str):
        return err(where, "default must be a string")
    options = var.get("options", [])
    if vtype == "select":
        if not options or not all(isinstance(o, str) and o for o in options):
            err(where, "select needs a list of non-empty options")
        elif default and default not in options:
            err(where, "default is not one of the options")
    elif options:
        err(where, "options only belong to select")
    if default:
        if vtype == "password":
            err(where, "a password has no default")
        if vtype == "checkbox" and default not in ("true", "false"):
            err(where, "checkbox default must be true or false")
        if vtype == "integer" and not re.fullmatch(r"-?\d+", default):
            err(where, "integer default is not an integer")
        if vtype == "decimal" and not re.fullmatch(r"-?\d+(\.\d+)?", default):
            err(where, "decimal default is not a number")
    if body is not None and name:
        used = (
            re.search(rf"env:{name}\b", body, re.I)
            if ext == ".ps1"
            else re.search(rf"\$\{{?{name}\b", body)
        )
        if not used:
            err(where, "is declared but the script never reads it")


def check_file(path):
    where = f"scripts/{path.name}"
    raw = path.read_bytes()
    if len(raw) > 64 * 1024:
        err(where, "larger than 64 KiB")
    if b"\r" in raw:
        err(where, "has CR line endings, use LF")
    if raw.startswith(b"\xef\xbb\xbf"):
        err(where, "starts with a BOM")
    if not raw.endswith(b"\n"):
        err(where, "does not end with a newline")
    try:
        body = raw.decode("ascii" if path.suffix == ".ps1" else "utf-8")
    except UnicodeDecodeError as e:
        err(where, f"not {'ASCII' if path.suffix == '.ps1' else 'UTF-8'}: {e}")
        return None
    prefix = path.name.split("_", 1)[0]
    if path.suffix == ".sh" and body.split("\n", 1)[0] != SHEBANG.get(prefix):
        err(where, f"first line must be {SHEBANG.get(prefix)}")
    return body


def check_entry(entry, source, bodies):
    where = f"{source} {entry.get('filename', '?')} ({entry.get('name', '?')})"
    for key in REQUIRED - entry.keys():
        err(where, f"missing {key}")
    for key in entry.keys() - REQUIRED - OPTIONAL:
        err(where, f"unknown key {key}")
    if REQUIRED - entry.keys():
        return

    guid = entry["guid"]
    try:
        if str(uuid.UUID(guid, version=4)) != guid:
            raise ValueError
    except (ValueError, AttributeError, TypeError):
        err(where, "guid is not a lowercase uuid4")

    filename = entry["filename"]
    m = FILENAME.match(filename)
    if not m:
        return err(where, "filename must look like win_area_what.ps1 or linux_area_what.sh")
    prefix, ext = m.group(1), "." + m.group(3)
    if (prefix == "win") != (ext == ".ps1"):
        err(where, "win_ scripts are .ps1, linux_ and mac_ scripts are .sh")
    plat, plat_label = PLATFORMS[prefix]
    if entry["supported_platforms"] != [plat]:
        err(where, f"supported_platforms must be [{plat!r}]")
    if entry["shell"] != SHELLS[ext]:
        err(where, f"shell must be {SHELLS[ext]}")
    category = entry["category"]
    cat_plat, _, area = category.partition(" / ")
    if cat_plat != plat_label or area not in AREAS:
        err(where, f"category must be '{plat_label} / <area>', area one of {sorted(AREAS)}")

    if not 3 <= len(entry["name"]) <= 80:
        err(where, "name must be 3-80 characters")
    if not 20 <= len(entry["description"]) <= 300:
        err(where, "description must be 20-300 characters")
    timeout = entry["default_timeout"]
    if not isinstance(timeout, int) or isinstance(timeout, bool) or not 10 <= timeout <= 7200:
        err(where, "default_timeout must be an integer from 10 to 7200")
    if entry.get("args", []):
        err(where, "args must stay empty, inputs are variables")
    if not isinstance(entry.get("run_as_user", False), bool):
        err(where, "run_as_user must be true or false")
    if entry.get("run_as_user") and prefix != "win":
        err(where, "run_as_user is Windows only")
    for item in entry.get("env", []):
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*=.*", item, re.S):
            err(where, f"env entry {item!r} is not KEY=value")

    body = bodies.get(filename)
    if filename not in bodies:
        err(where, "file is missing in scripts/")
    variables = entry.get("variables", [])
    if not isinstance(variables, list) or len(variables) > 30:
        return err(where, "variables must be a list of at most 30")
    seen = set()
    for var in variables:
        check_variable(where, var, body, ext)
        if isinstance(var, dict):
            key = str(var.get("name", "")).upper()
            if key in seen:
                err(where, f"variable {key} is declared twice")
            seen.add(key)


def main(argv):
    full = not argv
    sources = [Path(a) for a in argv] or [
        p for p in [ROOT / "community_scripts.json", *sorted((ROOT / "manifest").glob("*.json"))] if p.exists()
    ]
    bodies = {p.name: check_file(p) for p in sorted(SCRIPTS.iterdir()) if p.is_file()}

    entries = []
    for src in sources:
        try:
            data = json.loads(src.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            err(str(src), f"cannot be read: {e}")
            continue
        if not isinstance(data, list):
            err(str(src), "top level must be a list")
            continue
        for entry in data:
            if isinstance(entry, dict):
                check_entry(entry, src.name, bodies)
                entries.append(entry)
            else:
                err(str(src), "entry is not an object")

    for field, label in (("guid", "guid"), (("category", "name"), "category + name")):
        seen = {}
        for entry in entries:
            key = entry.get(field) if isinstance(field, str) else tuple(entry.get(f) for f in field)
            if key in seen:
                err(entry.get("filename", "?"), f"{label} {key!r} is used twice")
            seen[key] = True

    if full:
        used = {e.get("filename") for e in entries}
        for name in bodies.keys() - used:
            err(f"scripts/{name}", "no manifest entry points at this file")

    for line in errors:
        print(line)
    print(f"{len(entries)} entries, {len(bodies)} files, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
