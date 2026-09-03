#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/packages.sh"

pkgs=$(load_profile_packages core)
printf '%s\n' "$pkgs" | grep -qx nmap || { echo "core missing nmap"; exit 1; }
printf '%s\n' "$pkgs" | grep -q '^#' && { echo "comments leaked"; exit 1; }

valid_profile core || exit 1
valid_profile all || exit 1
valid_profile catalog || exit 1
valid_profile nope && exit 1

count=$(expand_profiles all | wc -l | tr -d ' ')
[[ $count -eq 8 ]] || { echo "all expansion failed: $count"; exit 1; }

profile_contains_package web sqlmap || { echo "web should contain sqlmap"; exit 1; }
profile_contains_package web nmap && { echo "web should not contain nmap"; exit 1; }
echo "ok profiles"
