# Black omARCHy Constitution

Canonical governance for every specification, plan, task list, and
implementation. A violation requires an explicit, documented exception in
the corresponding spec. Silence is not an exception.

**Version**: 1.0.0 | **Ratified**: 2026-08-28 | **Last Amended**: 2026-08-28

## I. Omarchy remains Omarchy (non-negotiable)

Black omARCHy is an additive security capability layer for a supported
Omarchy installation. It is not a Linux distribution, not an ISO, not a
fork of Omarchy, and not a mandate to harden, restyle, or otherwise
"improve" Omarchy.

A successful installation must feel like the same Omarchy workstation,
now with BlackArch security capabilities available.

Unless strictly required to add BlackArch repository compatibility, do
not modify:

- Omarchy shell, themes, menus, keybindings, or visual design
- Hyprland configuration
- default Omarchy applications, terminals, launchers, or panels
- Omarchy's update mechanism or snapshot/migration path
- Omarchy package repository configuration beyond the minimum addition
  of the official BlackArch repository
- system services configured by Omarchy
- security or hardening defaults shipped by Omarchy
- Docker or container configuration
- login, session, or boot configuration
- desktop appearance or user workflow

Do not replace an Omarchy component because another component is more
security-oriented. Do not disable an Omarchy feature because a
conventional security workstation would disable it. Do not convert the
host from Omarchy's supported Arch package and update model into generic
upstream Arch.

Design test for every proposed change: does Black omARCHy actually
require this, or are we trying to make Omarchy more like a security
distribution? If the latter, do not make the change.

## II. Conflict priority

When BlackArch and Omarchy conflict:

1. Preserve a functioning Omarchy installation.
2. Preserve Omarchy's supported update path.
3. Exclude or defer the conflicting BlackArch package.
4. Find an isolated alternative for that security capability.
5. Only consider modifying Omarchy itself as a last resort, and stop for
   architectural review before doing so.

A BlackArch package that requires damaging Omarchy is not part of the
supported Black omARCHy package set.

Package classification for curated profiles:

- `PASS` — installs cleanly, no Omarchy regression observed
- `PASS WITH DEPENDENCIES` — installs with additional packages that do
  not alter Omarchy-owned behavior
- `ISOLATE` — capability is useful but must be delivered without a
  conflicting package (container, separate profile, or documented
  manual path)
- `CONFLICT` — excluded; would require changing Omarchy
- `UNTESTED` — must not ship in a default profile

Curated profiles are a compatibility-certified subset of BlackArch for
Omarchy, not a shopping list of popular hacking tools.

## III. Official BlackArch, verified before execute

Use BlackArch's official repository bootstrap. Do not mirror thousands
of security packages. Do not invent an unofficial replica of strap.sh.

Never pipe remote content into a root shell (`curl | sudo bash` is
forbidden).

The bootstrap MUST:

1. Download the official BlackArch strap script independently.
2. Independently retrieve the currently published verification value
   from an official BlackArch source (the downloads page on
   blackarch.org).
3. Verify the downloaded script against that value.
4. From the verified script, read the keyring VERSION and the GPG
   fingerprint it names. Independently download the keyring tarball
   and signature, and verify the tarball with that fingerprint.
   Abort if that verification cannot be performed.
5. Abort on mismatch, parse failure, or transport failure.
6. Execute the verified script only after those checks pass.
7. After execution, confirm the installed keyring files match the
   independently verified tarball. Abort and restore this run's
   pacman.conf backup on mismatch.

Upstream strap.sh currently comments out its own keyring signature
check. Script SHA1 is necessary and not sufficient. Same-origin HTML
hash detection is not independent attestation of BlackArch package
trust.

Do not use `--overwrite='*'` as a blanket default. Package conflicts
must be investigated, classified, and usually excluded.

## IV. Fail closed

Unsupported architecture, unsupported OS, missing Omarchy evidence,
unavailable package repositories, failed checksum verification,
ambiguous pacman state, or an unexpected change to Omarchy-owned
configuration MUST terminate cleanly with a non-zero status and a
message that does not leak local secrets.

Omarchy detection MUST use reliable system evidence (installed `omarchy`
package, `/usr/share/omarchy/version`, `omarchy` command, and
`/etc/os-release` `ID=omarchy` or `ID=arch`). Hostname, wallpaper, and
cosmetic markers are not evidence.

v0.1 supports `x86_64` only.

## V. Idempotent and reversible

Re-running bootstrap MUST NOT:

- duplicate the `[blackarch]` pacman stanza
- corrupt `/etc/pacman.conf`
- rewrite Omarchy repository or mirror configuration
- reinstall or reconfigure destructively
- run a full system upgrade as a side effect
- re-execute strap.sh when an enabled `blackarch` repo is already
  present and Omarchy repos are intact

Package installation MUST NOT upgrade, replace, or remove
already-installed packages as a side effect. A transaction that would
do so is a conflict: exclude the candidate. Never set
`OMARCHY_ALLOW_DIRECT_PACMAN`.

Uninstall reverses Black omARCHy-owned additions with a stanza parser
and the install manifest. It restores a whole `pacman.conf` backup only
when the non-blackarch bytes still match that backup. It must not roll
Omarchy channel or mirror configuration backward.

Installation MUST capture enough pre-change state to reverse
Black omARCHy repository and configuration changes later without
restoring Omarchy by guesswork.

Uninstall restores Black omARCHy-owned additions. It does not
redecorate Omarchy and it does not wipe the pacman keyring wholesale.

## VI. Minimal default footprint

Do not install the complete `blackarch` package group or
`blackarch-officials` by default.

`blackomarchy install all` means all Black omARCHy curated profiles.
It does not mean every package in BlackArch.

Default `core` is a practical professional baseline and must remain a
small, compatibility-tested set.

## VII. Additive integration only

Black omARCHy may add:

- the official BlackArch repository and required signing material
- curated BlackArch packages
- Black omARCHy package manifests and state
- a thin `blackomarchy` management CLI
- project-owned documentation
- optional integrations that use officially supported Omarchy
  extension points

Any optional desktop integration must be additive, reversible, isolated
from upstream-owned files, and unnecessary for core functionality.

If an integration requires patching an Omarchy-owned file, skip it for
v0.1 unless there is no reasonable alternative. v0.1 ships without
menu, theme, or keybinding changes.

The CLI MUST be thin, auditable shell. No application framework is
justified for v0.1.

## VIII. Public and private data separation

Local operator infrastructure, VM addresses, credentials, SSH keys,
host fingerprints, and `private/` are secret local input.

They MUST never be committed, copied into generated documentation,
emitted in logs intended for publication, included in GitHub issues,
included in Spec Kit artifacts, or otherwise exposed.

`.gitignore` MUST exclude `private/` before any public commit.

Tracked documentation uses only synthetic examples. Before any public
push, search the tree and git history for secrets.

## IX. Tests before release; evidence-backed claims

No README claim may outrun tested behavior.

Tests MUST prove two things, not one:

1. Documented BlackArch capabilities are present.
2. The pre-existing Omarchy desktop, configuration, application set,
   update path, and user experience were not materially changed.

Capture a sanitized pre-install baseline on a clean Omarchy system and
compare it after installation. Unexpected Omarchy changes are
regressions even if the security tools work.

Release language is experimental until those tests pass. Do not imply
affiliation with or endorsement by Omarchy, BlackArch, or Arch Linux
unless a formal relationship exists.

## X. Reproducibility and honesty

Prefer clone, read, and run over a one-line remote root shell.

Pin or live-confirm verification data from official sources. Record
what was verified. If a package was excluded for conflict, say so.

## Governance

This constitution supersedes informal preference. Amendments require
an updated version, date, and a short migration note in this file.

Spec Kit artifacts and implementation MUST include a constitution
check. Complexity that is not required by BlackArch compatibility is
a defect.

Adversarial review is mandatory at two gates: specification/plan, and
implementation/release. Blocking findings stop the release.
