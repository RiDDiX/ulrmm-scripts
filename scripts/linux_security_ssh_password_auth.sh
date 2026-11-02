#!/bin/sh
# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Shows, disables or enables SSH password login. Disabling needs a usable authorized key for root or a sudo/wheel user.
# Variables: STATE (status, disable, enable; default status).
# Exit codes: 0 ok (status: password login off), 1 failed or status shows password login on, 3 bad input, no sshd, or unsafe to disable.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

command -v awk >/dev/null 2>&1 || { echo "awk not found: install gawk"; exit 3; }
set -f

st=${STATE:-status}
case $st in status | disable | enable) ;; *) echo "STATE must be status, disable or enable"; exit 3 ;; esac
command -v sshd >/dev/null 2>&1 || { echo "sshd is not installed"; exit 3; }
main=/etc/ssh/sshd_config
[ -f "$main" ] || { echo "$main not found"; exit 3; }
tmp=$(mktemp -d) || exit 3
trap 'rm -rf "$tmp"' EXIT
if command -v ssh-keygen >/dev/null 2>&1; then ssh-keygen -q -t ed25519 -N '' -f "$tmp/k" >/dev/null 2>&1; fi
# Debian's sshd -T refuses to run while sshd is stopped and its privsep directory is gone
mkdir -p /run/sshd 2>/dev/null

conf() { sshd -T -f "$main" "$@" 2>/dev/null || sshd -T -f "$main" -h "$tmp/k" "$@" 2>/dev/null; }
eff() { conf | awk -v k="$1" '$1==k {print $2; exit}'; }
# Password login is on when PasswordAuthentication is yes or PAM answers keyboard-interactive.
pwon() { [ "$(eff passwordauthentication)" = yes ] || { [ "$(eff kbdinteractiveauthentication)" = yes ] && [ "$(eff usepam)" = yes ]; }; }
cur=$(eff passwordauthentication)
[ -n "$cur" ] || { echo "Cannot read the effective sshd configuration: $(sshd -T -f "$main" 2>&1 | head -1)"; exit 3; }
if [ "$st" = status ]; then
  echo "SSH password authentication: $cur, keyboard-interactive: $(eff kbdinteractiveauthentication), PAM: $(eff usepam)"
  pwon && exit 1 || exit 0
fi
want=yes
[ "$st" = disable ] && want=no
if { [ "$st" = enable ] && [ "$cur" = yes ]; } || { [ "$st" = disable ] && ! pwon; }; then
  echo "SSH password authentication already $want"
  exit 0
fi

# shellcheck disable=SC2254
# Succeeds when user $1 can log in with a plain key line from an authorized_keys file sshd reads for them.
keyuser() {
  ku=$1
  ent=$(getent passwd "$ku") || return 1
  case $(printf '%s' "$ent" | cut -d: -f7) in */nologin | */false | '') return 1 ;; esac
  home=$(printf '%s' "$ent" | cut -d: -f6)
  uid=$(printf '%s' "$ent" | cut -d: -f3)
  sp=$(awk -F: -v u="$ku" '$1==u' /etc/shadow 2>/dev/null)
  exp=$(printf '%s' "$sp" | cut -d: -f8)
  case $exp in '' | *[!0-9]*) ;; *) [ "$exp" -gt $(($(date +%s) / 86400)) ] || return 1 ;; esac
  case $(printf '%s' "$sp" | cut -d: -f2) in '!'*) [ "$(eff usepam)" = yes ] || return 1 ;; esac
  conf -C "user=$ku,host=localhost,addr=127.0.0.1" >"$tmp/u" || return 1
  v() { awk -v k="$1" '$1==k {sub(/^[^ ]+ /, ""); print}' "$tmp/u"; }
  [ "$(v pubkeyauthentication)" = yes ] || return 1
  if [ "$ku" = root ]; then case $(v permitrootlogin) in yes | prohibit-password | without-password) ;; *) return 1 ;; esac; fi
  am=
  for m in $(v authenticationmethods); do case $m in any | publickey) am=1 ;; esac; done
  [ -n "$am" ] || return 1
  grp=" $(id -Gn "$ku" 2>/dev/null) "
  for p in $(v denyusers); do case $p in *@*) return 1 ;; esac; case $ku in $p) return 1 ;; esac; done
  for p in $(v denygroups); do for g in $grp; do case $g in $p) return 1 ;; esac; done; done
  if [ -n "$(v allowusers)" ]; then
    hit=
    for p in $(v allowusers); do case $p in *@*) ;; *) case $ku in $p) hit=1 ;; esac ;; esac; done
    [ -n "$hit" ] || return 1
  fi
  if [ -n "$(v allowgroups)" ]; then
    hit=
    for p in $(v allowgroups); do for g in $grp; do case $g in $p) hit=1 ;; esac; done; done
    [ -n "$hit" ] || return 1
  fi
  strict=$(v strictmodes)
  for akf in $(v authorizedkeysfile); do
    [ "$akf" = none ] && continue
    f=$(awk -v p="$akf" -v h="$home" -v u="$ku" -v i="$uid" 'BEGIN {
      while ((n = index(p, "%")) > 0) { c = substr(p, n + 1, 1); o = o substr(p, 1, n - 1) (c == "h" ? h : c == "u" ? u : c == "U" ? i : c == "%" ? "%" : "%" c); p = substr(p, n + 2) }
      print o p }')
    case $f in /*) ;; *) f=$home/$f ;; esac
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    grep -Eq '^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp[0-9]+|sk-[a-z0-9@.-]+) ' "$f" || continue
    # StrictModes: sshd ignores the file when it or a parent is not owned by root or the user, or is group/world writable
    if [ "$strict" != no ]; then
      p=$f bad=
      while [ -n "$p" ]; do
        # shellcheck disable=SC2046
        set -- $(stat -L -c '%u %a' "$p" 2>/dev/null)
        { [ "${1:-x}" = 0 ] || [ "${1:-x}" = "$uid" ]; } && [ $((0${2:-777} & 022)) -eq 0 ] || { bad=1; break; }
        [ "$p" = / ] && break
        p=$(dirname "$p")
      done
      [ -z "$bad" ] || continue
    fi
    return 0
  done
  return 1
}

if [ "$st" = disable ]; then
  ok=
  members=
  for g in sudo wheel admin; do
    members="$members $(getent group "$g" 2>/dev/null | cut -d: -f4 | tr ',' ' ')"
  done
  for u in root $members; do
    case " $ok " in *" $u "*) continue ;; esac
    keyuser "$u" && ok="$ok $u"
  done
  if [ -z "$ok" ]; then
    echo "Refusing to disable password login: neither root nor a sudo/wheel member can log in with an authorized key"
    echo "(checked: login shell, locked or expired account, PubkeyAuthentication, PermitRootLogin, AuthenticationMethods,"
    echo " Allow/DenyUsers, Allow/DenyGroups, AuthorizedKeysFile and StrictModes ownership and modes)"
    exit 3
  fi
  echo "Key login available for:$ok"
fi

reload() {
  if [ -d /run/systemd/system ]; then
    systemctl reload ssh >/dev/null 2>&1 || systemctl reload sshd >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1
  elif command -v rc-service >/dev/null 2>&1; then
    rc-service sshd reload >/dev/null 2>&1
  else
    # only the listener: per-connection sshd processes die on SIGHUP
    pf=$(eff pidfile)
    [ -s "$pf" ] && kill -HUP "$(cat "$pf")" 2>/dev/null
  fi
}
done_ok() { [ "$(eff passwordauthentication)" = "$want" ] && { [ "$st" = enable ] || ! pwon; }; }
chk() { sshd -t -f "$main" 2>"$tmp/e" || sshd -t -f "$main" -h "$tmp/k" 2>"$tmp/e"; }
running() { pgrep -x sshd >/dev/null 2>&1; }

dropin=/etc/ssh/sshd_config.d/00-ulrmm-password-auth.conf
write_dropin() {
  printf 'PasswordAuthentication %s\n' "$want" >"$dropin"
  if [ "$st" = disable ] && [ -n "$(eff kbdinteractiveauthentication)" ]; then
    printf 'KbdInteractiveAuthentication no\n' >>"$dropin"
  fi
}
used=
if grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/' "$main" && [ -d /etc/ssh/sshd_config.d ]; then
  prev=
  [ -f "$dropin" ] && cp -p "$dropin" "$tmp/dropin.bak" && prev=1
  write_dropin
  if chk && done_ok; then
    used="drop-in $dropin"
  else
    if [ -n "$prev" ]; then cp -p "$tmp/dropin.bak" "$dropin"; else rm -f "$dropin"; fi
  fi
fi
if [ -z "$used" ]; then
  cp -p "$main" "$tmp/main.bak" || exit 1
  [ -f "$main.ulrmm.bak" ] || cp -p "$main" "$main.ulrmm.bak"
  {
    printf 'PasswordAuthentication %s\n' "$want"
    [ "$st" = disable ] && [ -n "$(eff kbdinteractiveauthentication)" ] && printf 'KbdInteractiveAuthentication no\n'
    awk -v st="$st" 'tolower($1) == "match" {m = 1} !m && (tolower($1) == "passwordauthentication" || st == "disable" && tolower($1) == "kbdinteractiveauthentication") {$0 = "#" $0} {print}' "$main"
  } >"$tmp/new"
  # replace by rename so a killed run never leaves a truncated sshd_config
  put() { cp -p "$main" "$main.ulrmm.new" && cat "$1" >"$main.ulrmm.new" && mv -f "$main.ulrmm.new" "$main"; }
  put "$tmp/new" || { rm -f "$main.ulrmm.new"; echo "Writing $main failed"; exit 1; }
  if chk && done_ok; then
    used="$main (backup $main.ulrmm.bak)"
  else
    put "$tmp/main.bak"
    echo "sshd rejected the change, original restored: $(head -1 "$tmp/e")"
    exit 1
  fi
fi
if running; then
  reload || { echo "SSH password authentication set to $want via $used, but reloading sshd failed: restart it"; exit 1; }
  sleep 1
  running || { echo "sshd is not running after reload"; exit 1; }
  echo "SSH password authentication set to $want via $used, sshd reloaded"
else
  echo "SSH password authentication set to $want via $used (sshd not running, applied on next start)"
fi
if [ "$st" = disable ] && awk 'FNR == 1 {m = 0} tolower($1) == "match" {m = 1} m && tolower($1) ~ /^(passwordauthentication|kbdinteractiveauthentication)$/ && tolower($2) == "yes" {f = 1} END {exit !f}' "$main" /etc/ssh/sshd_config.d/*.conf 2>/dev/null; then
  echo "Note: a Match block still allows passwords for some users or addresses"
fi
exit 0
