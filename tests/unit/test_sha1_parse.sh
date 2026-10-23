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

echo "ok official strap SHA1 parse"
