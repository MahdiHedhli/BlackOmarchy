#!/usr/bin/env bash
# Pacman helpers. Never sysupgrade. Never --overwrite='*'.

if [[ -n ${BLACKOMARCHY_PACMAN_LOADED:-} ]]; then
  return 0 2>/dev/null || true
fi
BLACKOMARCHY_PACMAN_LOADED=1

pacman_conf_file() {
  blackomarchy_path /etc/pacman.conf
}

DENY_PACKAGES_REGEX='^(blackarch|blackarch-officials|linux|linux-lts|linux-zen|linux-hardened|linux-rt|sddm|gdm|lightdm|networkmanager|hyprland|omarchy|omarchy-settings|omarchy-keyring|omarchy-nvim)$'

repo_list() {
  if have_cmd pacman-conf; then
    pacman-conf --repo-list
  else
    awk '/^\[/ && $0 !~ /^\[options\]/ {gsub(/[][]/, ""); print}' "$(pacman_conf_file)"
  fi
}

repo_enabled() {
  repo_list | grep -qx "$1"
}

count_uncommented_repo_headers() {
  local name=$1 n
  n=$(grep -c "^\[${name}\]" "$(pacman_conf_file)" 2>/dev/null || true)
  printf '%s\n' "${n:-0}"
}

blackarch_ambiguous() {
  local conf
  conf=$(pacman_conf_file)
  grep -q '\[blackarch\]' "$conf" 2>/dev/null || return 1
  repo_enabled blackarch && return 1
  return 0
}

require_omarchy_repos() {
  local missing=()
  local r
  for r in core extra multilib omarchy; do
    repo_enabled "$r" || missing+=("$r")
  done
  if ((${#missing[@]} > 0)); then
    die "required pacman repositories missing or disabled: ${missing[*]}"
  fi
}

omarchy_server_fingerprint() {
  omarchy_server_line
}

strip_blackarch_stanza() {
  awk '
    /^\[blackarch\]/ {skip=1; next}
    /^\[/ {skip=0}
    skip {next}
    {print}
  '
}

non_blackarch_bytes() {
  strip_blackarch_stanza <"$(pacman_conf_file)"
}

remove_blackarch_stanza_from_file() {
  local conf tmp
  conf=$(pacman_conf_file)
  tmp=$(mktemp "${conf}.XXXXXX")
  strip_blackarch_stanza <"$conf" >"$tmp"
  chmod --reference="$conf" "$tmp" 2>/dev/null || chmod 644 "$tmp"
  mv -f "$tmp" "$conf"
}

append_blackarch_stanza() {
  local conf
  conf=$(pacman_conf_file)
  if repo_enabled blackarch; then
    return 0
  fi
  if blackarch_ambiguous; then
    die "ambiguous [blackarch] configuration in pacman.conf"
  fi
  printf '\n[blackarch]\nInclude = /etc/pacman.d/blackarch-mirrorlist\n' >>"$conf"
}

blackarch_stanza_count() {
  count_uncommented_repo_headers blackarch
}

assert_single_blackarch() {
  local n
  n=$(blackarch_stanza_count)
  if [[ $n -gt 1 ]]; then
    die "duplicate [blackarch] stanza in pacman.conf"
  fi
}

assert_no_sysupgrade_args() {
  local a
  for a in "$@"; do
    case "$a" in
      -Syu|-Suy|-Syyu|-Syuy|-Suyy|--sysupgrade)
        die "system upgrade is forbidden from Black omARCHy ($a)"
        ;;
      -*)
        if [[ $a == *S* && $a == *u* ]]; then
          die "system upgrade is forbidden from Black omARCHy ($a)"
        fi
        ;;
    esac
  done
}

package_denied() {
  [[ $1 =~ $DENY_PACKAGES_REGEX ]]
}

package_exists() {
  pacman -Si "$1" >/dev/null 2>&1
}

package_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

package_conflict_names() {
  pacman -Si "$1" 2>/dev/null | awk '
    /^Replaces/ {p=1}
    /^Conflicts With/ {p=1}
    /^Conflicts/ {p=1}
    p {
      if ($1 ~ /^(Replaces|Conflicts)/) {
        $1=""
        if ($2 == "With") $2=""
      }
      print
    }
    /^[^[:space:]]/ && !/^Replaces/ && !/^Conflicts/ {p=0}
  ' | tr ' ' '\n' | sed '/^$/d; /^None$/d'
}

package_replaces_installed() {
  local pkg=$1 name
  while IFS= read -r name; do
    [[ -n $name && $name != "$pkg" ]] || continue
    if package_installed "$name"; then
      printf '%s\n' "$name"
      return 0
    fi
  done < <(package_conflict_names "$pkg")
  return 1
}

package_replaces_omarchy() {
  package_conflict_names "$1" | grep -Eq '^omarchy'
}

transaction_names() {
  local pkg=$1
  pacman -S --print --print-format '%n' --needed "$pkg" 2>/dev/null || true
}

transaction_upgrades_installed() {
  local pkg=$1 name
  while IFS= read -r name; do
    [[ -n $name ]] || continue
    if package_installed "$name"; then
      if [[ $name != "$pkg" ]]; then
        printf '%s\n' "$name"
        return 0
      fi
    fi
  done < <(transaction_names "$pkg")
  return 1
}

add_package() {
  local pkg=$1
  assert_no_sysupgrade_args -S --needed "$pkg"
  if have_cmd omarchy-pkg-add; then
    omarchy-pkg-add "$pkg"
  else
    pacman -S --noconfirm --needed "$pkg"
  fi
}

remove_package_if_safe() {
  local pkg=$1
  package_installed "$pkg" || return 0
  if pacman -R --noconfirm "$pkg"; then
    return 0
  fi
  err "could not remove $pkg (likely required by another package)"
  return 1
}

snapshot_packages() {
  pacman -Q
}
