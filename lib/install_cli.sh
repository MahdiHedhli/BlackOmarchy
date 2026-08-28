#!/usr/bin/env bash
# Install the thin CLI and profiles into /usr/local.

if [[ -n ${BLACKOMARCHY_INSTALL_CLI_LOADED:-} ]]; then
  return 0 2>/dev/null || true
fi
BLACKOMARCHY_INSTALL_CLI_LOADED=1

project_root_from_lib() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

install_pre_refresh_hook() {
  local home dest src owner
  home=$(invoking_home)
  owner=$(invoking_user)
  [[ -n $home && $home != /root && $home != / ]] || return 0
  if [[ ! -d $home/.config/omarchy ]]; then
    log "skipping pre-refresh hook; $home/.config/omarchy does not exist"
    return 0
  fi
  dest="$home/.config/omarchy/hooks/pre-refresh-pacman.d"
  if [[ -n $owner ]] && have_cmd sudo; then
    sudo -u "$owner" mkdir -p "$dest"
  else
    install -d -m 0755 "$dest"
  fi
  src=$(project_root_from_lib)/share/hooks/blackomarchy-blackarch.sh
  if [[ ! -f $src ]]; then
    src="${BLACKOMARCHY_SHARE_DIR}/share/hooks/blackomarchy-blackarch.sh"
  fi
  [[ -f $src ]] || return 0
  install -m 0755 "$src" "$dest/blackomarchy-blackarch.sh"
  if have_cmd chown && [[ -n $owner ]]; then
    chown "$owner:$owner" "$dest/blackomarchy-blackarch.sh" 2>/dev/null || true
  fi
  append_manifest_line "file	${dest}/blackomarchy-blackarch.sh	hook"
}

install_cli() {
  local root dest_share dest_bin
  root=$(project_root_from_lib)
  dest_share=${BLACKOMARCHY_SHARE_DIR}
  dest_bin=${BLACKOMARCHY_BIN_DIR}
  install -d -m 0755 "$dest_share/lib" "$dest_share/packages" "$dest_share/config" \
    "$dest_share/share/hooks" "$dest_bin"
  install -m 0644 "$root"/lib/*.sh "$dest_share/lib/"
  install -m 0644 "$root"/packages/*.txt "$dest_share/packages/"
  install -m 0644 "$root/config/paths.conf" "$dest_share/config/"
  if [[ -f $root/share/hooks/blackomarchy-blackarch.sh ]]; then
    install -m 0755 "$root/share/hooks/blackomarchy-blackarch.sh" \
      "$dest_share/share/hooks/"
  fi
  install -m 0755 "$root/blackomarchy" "$dest_bin/blackomarchy"
  if [[ -f $root/share/blackomarchy-reappend-repo ]]; then
    install -m 0755 "$root/share/blackomarchy-reappend-repo" \
      /usr/local/sbin/blackomarchy-reappend-repo
    append_manifest_line "file	/usr/local/sbin/blackomarchy-reappend-repo	helper"
  fi
  printf '%s\n' "$BLACKOMARCHY_VERSION" >"$(state_dir)/version"
  append_manifest_line "file	${dest_bin}/blackomarchy	cli"
  append_manifest_line "file	${dest_share}	share"
  install_pre_refresh_hook
  log "CLI installed to $dest_bin/blackomarchy"
}

remove_pre_refresh_hook() {
  local home
  home=$(invoking_home)
  rm -f "$home/.config/omarchy/hooks/pre-refresh-pacman.d/blackomarchy-blackarch.sh" 2>/dev/null || true
}
