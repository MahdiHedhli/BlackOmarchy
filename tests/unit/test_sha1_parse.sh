#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/blackarch.sh"

page="$HERE/tests/unit/fixtures/downloads.html"
got=$(parse_strap_sha1_from_page "$page")
want=00688950aaf5e5804d2abebb8d3d3ea1d28525ed
[[ $got == "$want" ]] || { echo "SHA1 parse failed: $got"; exit 1; }

# Must not pick the Full ISO digest that appears first on the page.
[[ $got != ae64930aeddc491a4644bb3fa92a715145713c65 ]] || exit 1

sample="$HERE/tests/unit/fixtures/strap-sample.sh"
ver=$(parse_strap_version "$sample")
fp=$(parse_strap_fingerprint "$sample")
[[ $ver == 20251011 ]] || { echo "VERSION parse failed: $ver"; exit 1; }
[[ $fp == 4345771566D76038C7FEB43863EC0ADBEA87E4E3 ]] || { echo "fingerprint parse failed: $fp"; exit 1; }
echo "ok sha1/version/fingerprint parse"
