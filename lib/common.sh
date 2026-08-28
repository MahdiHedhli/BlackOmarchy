#!/usr/bin/env bash
# Shared helpers. Safe to source more than once.

if [[ -n ${BLACKOMARCHY_COMMON_LOADED:-} ]]; then
  return 0 2>/dev/null || true
fi
BLACKOMARCHY_COMMON_LOADED=1

set -euo pipefail

blackomarchy_root() {
  printf '%s' "${BLACKOMARCHY_ROOT:-}"
}

blackomarchy_path() {
  printf '%s%s' "$(blackomarchy_root)" "$1"
}

log() {
  printf '[blackomarchy] %s\n' "$*" >&2
}

err() {
  printf '[blackomarchy] error: %s\n' "$*" >&2
}

die() {
  err "$*"
  exit 1
}

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    die "this command must run as root (use sudo)"
  fi
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

upper_hex() {
  printf '%s' "$1" | tr 'a-f' 'A-F'
}

https_get() {
  local url=$1 dest=$2
  have_cmd curl || die "curl is required"
  curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 20 --retry 2 \
    --output "$dest" "$url" \
    || die "download failed: $url"
}

https_get_stdout() {
  local url=$1
  have_cmd curl || die "curl is required"
  curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 20 --retry 2 "$url" \
    || die "download failed: $url"
}

make_priv_tempdir() {
  local dir old
  old=$(umask)
  umask 077
  dir=$(mktemp -d "${TMPDIR:-/tmp}/blackomarchy.XXXXXX") || { umask "$old"; die "mktemp failed"; }
  umask "$old"
  chmod 700 "$dir"
  printf '%s\n' "$dir"
}

invoking_user() {
  if [[ -n ${SUDO_USER:-} && ${SUDO_USER} != root ]]; then
    printf '%s\n' "$SUDO_USER"
    return
  fi
  printf '%s\n' "${USER:-$(id -un)}"
}

invoking_home() {
  local user
  user=$(invoking_user)
  if have_cmd getent; then
    getent passwd "$user" | cut -d: -f6
    return
  fi
  printf '%s\n' "/home/$user"
}

load_paths() {
  local here candidate
  here=$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)
  for candidate in \
    "${here}/config/paths.conf" \
    "${here}/../config/paths.conf" \
    "${BLACKOMARCHY_SHARE_DIR:-/usr/local/share/blackomarchy}/config/paths.conf" \
    "/usr/local/share/blackomarchy/config/paths.conf"
  do
    if [[ -f $candidate ]]; then
      # shellcheck disable=SC1090
      source "$candidate"
      return 0
    fi
  done
  BLACKOMARCHY_VERSION="${BLACKOMARCHY_VERSION:-0.1.0}"
  BLACKOMARCHY_STATE_DIR="${BLACKOMARCHY_STATE_DIR:-/var/lib/blackomarchy}"
  BLACKOMARCHY_SHARE_DIR="${BLACKOMARCHY_SHARE_DIR:-/usr/local/share/blackomarchy}"
  BLACKOMARCHY_BIN_DIR="${BLACKOMARCHY_BIN_DIR:-/usr/local/bin}"
  BLACKARCH_STRAP_URL="${BLACKARCH_STRAP_URL:-https://blackarch.org/strap.sh}"
  BLACKARCH_DOWNLOADS_URL="${BLACKARCH_DOWNLOADS_URL:-https://blackarch.org/downloads.html}"
  BLACKARCH_KEYRING_BASE="${BLACKARCH_KEYRING_BASE:-https://www.blackarch.org/keyring}"
}

state_dir() {
  blackomarchy_path "${BLACKOMARCHY_STATE_DIR}"
}

ensure_state_dir() {
  install -d -m 0755 "$(state_dir)" \
    "$(state_dir)/backups" \
    "$(state_dir)/baseline"
}

append_manifest_line() {
  local file
  file="$(state_dir)/manifest"
  install -d -m 0755 "$(state_dir)"
  if [[ -f $file ]] && grep -Fxq "$1" "$file"; then
    return 0
  fi
  printf '%s\n' "$1" >>"$file"
}

append_exclusion() {
  local file
  file="$(state_dir)/exclusions"
  install -d -m 0755 "$(state_dir)"
  printf '%s\n' "$1" >>"$file"
}
