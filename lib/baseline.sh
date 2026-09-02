#!/usr/bin/env bash
# Sanitized Omarchy baseline capture and compare.

if [[ -n ${BLACKOMARCHY_BASELINE_LOADED:-} ]]; then
  return 0 2>/dev/null || true
fi
BLACKOMARCHY_BASELINE_LOADED=1

baseline_dir() {
  printf '%s' "$(state_dir)/baseline"
}

hash_if_exists() {
  local path=$1
  if [[ -e $path ]]; then
    if have_cmd sha256sum; then
      sha256sum "$path"
    else
      shasum -a 256 "$path"
    fi
  fi
}

hash_tree() {
  local root=$1
  [[ -d $root ]] || return 0
  find "$root" -type f -print0 2>/dev/null | sort -z | xargs -0 -n 1 sha256sum 2>/dev/null \
    || find "$root" -type f -print0 2>/dev/null | sort -z | xargs -0 -n 1 shasum -a 256
}

# Files this layer writes under ~/.config/omarchy. Omarchy owns the
# directories; we own these drop-ins and must not treat them as drift.
owned_omarchy_user_path_regex() {
  printf '%s' 'hooks/(pre-refresh-pacman|post-update|post-boot)\.d/blackomarchy|/extensions/omarchy-menu\.jsonc'
}

hash_omarchy_user_tree() {
  local home=$1
  [[ -d $home/.config/omarchy ]] || return 0
  hash_tree "$home/.config/omarchy" | grep -vE "$(owned_omarchy_user_path_regex)" || true
}

omarchy_owned_hash_targets() {
  blackomarchy_path /usr/share/omarchy/version
  blackomarchy_path /usr/share/libalpm/hooks/00-omarchy-update-guard.hook
  blackomarchy_path /etc/profile.d/omarchy.sh
}

capture_baseline() {
  local dest user home
  dest=$(baseline_dir)
  install -d -m 0755 "$dest"
  uname -m >"$dest/uname"
  if [[ -r $(os_release_file) ]]; then
    cp "$(os_release_file)" "$dest/os-release"
  fi
  omarchy_version_string >"$dest/omarchy-version"
  cp "$(pacman_conf_file)" "$dest/pacman.conf"
  repo_list >"$dest/repo-list" 2>/dev/null || true
  omarchy_server_line >"$dest/omarchy-server" 2>/dev/null || true
  pacman -Qqe >"$dest/explicit-packages" 2>/dev/null || true
  pacman -Q omarchy omarchy-settings omarchy-keyring >"$dest/omarchy-packages" 2>/dev/null || true
  : >"$dest/hashes.tsv"
  local p
  for p in $(omarchy_owned_hash_targets); do
    hash_if_exists "$p" >>"$dest/hashes.tsv" || true
  done
  if [[ -d $(blackomarchy_path /usr/share/omarchy) ]]; then
    hash_tree "$(blackomarchy_path /usr/share/omarchy)" >"$dest/omarchy-tree.hashes" || true
  fi
  user=$(invoking_user)
  home=$(invoking_home)
  if [[ -n $home && -d $home/.config/hypr ]]; then
    hash_tree "$home/.config/hypr" >"$dest/hypr.hashes" || true
  fi
  if [[ -n $home && -d $home/.config/omarchy ]]; then
    hash_omarchy_user_tree "$home" >"$dest/omarchy-user.hashes" || true
  fi
  log "baseline captured"
}

refresh_baseline_if_omarchy_moved() {
  local dest
  dest=$(baseline_dir)
  if [[ ! -f $dest/omarchy-packages ]]; then
    capture_baseline
    return
  fi
  if ! cmp -s "$dest/omarchy-packages" <(pacman -Q omarchy omarchy-settings omarchy-keyring 2>/dev/null || true); then
    log "Omarchy packages changed since last baseline (expected after omarchy update); recapturing"
    capture_baseline
  fi
}

# Hyprland / ~/.config/omarchy can change during core package install
# (Omarchy pacman hooks, first-run, our menu/hook overlays). Recapture
# those lists after install so verify does not treat that as layer damage.
refresh_user_config_hashes() {
  local dest home
  dest=$(baseline_dir)
  home=$(invoking_home)
  [[ -d $dest ]] || return 0
  if [[ -n $home && -d $home/.config/hypr ]]; then
    hash_tree "$home/.config/hypr" >"$dest/hypr.hashes" || true
  fi
  if [[ -n $home && -d $home/.config/omarchy ]]; then
    hash_omarchy_user_tree "$home" >"$dest/omarchy-user.hashes" || true
  fi
}

hash_paths_only() {
  awk '{ $1=""; sub(/^ /, ""); print }' "$1" 2>/dev/null | sort
}

log_hash_drift() {
  local label=$1 old=$2 new=$3
  local added removed
  added=$(comm -13 <(hash_paths_only "$old") <(hash_paths_only "$new") || true)
  removed=$(comm -23 <(hash_paths_only "$old") <(hash_paths_only "$new") || true)
  if [[ -n $added ]]; then
    err "$label added:"
    printf '%s\n' "$added" | sed 's/^/[blackomarchy]   /' >&2
  fi
  if [[ -n $removed ]]; then
    err "$label removed:"
    printf '%s\n' "$removed" | sed 's/^/[blackomarchy]   /' >&2
  fi
  if [[ -z $added && -z $removed ]]; then
    err "$label hashes changed (same paths, different contents)"
  fi
}

compare_file() {
  local name=$1 a=$2 b=$3
  if ! cmp -s "$a" "$b"; then
    printf '%s\n' "$name"
    return 1
  fi
  return 0
}

baseline_compare() {
  local dest failed=0
  dest=$(baseline_dir)
  [[ -d $dest ]] || die "no baseline snapshot found"

  if ! cmp -s "$dest/omarchy-version" <(omarchy_version_string); then
    err "Omarchy version drifted"
    failed=1
  fi
  if ! cmp -s "$dest/omarchy-server" <(omarchy_server_line); then
    err "Omarchy repository Server line drifted"
    failed=1
  fi
  if [[ -f $dest/omarchy-packages ]]; then
    if ! cmp -s "$dest/omarchy-packages" <(pacman -Q omarchy omarchy-settings omarchy-keyring 2>/dev/null || true); then
      err "Omarchy packages changed"
      failed=1
    fi
  fi

  local p tmp
  tmp=$(mktemp)
  : >"$tmp"
  for p in $(omarchy_owned_hash_targets); do
    hash_if_exists "$p" >>"$tmp" || true
  done
  if ! cmp -s "$dest/hashes.tsv" "$tmp"; then
    err "Omarchy-owned file hashes changed"
    failed=1
  fi
  rm -f "$tmp"
  if [[ -f $dest/omarchy-tree.hashes && -d $(blackomarchy_path /usr/share/omarchy) ]]; then
    tmp=$(mktemp)
    hash_tree "$(blackomarchy_path /usr/share/omarchy)" >"$tmp" || true
    if ! cmp -s "$dest/omarchy-tree.hashes" "$tmp"; then
      err "Omarchy tree hashes changed under /usr/share/omarchy"
      failed=1
    fi
    rm -f "$tmp"
  fi

  local home
  home=$(invoking_home)
  if [[ -f $dest/hypr.hashes && -d $home/.config/hypr ]]; then
    tmp=$(mktemp)
    hash_tree "$home/.config/hypr" >"$tmp" || true
    if ! cmp -s "$dest/hypr.hashes" "$tmp"; then
      err "Hyprland user configuration changed (not a version pin; Omarchy hooks or your edits)"
      log_hash_drift "hypr" "$dest/hypr.hashes" "$tmp"
      log "refresh the pin with: sudo blackomarchy recapture-baseline"
    fi
    rm -f "$tmp"
  fi
  if [[ -f $dest/omarchy-user.hashes && -d $home/.config/omarchy ]]; then
    tmp=$(mktemp)
    hash_omarchy_user_tree "$home" >"$tmp" || true
    local a b
    a=$(mktemp)
    b=$(mktemp)
    grep -vE "$(owned_omarchy_user_path_regex)" "$dest/omarchy-user.hashes" >"$a" || true
    grep -vE "$(owned_omarchy_user_path_regex)" "$tmp" >"$b" || true
    if ! cmp -s "$a" "$b"; then
      err "Omarchy user configuration changed (menu/hooks/first-run files under ~/.config/omarchy)"
      log_hash_drift "omarchy user config" "$a" "$b"
      log "refresh the pin with: sudo blackomarchy recapture-baseline"
    fi
    rm -f "$a" "$b" "$tmp"
  fi

  require_omarchy_repos
  assert_single_blackarch
  ((failed == 0))
}
