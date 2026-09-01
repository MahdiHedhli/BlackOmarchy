#!/usr/bin/env bash
# Install the thin CLI and profiles into /usr/local.

if [[ -n ${BLACKOMARCHY_INSTALL_CLI_LOADED:-} ]]; then
  return 0 2>/dev/null || true
fi
BLACKOMARCHY_INSTALL_CLI_LOADED=1

project_root_from_lib() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

as_owner() {
  local owner=$1
  shift
  if [[ -n $owner && $owner != root ]] && have_cmd sudo && [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    sudo -u "$owner" "$@"
  else
    "$@"
  fi
}

share_file() {
  local name=$1 root
  root=$(project_root_from_lib)
  if [[ -f $root/share/$name ]]; then
    printf '%s\n' "$root/share/$name"
    return
  fi
  if [[ -f ${BLACKOMARCHY_SHARE_DIR}/share/$name ]]; then
    printf '%s\n' "${BLACKOMARCHY_SHARE_DIR}/share/$name"
    return
  fi
  printf '%s\n' "${BLACKOMARCHY_SHARE_DIR}/$name"
}

seed_src_tree() {
  local home owner dest root
  home=$(invoking_home)
  owner=$(invoking_user)
  dest="$home/.local/share/blackomarchy-src"
  root=$(project_root_from_lib)
  [[ -n $home && $home != /root && -d $root ]] || return 0
  as_owner "$owner" mkdir -p "$dest"
  if have_cmd rsync; then
    rsync -a --exclude private --exclude .git "$root/" "$dest/"
  else
    cp -a "$root"/. "$dest"/
    rm -rf "$dest/private" "$dest/.git"
  fi
  if [[ -n $owner && $owner != root ]]; then
    chown -R "$owner:$owner" "$dest" 2>/dev/null || true
  fi
}

install_omarchy_integration() {
  local home owner dest src
  home=$(invoking_home)
  owner=$(invoking_user)
  [[ -n $home && $home != /root && $home != / ]] || return 0

  seed_src_tree

  as_owner "$owner" mkdir -p \
    "$home/.config/omarchy/hooks/pre-refresh-pacman.d" \
    "$home/.config/omarchy/hooks/post-update.d" \
    "$home/.config/omarchy/extensions"

  src=$(share_file hooks/blackomarchy-blackarch.sh)
  dest="$home/.config/omarchy/hooks/pre-refresh-pacman.d/blackomarchy-blackarch.sh"
  if [[ -f $src ]]; then
    install -m 0755 "$src" "$dest"
    [[ -n $owner ]] && chown "$owner:$owner" "$dest" 2>/dev/null || true
    append_manifest_line "file	${dest}	hook"
  fi

  src=$(share_file hooks/blackomarchy-post-update.sh)
  dest="$home/.config/omarchy/hooks/post-update.d/blackomarchy-post-update.sh"
  if [[ -f $src ]]; then
    install -m 0755 "$src" "$dest"
    [[ -n $owner ]] && chown "$owner:$owner" "$dest" 2>/dev/null || true
    append_manifest_line "file	${dest}	hook"
  fi

  src=$(share_file omarchy-menu-blackomarchy.jsonc)
  local merger target
  merger=$(share_file merge-omarchy-menu.py)
  target="$home/.config/omarchy/extensions/omarchy-menu.jsonc"
  if [[ -f $src && -f $merger ]] && have_cmd python3; then
    as_owner "$owner" python3 "$merger" "$src" "$target" install
    [[ -n $owner ]] && chown "$owner:$owner" "$target" 2>/dev/null || true
    append_manifest_line "file	${target}	menu"
    if have_cmd omarchy; then
      as_owner "$owner" omarchy menu refresh >/dev/null 2>&1 || true
    fi
  fi

  install_agent_skills
}

install_agent_skills() {
  local home owner root src dest_root skill name
  home=$(invoking_home)
  owner=$(invoking_user)
  root=$(project_root_from_lib)
  src="$root/share/skills"
  [[ -n $home && $home != /root && -d $src ]] || return 0
  for dest_root in "$home/.grok/skills" "$home/.claude/skills" "$home/.agents/skills"; do
    as_owner "$owner" mkdir -p "$dest_root"
    for skill in "$src"/*; do
      [[ -d $skill ]] || continue
      name=$(basename "$skill")
      as_owner "$owner" mkdir -p "$dest_root/$name"
      cp -a "$skill"/. "$dest_root/$name"/
      if [[ -n $owner && $owner != root ]]; then
        chown -R "$owner:$owner" "$dest_root/$name" 2>/dev/null || true
      fi
      append_manifest_line "file	${dest_root}/${name}	skill"
    done
  done
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
  install -d -m 0755 "$dest_share/share/hooks"
  if [[ -d $root/share/hooks ]]; then
    install -m 0755 "$root"/share/hooks/* "$dest_share/share/hooks/"
  fi
  for f in blackomarchy-reappend-repo blackomarchy-omarchy-install blackomarchy-apply-login-branding merge-omarchy-menu.py omarchy-menu-blackomarchy.jsonc; do
    if [[ -f $root/share/$f ]]; then
      install -m 0755 "$root/share/$f" "$dest_share/share/$f"
      install -m 0755 "$root/share/$f" "$dest_share/$f"
    fi
  done
  if [[ -d $root/share/branding ]]; then
    install -d -m 0755 "$dest_share/share/branding"
    if [[ -f $root/share/branding/login-logo.png ]]; then
      install -m 0644 "$root/share/branding/login-logo.png" \
        "$dest_share/share/branding/login-logo.png"
    fi
  fi
  if [[ -d $root/share/skills ]]; then
    install -d -m 0755 "$dest_share/share/skills"
    cp -a "$root/share/skills"/. "$dest_share/share/skills"/
  fi
  install -m 0755 "$root/blackomarchy" "$dest_bin/blackomarchy"
  install -m 0755 "$root/bootstrap.sh" "$dest_share/bootstrap.sh"
  install -m 0755 "$root/uninstall.sh" "$dest_share/uninstall.sh"
  if [[ -f $root/share/blackomarchy-omarchy-install ]]; then
    install -m 0755 "$root/share/blackomarchy-omarchy-install" \
      "$dest_bin/blackomarchy-omarchy-install"
    append_manifest_line "file	${dest_bin}/blackomarchy-omarchy-install	helper"
  fi
  if [[ -f $root/share/blackomarchy-reappend-repo ]]; then
    install -m 0755 "$root/share/blackomarchy-reappend-repo" \
      /usr/local/sbin/blackomarchy-reappend-repo
    append_manifest_line "file	/usr/local/sbin/blackomarchy-reappend-repo	helper"
  fi
  if [[ -f $root/share/blackomarchy-apply-login-branding ]]; then
    install -m 0755 "$root/share/blackomarchy-apply-login-branding" \
      /usr/local/sbin/blackomarchy-apply-login-branding
    append_manifest_line "file	/usr/local/sbin/blackomarchy-apply-login-branding	helper"
  fi
  printf '%s\n' "$BLACKOMARCHY_VERSION" >"$(state_dir)/version"
  append_manifest_line "file	${dest_bin}/blackomarchy	cli"
  append_manifest_line "file	${dest_share}	share"
  install_omarchy_integration
  if [[ -x /usr/local/sbin/blackomarchy-apply-login-branding ]]; then
    /usr/local/sbin/blackomarchy-apply-login-branding apply || true
  fi
  log "CLI installed to $dest_bin/blackomarchy"
}

remove_pre_refresh_hook() {
  local home owner merger src target
  home=$(invoking_home)
  owner=$(invoking_user)
  rm -f "$home/.config/omarchy/hooks/pre-refresh-pacman.d/blackomarchy-blackarch.sh" 2>/dev/null || true
  rm -f "$home/.config/omarchy/hooks/post-update.d/blackomarchy-post-update.sh" 2>/dev/null || true
  merger=$(share_file merge-omarchy-menu.py)
  src=$(share_file omarchy-menu-blackomarchy.jsonc)
  target="$home/.config/omarchy/extensions/omarchy-menu.jsonc"
  if [[ -f $merger && -f $src ]] && have_cmd python3; then
    as_owner "$owner" python3 "$merger" "$src" "$target" uninstall || true
  fi
  local dest_root name
  for dest_root in "$home/.grok/skills" "$home/.claude/skills" "$home/.agents/skills"; do
    for name in black-omarchy black-omarchy-pentest; do
      rm -rf "$dest_root/$name"
    done
  done
}
