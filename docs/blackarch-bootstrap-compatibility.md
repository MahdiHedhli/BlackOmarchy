# BlackArch Bootstrap Compatibility Fix

## Overview

BlackOmarchy's bootstrap process originally depended on assumptions about the structure of the official BlackArch `strap.sh` script.

The upstream bootstrap workflow changed, causing BlackOmarchy's keyring verification logic to fail before the BlackArch repository could be enabled.

This change updates the bootstrap implementation to follow the current BlackArch keyring distribution workflow, while retaining explicit GPG signer verification and installed-keyring integrity checks.

---

## 1. The Original Error

The original implementation downloaded the official `strap.sh` and attempted to extract two values directly from it:

```bash
version=$(parse_strap_version "$work/strap.sh")
fingerprint=$(parse_strap_fingerprint "$work/strap.sh")

[[ -n $version && -n $fingerprint ]] \
  || die "could not parse VERSION or keyring fingerprint from verified strap.sh"
```

This resulted in:

```
[blackomarchy] error: could not parse VERSION or keyring fingerprint from verified strap.sh
```

The problem was **not** the SHA1 verification of `strap.sh`. The downloaded script passed that check.

The failure occurred because the bootstrap implementation expected the upstream script to expose a `VERSION` value and a directly extractable GPG fingerprint.

---

## 2. Root Cause

The previous implementation contained two parsing functions:

```bash
parse_strap_version() {
  awk -F= '/^VERSION=/ {gsub(/"/, "", $2); print $2; exit}' "$1"
}

parse_strap_fingerprint() {
  awk '/recv-keys/ {
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^[0-9A-Fa-f]{40}$/) {
        print toupper($i)
        exit
      }
    }
  }' "$1"
}
```

These functions assumed that the upstream `strap.sh` contained:

- a `VERSION` declaration;
- a 40-character GPG fingerprint associated with a `recv-keys` invocation.

The current BlackArch bootstrap process no longer follows that structure.

The compatibility problem was therefore caused by coupling the BlackOmarchy bootstrap implementation to a specific internal format of the upstream `strap.sh` script.

---

## 3. Keyring Verification Changes

### 3.1 Removing the Old Parsing Approach

The obsolete parsing functions were removed:

```diff
-parse_strap_version() {
-  awk -F= '/^VERSION=/ {gsub(/"/, "", $2); print $2; exit}' "$1"
-}
-
-parse_strap_fingerprint() {
-  awk '/recv-keys/ {
-    for (i = 1; i <= NF; i++) {
-      if ($i ~ /^[0-9A-Fa-f]{40}$/) {
-        print toupper($i)
-        exit
-      }
-    }
-  }' "$1"
-}
```

Instead of extracting trust information from the implementation details of `strap.sh`, the updated code uses an explicit list of trusted BlackArch signing-key fingerprints.

### 3.2 Updating Trusted Signing Keys

The previous allowlist contained:

```bash
ALLOWED_KEYRING_SIGNERS=(
  CBA3C7D4798912702DCF568E67D8BDF42AD93F4E
  4345771566D76038C7FEB43863EC0ADBEA87E4E3
)
```

The updated implementation uses:

```bash
ALLOWED_KEYRING_SIGNERS=(
  8F9A9793CB8591147C2EC70566E0CDBD1E01F333
  A0917C4147A37007CB54C1CFD295AA940EFDDF62
  4345771566D76038C7FEB43863EC0ADBEA87E4E3
  F9A6E68A711354D84A9B91637533BAFE69A25079
)
```

This allows the bootstrap process to validate the signer independently of the exact implementation of the upstream `strap.sh`.

---

## 4. Verifying the Keyring Package

The previous implementation verified a `blackarch-keyring-<version>.tar.gz` archive.

The updated implementation introduces `verify_keyring_package()`.

First, the allowed signing keys are fetched from public keyservers, falling back from one to another:

```bash
verify_keyring_package() {
  local pkg=$1
  local sig=$2
  local homedir signer status fpr

  have_cmd gpg || die "gpg is required to verify the BlackArch keyring"

  homedir=$(make_priv_tempdir)
  chmod 700 "$homedir"

  for fpr in "${ALLOWED_KEYRING_SIGNERS[@]}"; do
    if ! gpg --homedir "$homedir" \
      --batch \
      --pinentry-mode loopback \
      --keyserver hkps://keyserver.ubuntu.com \
      --recv-keys "$fpr" >/dev/null 2>&1; then

      gpg --homedir "$homedir" \
        --batch \
        --pinentry-mode loopback \
        --keyserver hkps://keys.openpgp.org \
        --recv-keys "$fpr" >/dev/null 2>&1 || true
    fi
  done
```

Keys are requested by their **full 40-character fingerprint**, so a keyserver cannot substitute a different key: GPG will only import a key matching the requested fingerprint.

The detached signature is then checked using GPG:

```bash
status=$(
  gpg --homedir "$homedir" \
    --status-fd 1 \
    --verify "$sig" "$pkg" 2>/dev/null || true
)
```

The signer fingerprint is extracted from GPG's `VALIDSIG` status line:

```bash
signer=$(printf '%s\n' "$status" |
  awk '$2 == "VALIDSIG" { print $NF; exit }')
```

Finally, the fingerprint is checked against the explicit allowlist:

```bash
signer=$(upper_hex "$signer")

if ! signer_allowed "$signer"; then
  rm -rf "$homedir"
  die "BlackArch keyring signed by untrusted key $signer"
fi
```

This gives the verification process two separate properties:

1. The package has a valid GPG signature.
2. The signer belongs to the explicitly trusted set.

> **Note:** if the signature is invalid, or no allowed key could be fetched, `signer` ends up empty and the check fails. The failure mode is safe, but the resulting error message does not distinguish "invalid signature" from "signing key not found". See [Possible Improvements](#10-limitations-and-possible-improvements).

---

## 5. Discovering the Current Keyring Package

Instead of constructing a filename from a version extracted from `strap.sh`, the updated implementation queries the official BlackArch repository database.

```bash
local repo
repo="${BLACKARCH_MIRROR_BASE:-https://blackarch.org/blackarch/blackarch/os/$(uname -m)}"

log "fetching BlackArch repository database"
https_get "$repo/blackarch.db" "$work/blackarch.db"
```

The package filename is then extracted from the repository database:

```bash
keyring_pkg=$(
  bsdtar -xOf "$work/blackarch.db" 'blackarch-keyring-*/desc' 2>/dev/null |
    awk '/^%FILENAME%$/ { getline; print; exit }'
)
```

This removes the dependency on a keyring version embedded in the `strap.sh` implementation.

The resulting package is downloaded together with its detached signature:

```bash
keyring_url="$repo/$keyring_pkg"

https_get "$keyring_url" "$work/$keyring_pkg"
https_get "$keyring_url.sig" "$work/$keyring_pkg.sig"
```

The package is then passed to the verification function:

```bash
signer=$(verify_keyring_package \
  "$work/$keyring_pkg" \
  "$work/$keyring_pkg.sig") \
  || die "BlackArch keyring package verification failed"

log "keyring signature ok ($signer)"
```

Only after this verification does the bootstrap process execute the official `strap.sh`.

---

## 6. Keyring Integrity Verification

The original implementation expected a compressed tarball:

```bash
tar xzf "$tarfile" --strip-components=1 -C "$extracted"
```

The updated BlackArch distribution uses a package archive, so extraction was changed to:

```bash
bsdtar -xf "$package" -C "$extracted" || {
  rm -rf "$extracted"
  return 1
}
```

The expected keyring files are now located under the package's filesystem hierarchy:

```bash
for f in "$extracted"/usr/share/pacman/keyrings/blackarch*; do
```

The installed files are compared against those extracted from the independently verified package:

```bash
local base
base=$(basename "$f")

[[ -f $dest/$base ]] || {
  rm -rf "$extracted"
  return 1
}

cmp -s "$f" "$dest/$base" || {
  rm -rf "$extracted"
  return 1
}
```

This preserves an integrity check after the official `strap.sh` has run.

---

## 7. Updated Bootstrap Flow

The resulting verification flow is:

```
Official BlackArch downloads page
        │
        ▼
Download strap.sh
        │
        ▼
Verify strap.sh SHA1
        │
        ▼
Download official blackarch.db
        │
        ▼
Discover blackarch-keyring package
        │
        ▼
Download package + detached signature
        │
        ▼
GPG signature verification
        │
        ▼
Check signer against trusted fingerprints
        │
        ▼
Run official strap.sh
        │
        ▼
Compare installed keyring files
        │
        ▼
Verify repository configuration
```

This removes the dependency on parsing the internal structure of the upstream `strap.sh` script.

---

## 8. Validation

During development, the following checks were performed.

### 8.1 Shell syntax

```bash
bash -n lib/blackarch.sh
```

Shell syntax validation completed successfully.

### 8.2 BlackOmarchy verification

Commands:

```bash
blackomarchy verify
blackomarchy status
```

Output:

```
verify ok
Black omARCHy 0.1.0 installed layer: 0.1.0
Omarchy: 4.0.0.alpha
repos: core extra multilib omarchy blackarch
blackarch stanzas: 1
profiles: core web recon network wireless reversing forensics password
```

This confirmed that the repository was enabled.

### 8.3 Negative tests

> **Status:planned.** Negative testing has not been perfoemed yet. The tests below are planned to demonstrate that the verification rejects bad input, not just that it accepts good input. Results will be added here once they have been run. 

| Test | Expected result | Status |
|---|---|---|
| Tampered package (modify one byte of the `.pkg.tar.*`) | Rejected: no valid signature | Planned |
| Valid signature from a key **not** in `ALLOWED_KEYRING_SIGNERS` | Rejected: `signed by untrusted key` | Planned |
| Missing `.sig` file | Rejected: verification failed | Planned |
| Installed keyring file differs from the verified package | Integrity check fails | Planned |

---

## 9. Threat Model

### What this verification protects against

- A compromised or malicious mirror serving a **tampered keyring package**: the GPG signature would not validate.
- A package signed by an **unknown or unauthorised key**: the signer is not in the allowlist.
- **Local modification of the installed keyring files** after `strap.sh` runs: detected by the file comparison.
- Breakage caused by **changes in the internal format of `strap.sh`**, since it is no longer parsed.

### What it does not protect against

- **Downgrade / replay.** `blackarch.db` is fetched over HTTPS but is not itself signature-verified. A party controlling the mirror could point to an older, validly signed keyring package. Mitigation: also verify `blackarch.db.sig`, or enforce a minimum keyring version.
- **Compromise of the BlackArch signing keys themselves.** Anyone holding an allowed private key can produce an accepted package.
- **Compromise of the allowlist source.** The fingerprints are only as trustworthy as the source they were taken from (see [3.3](#33-provenance-of-the-fingerprints)).
- **Trust in the TLS connection to the keyserver / mirror** for availability. Keyservers cannot forge keys (fingerprints are pinned), but they can refuse to serve them.

---

## 10. Limitations and Possible Improvements

1. **Verify `blackarch.db.sig`** to close the downgrade gap described above.
2. **Distinguish failure modes.** `--verify` currently runs with `2>/dev/null || true`. Parsing `ERRSIG`, `NO_PUBKEY`, `BADSIG` and `VALIDSIG` from `--status-fd` would allow clear messages for "invalid signature", "key not found" and "untrusted signer".
3. **Ship the public keys with the repository** (or pin them locally) to remove the runtime dependency on public keyservers.
4. **Add the negative tests** from section 8.3 to an automated test suite.
