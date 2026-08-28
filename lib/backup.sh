#!/usr/bin/env bash
# Timestamped backups of pacman configuration.

if [[ -n ${BLACKOMARCHY_BACKUP_LOADED:-} ]]; then
  return 0 2>/dev/null || true
fi
BLACKOMARCHY_BACKUP_LOADED=1

current_backup_dir() {
  printf '%s' "${BLACKOMARCHY_CURRENT_BACKUP:-}"
}

create_backup() {
  local stamp dest conf
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  dest="$(state_dir)/backups/${stamp}"
  install -d -m 0755 "$dest"
  conf=$(pacman_conf_file)
  cp -a "$conf" "$dest/pacman.conf"
  if [[ -f $(blackomarchy_path /etc/pacman.d/mirrorlist) ]]; then
    cp -a "$(blackomarchy_path /etc/pacman.d/mirrorlist)" "$dest/mirrorlist"
  fi
  repo_list >"$dest/repo-list" 2>/dev/null || true
  omarchy_server_line >"$dest/omarchy-server" 2>/dev/null || true
  printf '%s\n' "$dest" >"$(state_dir)/latest-backup"
  BLACKOMARCHY_CURRENT_BACKUP=$dest
  log "backup written to $dest"
  printf '%s\n' "$dest"
}

restore_pacman_conf_from_current_backup() {
  local dest conf
  dest=$(current_backup_dir)
  [[ -n $dest && -f $dest/pacman.conf ]] || return 1
  conf=$(pacman_conf_file)
  cp -a "$dest/pacman.conf" "$conf"
  log "restored pacman.conf from this run's backup"
}

fail_restore() {
  restore_pacman_conf_from_current_backup || true
  die "$1"
}
