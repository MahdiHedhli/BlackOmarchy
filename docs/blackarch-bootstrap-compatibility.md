# BlackArch bootstrap compatibility

## Why installation failed

The old wrapper expected BlackArch's verified `strap.sh` to declare a
keyring `VERSION` and a `recv-keys` fingerprint. Upstream now discovers a
`blackarch-keyring-*.pkg.tar.*` package through its repository database,
so installation stopped with:

```text
could not parse VERSION or keyring fingerprint from verified strap.sh
```

The script's SHA1 check was not the cause. The wrapper depended on an
obsolete internal script format.

The package-discovery repair was contributed by David Alves in
[pull request #3](https://github.com/MahdiHedhli/BlackOmarchy/pull/3).
The upstream integration retains the original commits and adds negative
tests and stricter verification checks.

## Current verification flow

1. Download the official script and check its SHA1 against the live
   BlackArch downloads page.
2. Fetch the official repository database over HTTPS and read the
   keyring package filename. Reject missing, multiple, malformed, or
   path-containing filenames before using them in a local path.
3. Download that package and its detached GPG signature.
4. Fetch the pinned signing keys into a private, temporary GnuPG home.
   Try `hkps://keyserver.ubuntu.com`, then `hkps://keys.openpgp.org`.
5. Require successful GPG verification and exactly one `VALIDSIG` whose
   primary fingerprint is allowlisted. Reject expired, revoked, missing,
   or invalid signatures even if a `VALIDSIG` status is also present.
6. Execute the verified script unchanged in a separate session without
   a controlling terminal. Current upstream reads its full-upgrade
   prompt from `/dev/tty`; when that read fails, it explicitly declines
   the upgrade. System upgrades remain `omarchy update`.
7. Require all three installed keyring files (`blackarch.gpg`,
   `blackarch-trusted`, `blackarch-revoked`) to match the verified package.
   Missing files, symlinks, extraction errors, and mismatches fail.
8. Check existing packages and repository configuration, then record the
   verified script hash, primary signer fingerprint, and package filename
   under `/var/lib/blackomarchy/`.

An already-enabled BlackArch repository still skips the upstream script.
See [`lib/blackarch.sh`](../lib/blackarch.sh) for the implementation.

## Trust anchors

The allowlist matches the primary keys in the
[official BlackArch script](https://github.com/BlackArch/blackarch-site/blob/master/strap.sh),
cross-checked with
[`blackarch-trusted`](https://github.com/BlackArch/blackarch-keyring/blob/master/blackarch-trusted):

```text
8F9A9793CB8591147C2EC70566E0CDBD1E01F333
A0917C4147A37007CB54C1CFD295AA940EFDDF62
4345771566D76038C7FEB43863EC0ADBEA87E4E3
F9A6E68A711354D84A9B91637533BAFE69A25079
```

These values are pinned in this repository. Downloaded metadata and
keyservers cannot add a signer to the allowlist. `VALIDSIG`'s primary-key
fingerprint allows a package signed by a signing subkey to be checked
against its pinned primary key.

## Validation

Run `bash tests/unit/run.sh`. Regression coverage includes repository
metadata parsing, unsafe and ambiguous filenames, a real GPG signing
subkey, package tampering, missing signatures/keys, untrusted signers,
failed GPG status, expired/revoked status, and installed-keyring file
checks. Tests use temporary directories and generated test keys; they
do not execute the upstream installer or change the host.

The contributor reported a successful install on Omarchy 4.0.4-1. The
upstream integration's automated checks are not a substitute for a fresh
installation on a supported Omarchy VM; see [the VM guide](../tests/vm/README.md).

## Remaining limitations

- The script hash and script come from the same origin. SHA1 detects
  corruption and publication inconsistency, not compromise of that origin.
- The repository database is not independently authenticated. A mirror
  could select an older, validly signed package. Package signature
  verification prevents tampering but does not establish freshness;
  signing the database alone would not prevent replay of an old signed
  database without an additional freshness policy.
- Availability still depends on the mirror and public keyservers.
- Upstream fetches its own copy of the package when its script runs. If
  the package changes between the two downloads, the final comparison
  can fail. Rerun after confirming the upstream change.
- On a failure after the upstream script has run, the wrapper restores
  this run's `pacman.conf`; it cannot undo every upstream keyring or
  package side effect automatically.
