#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/blackarch.sh"

tmp=$(make_priv_tempdir)
trap 'rm -rf "$tmp"' EXIT

# On Linux, exercise the same /dev/tty fallback used by current upstream.
if command -v setsid >/dev/null 2>&1; then
  answer=$(setsid --wait sh -c 'read answer </dev/tty 2>/dev/null || answer=n; printf "%s" "$answer"' </dev/null 2>/dev/null)
  [[ $answer == n ]] || { echo 'upstream upgrade prompt was not declined'; exit 1; }
fi

# Exercise the wrapper without executing downloaded code or touching the host.
export BLACKOMARCHY_ROOT="$tmp/host"
export BLACKOMARCHY_STATE_DIR=/state
BLACKARCH_STRAP_URL=https://example.invalid/strap.sh
BLACKARCH_MIRROR_BASE=https://example.invalid/repo
ensure_state_dir
fetch_official_strap_sha1() { printf 'synthetic-hash\n'; }
https_get() { printf 'synthetic download' >"$2"; }
verify_sha1_file() { [[ $1 == synthetic-hash ]]; }
parse_keyring_package_filename() { printf 'blackarch-keyring-20251011-2-any.pkg.tar.zst\n'; }
verify_keyring_package() { printf '4345771566D76038C7FEB43863EC0ADBEA87E4E3\n'; }
snapshot_packages() { printf 'omarchy 4.0.4-1\n'; }
keyring_files_match() { return 0; }
require_omarchy_repos() { return 0; }
assert_single_blackarch() { return 0; }
repo_enabled() { [[ $1 == blackarch ]]; }
fail_restore() { die "$1"; }
setsid() {
  [[ $# == 3 && $1 == --wait && $2 == sh && $3 == */strap.sh ]] || exit 1
  [[ -z ${OMARCHY_ALLOW_DIRECT_PACMAN:-} && -z ${OMARCHY_UPDATE_PACMAN:-} ]] || exit 1
  printf 'called\n' >"$tmp/executed"
}
export OMARCHY_ALLOW_DIRECT_PACMAN=1 OMARCHY_UPDATE_PACMAN=1
run_official_strap
[[ -s $tmp/executed ]] || exit 1
[[ $(cat "$(state_dir)/keyring-package") == blackarch-keyring-20251011-2-any.pkg.tar.zst ]] || exit 1

# Signature failures must prevent script execution, even in a conditional call.
rm "$tmp/executed"
(
  verify_keyring_package() { return 1; }
  if (run_official_strap) >"$tmp/rejection.log" 2>&1; then
    echo 'failed signature accepted'
    exit 1
  fi
)
[[ ! -e $tmp/executed ]] || { echo 'script ran before signature verification'; exit 1; }
echo 'ok verified strap ordering and noninteractive session'
