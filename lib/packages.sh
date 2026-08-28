#!/usr/bin/env bash
# Profile load, classify, install one package at a time.

if [[ -n ${BLACKOMARCHY_PACKAGES_LOADED:-} ]]; then
  return 0 2>/dev/null || true
fi
BLACKOMARCHY_PACKAGES_LOADED=1

CURATED_PROFILES=(core web recon network wireless reversing forensics password)

profile_dir() {
  local here
  if [[ -d ${BLACKOMARCHY_SHARE_DIR:-}/packages ]]; then
    printf '%s\n' "${BLACKOMARCHY_SHARE_DIR}/packages"
    return
  fi
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  printf '%s\n' "$here/packages"
}

profile_file() {
  printf '%s/%s.txt\n' "$(profile_dir)" "$1"
}

valid_profile() {
  local p
  if [[ $1 == all ]]; then
    return 0
  fi
  for p in "${CURATED_PROFILES[@]}"; do
    [[ $p == "$1" ]] && return 0
  done
  return 1
}

expand_profiles() {
  local name=$1
  if [[ $name == all ]]; then
    printf '%s\n' "${CURATED_PROFILES[@]}"
    return
  fi
  printf '%s\n' "$name"
}

load_profile_packages() {
  local file
  file=$(profile_file "$1")
  [[ -f $file ]] || die "unknown profile: $1"
  awk '
    /^[[:space:]]*#/ {next}
    /^[[:space:]]*$/ {next}
    {print $1}
  ' "$file"
}

classify_candidate() {
  local pkg=$1
  if package_denied "$pkg"; then
    printf 'CONFLICT\tdenied package class\n'
    return
  fi
  if ! package_exists "$pkg"; then
    printf 'UNTESTED\tnot in configured repositories\n'
    return
  fi
  if package_replaces_omarchy "$pkg"; then
    printf 'CONFLICT\tConflicts/Replaces Omarchy packages\n'
    return
  fi
  local replaced
  replaced=$(package_replaces_installed "$pkg" || true)
  if [[ -n $replaced ]]; then
    printf 'CONFLICT\twould replace/remove installed %s\n' "$replaced"
    return
  fi
  local upgraded
  upgraded=$(transaction_upgrades_installed "$pkg" || true)
  if [[ -n $upgraded ]]; then
    printf 'CONFLICT\twould upgrade installed %s\n' "$upgraded"
    return
  fi
  if package_installed "$pkg"; then
    printf 'PASS\talready installed\n'
    return
  fi
  local tx
  tx=$(transaction_names "$pkg" | awk 'NF' | wc -l | tr -d ' ')
  if [[ ${tx:-0} -gt 1 ]]; then
    printf 'PASS WITH DEPENDENCIES\tnew package plus new dependencies\n'
    return
  fi
  printf 'PASS\tnew package\n'
}

install_profile() {
  local profile=$1 pkg class reason installed=0 skipped=0
  valid_profile "$profile" || die "unknown profile: $profile"
  local names
  names=$(expand_profiles "$profile")
  local name
  for name in $names; do
    log "profile $name"
    while IFS= read -r pkg; do
      [[ -n $pkg ]] || continue
      IFS=$'\t' read -r class reason <<<"$(classify_candidate "$pkg")"
      case "$class" in
        PASS|"PASS WITH DEPENDENCIES")
          if package_installed "$pkg"; then
            log "skip $pkg (already installed)"
            continue
          fi
          if add_package "$pkg"; then
            append_manifest_line "package	${pkg}	${class}	${name}"
            log "installed $pkg ($class)"
            installed=$((installed + 1))
          else
            append_exclusion "${pkg}	CONFLICT	install failed	${name}"
            log "excluded $pkg (install failed)"
            skipped=$((skipped + 1))
          fi
          ;;
        *)
          append_exclusion "$pkg	$class	$reason	$name"
          log "excluded $pkg ($class: $reason)"
          skipped=$((skipped + 1))
          ;;
      esac
    done < <(load_profile_packages "$name")
  done
  if [[ $installed -eq 0 && $skipped -gt 0 && $profile != all ]]; then
    local any=0
    while IFS= read -r pkg; do
      package_installed "$pkg" && any=1
    done < <(load_profile_packages "$profile")
    if [[ $any -eq 0 ]]; then
      die "profile $profile installed nothing (empty after exclusions)"
    fi
  fi
}

remove_profile() {
  local profile=$1 pkg
  valid_profile "$profile" || die "unknown profile: $profile"
  local names
  names=$(expand_profiles "$profile")
  local name
  for name in $names; do
    while IFS= read -r pkg; do
      [[ -n $pkg ]] || continue
      if grep -Eq "^package	${pkg}	" "$(state_dir)/manifest" 2>/dev/null; then
        remove_package_if_safe "$pkg"
        log "removed $pkg"
      fi
    done < <(load_profile_packages "$name")
  done
}

list_profiles() {
  local p file
  for p in "${CURATED_PROFILES[@]}"; do
    file=$(profile_file "$p")
    if [[ -f $file ]]; then
      printf '%s\n' "$p"
    fi
  done
}
