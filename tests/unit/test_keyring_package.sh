#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck disable=SC1091
source "$HERE/lib/common.sh"
# shellcheck disable=SC1091
source "$HERE/lib/blackarch.sh"

tmp=$(make_priv_tempdir)
cleanup() {
  gpgconf --homedir "$tmp/keys" --kill all >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT
export TMPDIR="$tmp"

reject() {
  if ( "$@" ) >"$tmp/rejection.log" 2>&1; then
    echo "expected rejection: $*"
    exit 1
  fi
}

pkgname=blackarch-keyring-20251011-2-any.pkg.tar.gz
mkdir -p "$tmp/db/blackarch-keyring-20251011-2"
desc="$tmp/db/blackarch-keyring-20251011-2/desc"
printf '%%FILENAME%%\n%s\n\n%%NAME%%\nblackarch-keyring\n' "$pkgname" >"$desc"
bsdtar -czf "$tmp/blackarch.db" -C "$tmp/db" blackarch-keyring-20251011-2
[[ $(parse_keyring_package_filename "$tmp/blackarch.db") == "$pkgname" ]] || exit 1
for unsafe in '../../outside' '/tmp/outside' 'blackarch-keyring-1-any.pkg.tar.zst/../../outside' 'other-1-any.pkg.tar.zst' ''; do
  printf '%%FILENAME%%\n%s\n' "$unsafe" >"$desc"
  bsdtar -czf "$tmp/blackarch.db" -C "$tmp/db" blackarch-keyring-20251011-2
  reject parse_keyring_package_filename "$tmp/blackarch.db"
done
printf '%%FILENAME%%\n%s\n%%FILENAME%%\n%s\n' "$pkgname" "$pkgname" >"$desc"
bsdtar -czf "$tmp/blackarch.db" -C "$tmp/db" blackarch-keyring-20251011-2
reject parse_keyring_package_filename "$tmp/blackarch.db"
printf 'not an archive' >"$tmp/corrupt.db"
reject parse_keyring_package_filename "$tmp/corrupt.db"

mkdir -p "$tmp/package/usr/share/pacman/keyrings"
export BLACKOMARCHY_ROOT="$tmp/host"
dest="$BLACKOMARCHY_ROOT/usr/share/pacman/keyrings"
mkdir -p "$dest"
for base in blackarch.gpg blackarch-trusted blackarch-revoked; do
  printf 'synthetic %s\n' "$base" >"$tmp/package/usr/share/pacman/keyrings/$base"
  cp "$tmp/package/usr/share/pacman/keyrings/$base" "$dest/$base"
done
bsdtar -czf "$tmp/$pkgname" -C "$tmp/package" usr
keyring_files_match "$tmp/$pkgname" || { echo 'matching files rejected'; exit 1; }
printf 'tampered' >>"$dest/blackarch.gpg"
reject keyring_files_match "$tmp/$pkgname"
cp "$tmp/package/usr/share/pacman/keyrings/blackarch.gpg" "$dest/blackarch.gpg"
rm "$dest/blackarch-revoked"
reject keyring_files_match "$tmp/$pkgname"
ln -s "$tmp/package/usr/share/pacman/keyrings/blackarch-revoked" "$dest/blackarch-revoked"
reject keyring_files_match "$tmp/$pkgname"
rm "$tmp/package/usr/share/pacman/keyrings/blackarch-trusted"
bsdtar -czf "$tmp/incomplete.pkg.tar.gz" -C "$tmp/package" usr
reject keyring_files_match "$tmp/incomplete.pkg.tar.gz"
reject keyring_files_match "$tmp/corrupt.db"

# Generate a primary certification key with a distinct signing subkey.
# Verification uses real crypto; only key retrieval is replaced with a local import.
mkdir -m 700 "$tmp/keys"
gpg --no-options --homedir "$tmp/keys" --batch --pinentry-mode loopback \
  --passphrase '' --quick-generate-key 'Black omARCHy test <test@example.invalid>' \
  ed25519 cert 0 >/dev/null 2>&1
fp=$(gpg --no-options --homedir "$tmp/keys" --batch --with-colons --list-keys 2>/dev/null |
  awk -F: '$1 == "fpr" && !found {print $10; found=1}')
gpg --no-options --homedir "$tmp/keys" --batch --pinentry-mode loopback \
  --passphrase '' --quick-add-key "$fp" ed25519 sign 0 >/dev/null 2>&1
gpg --no-options --homedir "$tmp/keys" --batch --pinentry-mode loopback \
  --passphrase '' --detach-sign "$tmp/$pkgname"
gpg --no-options --homedir "$tmp/keys" --batch --export "$fp" >"$tmp/public.gpg"
gpg_recv_fingerprint() {
  gpg --no-options --homedir "$1" --batch --import "$tmp/public.gpg" >/dev/null 2>&1
}
ALLOWED_KEYRING_SIGNERS=("$fp")
[[ $(verify_keyring_package "$tmp/$pkgname" "$tmp/$pkgname.sig") == "$fp" ]] || exit 1
reject verify_keyring_package "$tmp/$pkgname" "$tmp/missing.sig"
cp "$tmp/$pkgname" "$tmp/tampered.pkg"
printf 'tampered' >>"$tmp/tampered.pkg"
reject verify_keyring_package "$tmp/tampered.pkg" "$tmp/$pkgname.sig"
(
  ALLOWED_KEYRING_SIGNERS=(DEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF)
  reject verify_keyring_package "$tmp/$pkgname" "$tmp/$pkgname.sig"
)
(
  gpg_recv_fingerprint() { return 1; }
  reject verify_keyring_package "$tmp/$pkgname" "$tmp/$pkgname.sig"
)

# A VALIDSIG line must not hide a failing exit code or expiry/revocation status.
(
  gpg_recv_fingerprint() { return 0; }
  gpg() {
    printf '[GNUPG:] VALIDSIG %s 2026-10-23 1 0 4 0 22 8 00 %s\n' "$fp" "$fp"
    if [[ -n ${extra_status:-} ]]; then
      printf '[GNUPG:] %s\n' "$extra_status"
    fi
    return "${verify_rc:-0}"
  }
  verify_rc=1
  reject verify_keyring_package "$tmp/$pkgname" "$tmp/$pkgname.sig"
  verify_rc=0
  for extra_status in EXPKEYSIG REVKEYSIG EXPSIG KEYEXPIRED SIGEXPIRED; do
    reject verify_keyring_package "$tmp/$pkgname" "$tmp/$pkgname.sig"
  done
)

echo 'ok keyring metadata, file integrity, and signature regressions'
