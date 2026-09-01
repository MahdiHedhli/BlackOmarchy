#!/usr/bin/env bash
# Channel refresh copies a template over pacman.conf. Re-append must
# restore [blackarch] last without touching Omarchy repos.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/etc/pacman.d" "$tmp/usr/share/pacman/keyrings"
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
cp "$tmp/etc/pacman.conf" "$tmp/template.conf"
printf '\n[blackarch]\nInclude = /etc/pacman.d/blackarch-mirrorlist\n' >>"$tmp/etc/pacman.conf"
touch "$tmp/etc/pacman.d/blackarch-mirrorlist"
touch "$tmp/usr/share/pacman/keyrings/blackarch.gpg"

export BLACKOMARCHY_ROOT=$tmp
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/pacman.sh"

# Simulate omarchy refresh pacman: template overwrites pacman.conf.
cp "$tmp/template.conf" "$tmp/etc/pacman.conf"
repo_enabled blackarch && exit 1
append_blackarch_stanza
repo_enabled blackarch || exit 1
n=$(blackarch_stanza_count)
[[ $n -eq 1 ]] || exit 1
# Last uncommented repo header must be blackarch.
last=$(awk '/^\[/ && $0 !~ /^\[options\]/ {name=$0} END {print name}' "$tmp/etc/pacman.conf")
[[ $last == '[blackarch]' ]] || exit 1
grep -q 'pkgs.omarchy.org' "$tmp/etc/pacman.conf" || exit 1
# Idempotent.
append_blackarch_stanza
[[ $(blackarch_stanza_count) -eq 1 ]] || exit 1
echo "ok reappend after template rewrite"
