#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/etc"
printf 'ID=omarchy\n' >"$tmp/etc/os-release"
export BLACKOMARCHY_ROOT=$tmp
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/detect.sh"
os_is_arch || { echo "ID=omarchy should be accepted"; exit 1; }
printf 'ID=arch\n' >"$tmp/etc/os-release"
os_is_arch || { echo "ID=arch should be accepted"; exit 1; }
printf 'ID=debian\n' >"$tmp/etc/os-release"
os_is_arch && { echo "ID=debian should be rejected"; exit 1; }
echo "ok os detection"
