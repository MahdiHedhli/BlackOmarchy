#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/blackarch.sh"

tmp=$(mktemp)
echo hello >"$tmp"
if verify_sha1_file 00688950aaf5e5804d2abebb8d3d3ea1d28525ed "$tmp"; then
  echo "mismatch should fail"
  rm -f "$tmp"
  exit 1
fi
rm -f "$tmp"
echo "ok hash mismatch refuses"
