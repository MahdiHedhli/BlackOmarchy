#!/usr/bin/env bash
# Overlay copies SDDM and Plymouth logos, backs them up, and restores.
# Initramfs rebuild is skipped here (no mkinitcpio on the test host).
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
HELPER="$HERE/share/blackomarchy-apply-login-branding"
[[ -x $HELPER ]] || chmod +x "$HELPER"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/share/branding" "$tmp/sddm" "$tmp/plymouth" "$tmp/state"
printf 'wordmark' >"$tmp/share/branding/login-logo.png"
printf 'sddm-stock' >"$tmp/sddm/logo.png"
printf 'plymouth-stock' >"$tmp/plymouth/logo.png"
printf '0.1.0' >"$tmp/state/version"

export BLACKOMARCHY_SKIP_SUDO=1
export BLACKOMARCHY_SKIP_INITRAMFS=1
export BLACKOMARCHY_STATE_DIR="$tmp/state"
export BLACKOMARCHY_SHARE_DIR="$tmp"
export BLACKOMARCHY_SDDM_LOGO="$tmp/sddm/logo.png"
export BLACKOMARCHY_PLYMOUTH_LOGO="$tmp/plymouth/logo.png"

# No version pin: apply is a no-op.
rm -f "$tmp/state/version"
bash "$HELPER" apply
[[ $(cat "$tmp/sddm/logo.png") == sddm-stock ]] || exit 1
[[ $(cat "$tmp/plymouth/logo.png") == plymouth-stock ]] || exit 1
printf '0.1.0' >"$tmp/state/version"

bash "$HELPER" apply
[[ $(cat "$tmp/sddm/logo.png") == wordmark ]] || exit 1
[[ $(cat "$tmp/plymouth/logo.png") == wordmark ]] || exit 1
[[ $(cat "$tmp/state/sddm-logo.omarchy.png") == sddm-stock ]] || exit 1
[[ $(cat "$tmp/state/plymouth-logo.omarchy.png") == plymouth-stock ]] || exit 1

# Idempotent: backups stay the original stock, not the overlay.
bash "$HELPER" apply
[[ $(cat "$tmp/state/sddm-logo.omarchy.png") == sddm-stock ]] || exit 1
[[ $(cat "$tmp/state/plymouth-logo.omarchy.png") == plymouth-stock ]] || exit 1

# apply-sddm does not touch Plymouth.
printf 'plymouth-other' >"$tmp/plymouth/logo.png"
bash "$HELPER" apply-sddm
[[ $(cat "$tmp/sddm/logo.png") == wordmark ]] || exit 1
[[ $(cat "$tmp/plymouth/logo.png") == plymouth-other ]] || exit 1

bash "$HELPER" restore
[[ $(cat "$tmp/sddm/logo.png") == sddm-stock ]] || exit 1
[[ $(cat "$tmp/plymouth/logo.png") == plymouth-stock ]] || exit 1

set +e
bash "$HELPER" nope >/dev/null 2>&1
rc=$?
set -e
[[ $rc -eq 2 ]] || exit 1

echo "ok branding overlay"
