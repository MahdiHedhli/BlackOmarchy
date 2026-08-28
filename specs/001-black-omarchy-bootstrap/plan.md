# Implementation Plan: Black omARCHy v0.1 bootstrap

**Branch**: `001-black-omarchy-bootstrap` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-black-omarchy-bootstrap/spec.md`

## Summary

Ship a boring, auditable POSIX/bash installer that: verifies the host is
x86_64 Omarchy, snapshots Omarchy state, hash-checks the official
BlackArch `strap.sh` against the live downloads page, runs that script,
installs a compatibility-tested `core` profile without system upgrade or
overwrite, installs a thin `blackomarchy` CLI, and proves Omarchy did
not change. Optional profiles and uninstall follow the same rules.

## Technical Context

**Language/Version**: Bash 5.x / POSIX shell helpers, `set -euo pipefail`

**Primary Dependencies**: Host tools already present on Omarchy (`bash`,
`curl`, `sha1sum`, `pacman`, `awk`, `sed`, `python` or `python3` only if
unavoidable; prefer pure shell). Official BlackArch `strap.sh` at
runtime. No Node, no Python app, no extra frameworks.

**Storage**: `/var/lib/blackomarchy/` (state, backups, baseline,
manifest), `/usr/local/share/blackomarchy/` (installed profiles/lib),
`/usr/local/bin/blackomarchy`

**Testing**: Bash unit tests with fixtures (no root). VM integration and
clean-room validation over SSH using operator-local connection info that
never enters the public tree.

**Target Platform**: Omarchy 4.x on Arch Linux, `x86_64` only

**Project Type**: CLI / bootstrap scripts

**Performance Goals**: Bootstrap completes in one operator sitting on a
typical VM; no background daemons.

**Constraints**: No `curl | sh`. No `pacman -Syu` as a side effect. No
`--overwrite='*'`. No Omarchy-owned file edits. No secrets in git.

**Scale/Scope**: One feature covering the entire v0.1 product.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Omarchy remains Omarchy: plan adds repo, packages, CLI, docs only.
- Conflict priority: package resolver excludes conflicts.
- Official BlackArch verified: live SHA1 parse from blackarch.org/downloads.html.
- Fail closed: detect.sh and blackarch.sh abort on ambiguity.
- Idempotent/reversible: backup.sh + stanza helpers + manifest.
- Minimal footprint: packages/core.txt default; no blackarch group.
- Additive only: no Hyprland/menu/theme work in v0.1.
- Public/private split: operator VM docs stay in gitignored `private/`.
- Tests before release: unit + VM A + VM B baseline compare.
- Evidence-backed README: Humanizer pass after tests, not before.

Post-Phase 1 re-check: still pass. strap.sh's commented `verify_keyring`
is documented; we still hash-verify the script. strap.sh `sed` on
pacman.conf is wrapped by a pre/post Omarchy-repo integrity check.

## Project Structure

### Documentation (this feature)

```text
specs/001-black-omarchy-bootstrap/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/cli.md
└── tasks.md
```

### Source Code (repository root)

```text
bootstrap.sh
uninstall.sh
blackomarchy
lib/
  common.sh
  detect.sh
  pacman.sh
  blackarch.sh
  packages.sh
  backup.sh
  baseline.sh
  install_cli.sh
packages/
  core.txt
  web.txt
  recon.txt
  network.txt
  wireless.txt
  reversing.txt
  forensics.txt
  password.txt
config/
  paths.conf
docs/
  architecture.md
  package-profiles.md
  compatibility.md
  uninstall.md
tests/
  unit/
  integration/
  vm/
assets/
LICENSE
README.md
```

Operator-only homelab files remain under gitignored `private/` and are
not part of the public product tree.

## Implementation approach

### Host detection

Require all of:

- `uname -m` is `x86_64`
- `/etc/os-release` `ID=omarchy` or `ID=arch`
- `pacman -Q omarchy` succeeds
- `/usr/share/omarchy/version` is readable
- `command -v omarchy` succeeds

Refuse otherwise. Record version string and `[omarchy]` `Server=` line
as channel evidence.

### Pacman policy

- Never invoke `--sysupgrade` / `-Syu`.
- Prefer per-package `omarchy-pkg-add` (Omarchy's additive path).
  Fall back to `pacman -S --needed --noconfirm` one package at a time.
  Never pass a whole profile as one argv.
- Before each install, print the transaction. If any already-installed
  package would be upgraded, replaced, or removed, skip as CONFLICT.
- Never set `OMARCHY_ALLOW_DIRECT_PACMAN`.
- After any edit to `/etc/pacman.conf`, verify:
  - `[core]`, `[extra]`, `[multilib]`, `[omarchy]` still present
  - `[blackarch]` present exactly once and enabled
  - Omarchy `Server=` line unchanged
- Do not rewrite `/etc/pacman.d/mirrorlist`.
- On any failure after backup, restore this run's `pacman.conf` copy.
- Append the manifest as each package succeeds.
- Install a reversible
  `~/.config/omarchy/hooks/pre-refresh-pacman.d/blackomarchy-blackarch.sh`
  so `omarchy-refresh-pacman` does not silently drop `[blackarch]`.

### BlackArch strap.sh

If `pacman-conf --repo-list` already lists exactly one enabled
`blackarch` and Omarchy repos are intact, skip strap.sh entirely.

Otherwise:

1. Create `mktemp -d` with umask 077.
2. `curl --proto '=https' --tlsv1.2 -fsSL` the downloads page and
   parse SHA1 from the `echo <40 hex> strap.sh` snippet only.
3. Download `strap.sh` the same way.
4. `echo "$sha1  strap.sh" | sha1sum -c --status`.
5. Parse `VERSION=` and the `recv-keys` fingerprint from the verified
   script.
6. Independently download `blackarch-keyring-$VERSION.tar.gz` and
   `.sig` from `https://www.blackarch.org/keyring/` with `-f`.
7. Verify the tarball in a temporary `GNUPGHOME` using that
   fingerprint. Abort if keyserver or signature checks fail.
8. Execute `sh strap.sh` as root.
9. Confirm installed keyring files match the verified tarball.
10. Diff Omarchy-owned pacman settings against the backup. Unexpected
    drift restores this run's backup and fails.

Known upstream behaviors (see research.md): keyring GPG verify is
commented out inside strap.sh; `pacman_upgrade` is defined but not
called; `[blackarch]` grep treats commented stanzas as present, so we
do not trust that check; `sed` deletion is blunt, so we snapshot first.

### Profiles

Plain text, one package per line, comments with `#`. Resolver queries
`pacman -Si`. Missing names become `UNTESTED`/`missing`. Conflicts
become `CONFLICT` and are skipped. Successful installs recorded in the
manifest with classification.

Default `core` covers: network discovery, packet inspection, web
assessment, content discovery, OSINT/recon, Windows/AD assessment,
password/hash utilities, basic reverse engineering, forensics, YARA.

Do not include BlackArch WM/themes, browser replacements, kernels, or
`blackarch` / `blackarch-officials` metapackages.

### Baseline

Capture hashes and inventories to `/var/lib/blackomarchy/baseline/`.
Compare after install. Expected deltas: `[blackarch]` stanza, BlackArch
mirrorlist, keyring files, added packages, CLI paths. Unexpected deltas
in `/usr/share/omarchy`, Omarchy hooks, Hyprland/user omarchy configs,
or removed omarchy packages fail `verify`.

### CLI

`blackomarchy` is a dispatcher that sources `lib/*.sh`. Commands:

- `status` — repos, profiles, omarchy version, drift summary
- `verify` — baseline + repo + hash of installed CLI
- `profiles` — list with install state
- `install <profile>` / `remove <profile>`
- `doctor` — detection, pacman.conf sanity, guard presence, secrets
  scan of project checkout if present

### Uninstall

Always remove the `[blackarch]` block with a stanza parser (not
`sed '/blackarch/{N;d}'`). Restore a whole-file pacman.conf backup
only if the non-blackarch bytes still match the backup. Remove
manifest packages (including `blackarch-mirrorlist`) with
`pacman -Rns` only when no foreign dependents remain. Remove the
pre-refresh hook, CLI, and `/usr/local/share/blackomarchy`. Leave
pacman keyring entries unless a documented, safe removal path exists;
do not `rm -rf /etc/pacman.d/gnupg`.

### Testing

- `tests/unit`: detect, pacman stanza helpers, SHA1 parser, profile
  parser, with fake roots.
- `tests/integration`: optional container/chroot later; not required
  if VM tests cover it.
- `tests/vm`: scripts parameterized by env (`BLACKOMARCHY_SSH_HOST`
  etc.) from gitignored `tests/vm/local.env`. Never hardcode
  infrastructure.

VM A: iterative. VM B: pristine until candidate is ready, then README
as written plus baseline compare, reboot, representative tools,
uninstall.

### Branding

Artwork is a stretch goal and MUST NOT block v0.1. If original SVG
assets are added later, they remain optional in the README.

## Key Decisions

1. **Additive layer, not a distro.** Omarchy UX is upstream-owned.
2. **Execute official strap.sh after live SHA1 verification.** Do not
   reimplement keyring install unless strap.sh becomes unusable.
3. **No system upgrade during bootstrap.** Respect Omarchy's update
   guard and snapshot path.
4. **Repo priority stays Omarchy/Arch first.** BlackArch is appended.
5. **Profiles are compatibility certificates.** Conflicts are excluded.
6. **Thin bash CLI.** Auditable by reading.
7. **Secrets never leave `private/`.** Public git history starts from
   an orphan commit of the public tree if the local repo still contains
   operator files in older commits.
8. **MIT license** with trademark/affiliation disclaimer.

## Risks

- BlackArch package vs Omarchy delayed Arch mirror skew.
- strap.sh `sed` on pacman.conf is blunt; mitigated by backup + verify.
- Graphical UX checks are incomplete over SSH; mitigated by reboot +
  package/config baseline + documented remaining checks.
- Upstream strap.sh hash can change; live parse handles that, tests
  must tolerate a new official hash.

## PR Plan

v0.1 is one public repository on `main`, not a stack of product PRs.

### PR 1: Public v0.1

- **Files**: entire public product tree listed above, Spec Kit artifacts,
  LICENSE, README
- **Dependencies**: none
- **Description**: Spec, bootstrap, CLI, profiles, docs, tests, after
  Gate 1 and Gate 2 reviews and clean-room validation
