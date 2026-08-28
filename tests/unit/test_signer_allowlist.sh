#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/blackarch.sh"

signer_allowed CBA3C7D4798912702DCF568E67D8BDF42AD93F4E || { echo "master key should be allowed"; exit 1; }
signer_allowed 4345771566D76038C7FEB43863EC0ADBEA87E4E3 || { echo "strap-listed key should be allowed"; exit 1; }
if signer_allowed DEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF; then
  echo "unknown key must be denied"
  exit 1
fi
echo "ok signer allowlist"
