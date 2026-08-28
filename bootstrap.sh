#!/usr/bin/env bash
# Black omARCHy v0.1 — additive BlackArch layer for Omarchy.
# Clone, read, then run. Do not pipe this file from the network into sudo.

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
load_paths
# shellcheck disable=SC1091
source "$HERE/lib/detect.sh"
# shellcheck disable=SC1091
source "$HERE/lib/pacman.sh"
# shellcheck disable=SC1091
source "$HERE/lib/backup.sh"
# shellcheck disable=SC1091
source "$HERE/lib/baseline.sh"
# shellcheck disable=SC1091
source "$HERE/lib/blackarch.sh"
# shellcheck disable=SC1091
source "$HERE/lib/packages.sh"
# shellcheck disable=SC1091
source "$HERE/lib/install_cli.sh"

unset OMARCHY_ALLOW_DIRECT_PACMAN OMARCHY_UPDATE_PACMAN

require_root
detect_host
ensure_state_dir
create_backup >/dev/null
if [[ ! -f $(baseline_dir)/omarchy-version ]]; then
  capture_baseline
fi

log "Omarchy $(omarchy_version_string | tr '\n' ' ')"
ensure_blackarch_repo
install_profile core
install_cli

if ! baseline_compare; then
  die "Omarchy baseline drifted after install; layer is present, run: sudo ./uninstall.sh"
fi

log "done"
log "BlackArch repository: enabled"
log "default profile: core"
log "CLI: blackomarchy status | verify | profiles"
log "Omarchy desktop, update path, and configuration were not modified"
log "keep using: omarchy update"
