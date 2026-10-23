#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/blackarch.sh"

for fp in \
  8F9A9793CB8591147C2EC70566E0CDBD1E01F333 \
  A0917C4147A37007CB54C1CFD295AA940EFDDF62 \
  4345771566D76038C7FEB43863EC0ADBEA87E4E3 \
  F9A6E68A711354D84A9B91637533BAFE69A25079; do
  signer_allowed "$fp" || { echo "official signer should be allowed: $fp"; exit 1; }
done
signer_allowed 8f9a9793cb8591147c2ec70566e0cdbd1e01f333 || exit 1
if signer_allowed DEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF; then
  echo "unknown key must be denied"
  exit 1
fi
echo "ok signer allowlist"
