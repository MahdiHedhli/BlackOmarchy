#!/usr/bin/env bash
# Reverse Black omARCHy-owned additions. Does not roll Omarchy backward.

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
if [[ -f "$HERE/lib/common.sh" ]]; then
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
  source "$HERE/lib/install_cli.sh"
else
  # shellcheck disable=SC1091
  source /usr/local/share/blackomarchy/lib/common.sh
  load_paths
  # shellcheck disable=SC1091
  source /usr/local/share/blackomarchy/lib/detect.sh
  # shellcheck disable=SC1091
  source /usr/local/share/blackomarchy/lib/pacman.sh
  # shellcheck disable=SC1091
  source /usr/local/share/blackomarchy/lib/backup.sh
  # shellcheck disable=SC1091
  source /usr/local/share/blackomarchy/lib/install_cli.sh
fi

require_root
unset OMARCHY_ALLOW_DIRECT_PACMAN OMARCHY_UPDATE_PACMAN

manifest=$(state_dir)/manifest
remove_failed=0
if [[ -f $manifest ]]; then
  while IFS=$'\t' read -r kind name _rest; do
    if [[ $kind == package ]]; then
      remove_package_if_safe "$name" || remove_failed=1
    fi
  done < <(tac "$manifest")
fi

remove_pre_refresh_hook

conf=$(pacman_conf_file)
backup=""
if [[ -f $(state_dir)/latest-backup ]]; then
  backup=$(cat "$(state_dir)/latest-backup")
fi

if [[ -n $backup && -f $backup/pacman.conf ]]; then
  current_non=$(mktemp)
  backup_non=$(mktemp)
  strip_blackarch_stanza <"$conf" >"$current_non"
  strip_blackarch_stanza <"$backup/pacman.conf" >"$backup_non"
  if cmp -s "$current_non" "$backup_non"; then
    cp -a "$backup/pacman.conf" "$conf"
    log "pacman.conf restored from backup (non-blackarch bytes still matched)"
  else
    remove_blackarch_stanza_from_file
    log "removed [blackarch] stanza without restoring an older Omarchy config"
  fi
  rm -f "$current_non" "$backup_non"
else
  remove_blackarch_stanza_from_file
fi

if [[ -x /usr/local/sbin/blackomarchy-apply-login-branding ]]; then
  /usr/local/sbin/blackomarchy-apply-login-branding restore || true
fi
if [[ -f /etc/systemd/system/blackomarchy-sddm-branding.service ]]; then
  systemctl disable --now blackomarchy-sddm-branding.service >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/blackomarchy-sddm-branding.service
  systemctl daemon-reload || true
fi
rm -rf /usr/local/share/blackomarchy
rm -f /usr/local/bin/blackomarchy \
  /usr/local/bin/blackomarchy-update \
  /usr/local/sbin/blackomarchy-reappend-repo \
  /usr/local/sbin/blackomarchy-apply-login-branding
# Keep blackomarchy-omarchy-install and the seeded source tree so
# Install > Black omARCHy still works, same as other optional apps.
if [[ $remove_failed -ne 0 ]]; then
  err "some manifest packages could not be removed"
  exit 1
fi
# Keep /var/lib/blackomarchy backups; remove live pointers that would claim we are installed.
rm -f "$(state_dir)/version"

log "Black omARCHy removed. Pacman keyring files were left in place."
log "Omarchy-owned files were not modified."
log "Re-add from the Omarchy menu: Install > Black omARCHy"
