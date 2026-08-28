#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/etc"
cat >"$tmp/etc/pacman.conf" <<'EOF'
[options]
Architecture = auto
[core]
Include = /etc/pacman.d/mirrorlist
[extra]
Include = /etc/pacman.d/mirrorlist
[multilib]
Include = /etc/pacman.d/mirrorlist
[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/stable/$arch
EOF

export BLACKOMARCHY_ROOT=$tmp
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/pacman.sh"

out=$(strip_blackarch_stanza <"$tmp/etc/pacman.conf")
printf '%s\n' "$out" | grep -q '^\[omarchy\]' || exit 1
printf '%s\n' "$out" | grep -q '^\[blackarch\]' && exit 1

printf '\n[blackarch]\nInclude = /etc/pacman.d/blackarch-mirrorlist\n' >>"$tmp/etc/pacman.conf"
n=$(grep -c '^\[blackarch\]' "$tmp/etc/pacman.conf")
[[ $n -eq 1 ]] || exit 1

stripped=$(strip_blackarch_stanza <"$tmp/etc/pacman.conf")
printf '%s\n' "$stripped" | grep -q '^\[omarchy\]' || exit 1
printf '%s\n' "$stripped" | grep -q '^\[blackarch\]' && exit 1
printf '%s\n' "$stripped" | grep -q 'pkgs.omarchy.org' || exit 1
echo "ok stanza parser"
