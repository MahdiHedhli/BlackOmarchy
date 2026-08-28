#!/usr/bin/env bash
# Host detection. Fail closed.

if [[ -n ${BLACKOMARCHY_DETECT_LOADED:-} ]]; then
  return 0 2>/dev/null || true
fi
BLACKOMARCHY_DETECT_LOADED=1

os_release_file() {
  blackomarchy_path /etc/os-release
}

omarchy_version_file() {
  blackomarchy_path /usr/share/omarchy/version
}

read_os_id() {
  local file
  file=$(os_release_file)
  [[ -r $file ]] || return 1
  awk -F= '/^ID=/ {gsub(/"/, "", $2); print $2; exit}' "$file"
}

arch_is_x86_64() {
  [[ $(uname -m) == x86_64 ]]
}

os_is_arch() {
  local id
  id=$(read_os_id)
  [[ $id == arch || $id == omarchy ]]
}

pacman_query() {
  if have_cmd pacman; then
    pacman -Q "$1" >/dev/null 2>&1
  else
    return 1
  fi
}

omarchy_command_present() {
  have_cmd omarchy
}

detect_unsupported_channel() {
  if pacman_query omarchy-dev || pacman_query omarchy-settings-dev; then
    die "unsupported Omarchy channel: omarchy-dev is not supported in v0.1 (stable/rc packaged omarchy required)"
  fi
}

detect_architecture() {
  arch_is_x86_64 || die "unsupported architecture: $(uname -m) (x86_64 required)"
}

detect_os() {
  os_is_arch || die "unsupported OS: ID=$(read_os_id 2>/dev/null || printf unknown) (Omarchy or Arch required)"
}

detect_omarchy() {
  detect_unsupported_channel
  local missing=()
  pacman_query omarchy || missing+=("package:omarchy")
  [[ -r $(omarchy_version_file) ]] || missing+=("file:/usr/share/omarchy/version")
  omarchy_command_present || missing+=("command:omarchy")
  if ((${#missing[@]} > 0)); then
    die "Omarchy not detected (need packaged Omarchy 4.x). Missing: ${missing[*]}"
  fi
}

omarchy_version_string() {
  local file
  file=$(omarchy_version_file)
  if [[ -r $file ]]; then
    tr -d '\n' <"$file"
    printf '\n'
    return
  fi
  pacman -Q omarchy 2>/dev/null || true
}

omarchy_server_line() {
  local conf
  conf=$(blackomarchy_path /etc/pacman.conf)
  [[ -r $conf ]] || return 0
  awk '
    /^\[omarchy\]/ {in_om=1; next}
    /^\[/ {in_om=0}
    in_om && /^[[:space:]]*Server[[:space:]]*=/ {print; exit}
  ' "$conf"
}

detect_host() {
  detect_architecture
  detect_os
  detect_omarchy
}
