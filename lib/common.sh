#!/usr/bin/env bash
# Shared helpers: colored logging, interactive prompts, privilege escalation.
# Sourced by install.sh and the other scripts.

# --- logging -----------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'; C_INFO=$'\e[36m'; C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'
else
  C_RESET=; C_INFO=; C_OK=; C_WARN=; C_ERR=
fi

log()  { printf '%s[*]%s %s\n' "$C_INFO" "$C_RESET" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$C_OK"   "$C_RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }
err()  { printf '%s[x]%s %s\n' "$C_ERR"  "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- prompts -----------------------------------------------------------------
# ask VAR "Prompt" "default"  -> reads into VAR, falling back to default.
ask() {
  local __var=$1 __prompt=$2 __default=${3:-} __reply
  if [[ -n $__default ]]; then
    read -r -p "$__prompt [$__default]: " __reply
    __reply=${__reply:-$__default}
  else
    read -r -p "$__prompt: " __reply
  fi
  printf -v "$__var" '%s' "$__reply"
}

# confirm "Question" [Y|N]  -> exit 0 on yes. Second arg sets the default.
confirm() {
  local __q=$1 __def=${2:-N} __reply __hint
  [[ $__def == [Yy] ]] && __hint="[Y/n]" || __hint="[y/N]"
  read -r -p "$__q $__hint: " __reply
  __reply=${__reply:-$__def}
  [[ $__reply == [yY] ]]
}

# --- privilege ---------------------------------------------------------------
SUDO=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  have sudo || die "This installer needs root for package/Docker installation, but 'sudo' is not available. Re-run as root."
  SUDO="sudo"
fi
as_root() { $SUDO "$@"; }
