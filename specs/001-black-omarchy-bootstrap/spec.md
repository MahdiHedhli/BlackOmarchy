# Feature Specification: Black omARCHy v0.1 bootstrap

**Feature Branch**: `001-black-omarchy-bootstrap`

**Created**: 2026-08-28

**Status**: In Review

**Input**: Convert a clean supported Omarchy installation into a curated
security workstation by adding the official BlackArch repository, a
compatibility-tested package subset, and a thin management CLI, without
materially changing Omarchy.

## Summary

A user with a clean x86_64 Omarchy installation clones this project,
reads the bootstrap, and runs it. The host gains the official BlackArch
repository and a small curated toolset. Omarchy's desktop, applications,
configuration, keybindings, and update path remain the same. The layer
is idempotent and reversible.

This is the complete v0.1 product, not a slice of it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Additive bootstrap (Priority: P1)

An operator starts from a supported Omarchy install, inspects
`bootstrap.sh`, and runs it with sudo. The script detects architecture
and Omarchy, records a baseline, verifies the official BlackArch strap
script against the currently published official hash, adds the BlackArch
repository, installs the `core` profile, installs the `blackomarchy`
CLI, compares the baseline, and prints a short summary.

**Why this priority**: Without a safe additive install there is no
product.

**Independent Test**: On a clean Omarchy system, follow the README
install steps as written. Afterwards, BlackArch tools from `core` run,
and the Omarchy session and `omarchy update` path still work.

**Acceptance Scenarios**:

1. **Given** a clean supported x86_64 Omarchy install, **When** the
   documented bootstrap is run, **Then** the BlackArch repository is
   present exactly once, the `core` profile packages that classified
   `PASS` or `PASS WITH DEPENDENCIES` are installed, and the
   `blackomarchy` CLI is on PATH.
2. **Given** the same host after a successful bootstrap, **When** the
   operator launches the graphical Omarchy session and uses existing
   applications, **Then** desktop appearance, default applications, and
   session behavior match the pre-install baseline.
3. **Given** a successful bootstrap, **When** the operator runs
   Omarchy's supported update command, **Then** the command still
   functions or any incompatibility is documented as a release blocker
   rather than hidden.

---

### User Story 2 - Safe failure and idempotence (Priority: P1)

The bootstrap refuses unsafe conditions and can be re-run without
corrupting pacman configuration.

**Why this priority**: A security workstation installer that damages
pacman or Omarchy is worse than no installer.

**Independent Test**: Exercise unsupported OS/arch, hash mismatch, and a
second bootstrap on an already-converted host.

**Acceptance Scenarios**:

1. **Given** a non-x86_64 host or a host that is not Omarchy, **When**
   bootstrap runs, **Then** it exits non-zero before changing
   repositories or installing packages.
2. **Given** a downloaded strap script whose hash does not match the
   currently published official value, **When** bootstrap verifies it,
   **Then** it aborts without executing the script.
3. **Given** a host already converted by Black omARCHy, **When**
   bootstrap is run again, **Then** `/etc/pacman.conf` still contains
   exactly one `[blackarch]` stanza, Omarchy repository entries are
   unchanged, and the run completes without destructive reconfiguration.

---

### User Story 3 - Curated profiles and CLI (Priority: P2)

After bootstrap, the operator uses `blackomarchy` to inspect status,
verify the layer, list profiles, and install or remove optional
profiles. `install all` means all curated Black omARCHy profiles.

**Why this priority**: Profiles are the project's compatibility filter.
The CLI is how that filter is applied after day one.

**Independent Test**: `blackomarchy status`, `verify`, `profiles`,
`install web`, `remove web` on a converted host.

**Acceptance Scenarios**:

1. **Given** a converted host, **When** the operator runs
   `blackomarchy status` and `blackomarchy verify`, **Then** both report
   repository presence, profile state, and Omarchy baseline drift.
2. **Given** a converted host, **When** the operator runs
   `blackomarchy install web`, **Then** only packages in the `web`
   profile that resolve cleanly are installed; conflicts are classified
   and skipped rather than forced.
3. **Given** `blackomarchy install all`, **When** it runs, **Then** it
   installs curated profiles only and does not install the complete
   BlackArch group.

---

### User Story 4 - Reversible uninstall (Priority: P2)

The operator can remove Black omARCHy-owned repository configuration
and packages they installed through the project, leaving Omarchy
intact.

**Why this priority**: Reversibility is a product principle and a
recovery path.

**Independent Test**: Uninstall on a converted host and confirm Omarchy
still boots and updates.

**Acceptance Scenarios**:

1. **Given** a converted host with a recorded manifest, **When**
   `uninstall.sh` runs, **Then** the `[blackarch]` stanza is removed,
   Black omARCHy-installed packages in the manifest are removed if
   otherwise unused, and Omarchy-owned configuration is untouched.
2. **Given** a converted host whose Omarchy channel or pacman.conf may
   have changed after install, **When** uninstall completes, **Then**
   the `[blackarch]` stanza is gone, Omarchy repository configuration
   is not restored from an old backup, and Omarchy remains usable.

---

### Edge Cases

- Strap.sh already present from a previous manual BlackArch install:
  detect existing `[blackarch]`, do not duplicate, continue with
  profiles if Omarchy baseline is still valid.
- A `core` package name does not exist in the live repositories:
  skip, record `UNTESTED`/`missing`, do not abort the whole profile
  unless the profile becomes empty.
- A package conflicts with an Omarchy-owned package: classify
  `CONFLICT`, exclude, continue.
- Pacman database lock or interrupted transaction: fail closed.
- Official downloads page unreachable or hash line unparsable: fail
  closed, do not fall back to executing an unverified script.
- Operator runs bootstrap without reading it: still permitted; README
  must not advertise a one-line remote root pipe.
- Graphical session cannot be driven from SSH: capture what can be
  captured (packages, configs, services, `omarchy` CLI) and document
  remaining session checks.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Bootstrap MUST detect `x86_64` and refuse other
  architectures.
- **FR-002**: Bootstrap MUST confirm Omarchy using reliable system
  evidence: the `omarchy` package query, `/usr/share/omarchy/version`,
  and the `omarchy` command. Cosmetic markers are insufficient.
- **FR-003**: Bootstrap MUST record a timestamped backup and a
  sanitized baseline of pacman configuration, configured repos/mirrors,
  Omarchy channel if detectable, Omarchy package versions, hashes of
  selected Omarchy-owned files, and the explicit package set.
- **FR-004**: Bootstrap MUST download BlackArch's official strap script
  over HTTPS to a private temporary directory.
- **FR-005**: Bootstrap MUST retrieve the currently published strap.sh
  SHA1 from the official BlackArch downloads page by matching the
  `echo <40 hex> strap.sh` snippet (not the first SHA1 on the page)
  and verify the downloaded script before execution. Fetch page and
  script with HTTPS only (`curl --proto '=https' --tlsv1.2 -fsSL`).
- **FR-006**: Bootstrap MUST abort on hash mismatch, parse failure, or
  download failure without executing the script.
- **FR-006a**: After script verification, bootstrap MUST parse VERSION
  from the verified script, independently download
  `blackarch-keyring-$VERSION.tar.gz` and `.sig`, parse the issuer
  fingerprint from the signature, retrieve that key, verify the
  tarball in a temporary GnuPG homedir, and abort if verification
  cannot be performed. The `recv-keys` fingerprint inside strap.sh is
  recorded for audit; it is not the sole trust anchor because it can
  be stale relative to the live tarball.
- **FR-007**: Bootstrap MUST execute the verified strap script only
  after FR-005 and FR-006a pass, and MUST NOT pipe it from the network
  into a shell in one step. After execution, installed keyring files
  MUST match the independently verified tarball or the run restores
  this run's pacman.conf backup and aborts.
- **FR-007a**: If `pacman-conf --repo-list` already contains exactly
  one enabled `blackarch` repository and Omarchy repos are intact,
  bootstrap MUST NOT execute strap.sh. A commented or ambiguous
  `[blackarch]` match is fail-closed.
- **FR-008**: Bootstrap MUST NOT perform a full system upgrade
  (`pacman -Syu` / `--sysupgrade`) and MUST NOT set
  `OMARCHY_ALLOW_DIRECT_PACMAN`. Metadata refresh inside official
  strap.sh is tolerated only on the first repo-add path.
- **FR-009**: Bootstrap MUST install profile packages one at a time
  using `omarchy-pkg-add` when present, otherwise
  `pacman -S --needed` without `--overwrite='*'` and without `-u`.
- **FR-010**: Before installing a candidate, bootstrap MUST print the
  pacman transaction. If any already-installed package would be
  upgraded, replaced, or removed, or if the package Conflicts/Replaces
  Omarchy-owned packages, or if it is a kernel/DM/WM/NetworkManager
  replacement or a BlackArch metapackage, classify CONFLICT, skip, and
  continue. File conflicts are classified the same way. Missing names
  are skipped without aborting the profile unless the profile becomes
  empty.
- **FR-011**: Bootstrap MUST install the `blackomarchy` CLI and project
  state under project-owned paths.
- **FR-012**: Bootstrap MUST compare the post-install system to the
  pre-install Omarchy baseline. Unexpected Omarchy-owned file or
  repository changes are failures (non-zero exit). Added BlackArch
  packages and the `[blackarch]` stanza are expected.
- **FR-013**: Bootstrap MUST print a concise completion summary
  including what was added, what was excluded, and that Omarchy is
  unchanged.
- **FR-014**: Re-running bootstrap MUST be safe: no duplicate
  `[blackarch]` stanza, no Omarchy repo rewrite, no destructive
  reconfigure, and no second execution of strap.sh when an enabled
  `blackarch` repo is already present.
- **FR-015**: `blackomarchy` MUST support `status`, `verify`,
  `profiles`, `install <profile>`, `remove <profile>`, and `doctor`.
- **FR-016**: Profiles `core`, `web`, `recon`, `network`, `wireless`,
  `reversing`, `forensics`, and `password` MUST exist. `all` means those
  curated profiles, not the BlackArch group.
- **FR-017**: Uninstall MUST reverse Black omARCHy-owned repository and
  package additions using a stanza parser and the install manifest.
  Whole-file pacman.conf restore is allowed only when non-blackarch
  bytes still match the backup. `blackarch-mirrorlist` and the
  pre-refresh hook are in the manifest.
- **FR-018**: v0.1 MUST NOT modify Omarchy shell, themes, Hyprland
  config, keybindings, menus, or default applications.
- **FR-019**: Public artifacts MUST NOT contain local infrastructure
  secrets, addresses, credentials, or `private/` contents.
- **FR-020**: README MUST describe what the project is and is not,
  experimental status, prerequisites, architecture support, install,
  profiles, verification, updating, uninstall, limitations, security
  model, contributing, and affiliation disclaimer.

### Key Entities

- **Baseline snapshot**: Pre-install Omarchy evidence used to detect
  regressions.
- **Backup set**: Timestamped copy of pacman configuration and related
  files sufficient to reverse repository changes.
- **Package profile**: Named list of candidate BlackArch/Arch packages
  with compatibility classification.
- **Install manifest**: Packages and files Black omARCHy actually added.
- **Compatibility record**: PASS / PASS WITH DEPENDENCIES / ISOLATE /
  CONFLICT / UNTESTED for each candidate.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A clean supported Omarchy VM gains the documented
  BlackArch capabilities from the README steps without materially
  changing its pre-existing Omarchy desktop, configuration, application
  set, update behavior, or user experience.
- **SC-002**: Official BlackArch repository addition uses a
  hash-verified strap script; a tampered script is refused.
- **SC-003**: Second bootstrap leaves a single `[blackarch]` stanza and
  does not alter Omarchy repository configuration.
- **SC-004**: `blackomarchy verify` exits 0 on a healthy converted
  host.
- **SC-005**: After reboot, Omarchy graphical session starts and
  representative `core` tools execute.
- **SC-006**: Uninstall removes Black omARCHy-owned repo configuration
  and leaves Omarchy usable.
- **SC-007**: Repository history and public files contain no secrets
  from `private/`.
- **SC-008**: Independent adversarial review of the implementation has
  no unresolved blocking findings.

## Assumptions

- Target is Omarchy 4.x packaged install (`omarchy` and
  `omarchy-settings` packages, files under `/usr/share/omarchy`), not
  the older git-in-home layout as the only supported form.
- Omarchy's ALPM update guard blocks direct `pacman -Syu` but allows
  `pacman -S --needed` package addition. Bootstrap never sets
  `OMARCHY_ALLOW_DIRECT_PACMAN`. If official strap.sh cannot proceed
  without a sysupgrade, abort for architectural review.
- Supported package set is stable/rc packaged Omarchy (`omarchy` +
  `omarchy-settings`). `omarchy-dev` is detected only to refuse with
  an unsupported-channel message, not "not Omarchy."
- `omarchy-refresh-pacman` overwrites pacman.conf from a template.
  v0.1 installs a reversible user hook under
  `~/.config/omarchy/hooks/pre-refresh-pacman.d/` so the BlackArch
  stanza is re-appended after that rewrite. The hook is user-owned,
  optional for core tooling once the repo is present, and removed on
  uninstall. `omarchy update` on VM B is a real update, not a dry run.
- BlackArch strap.sh appends `[blackarch]` after existing repos, so
  Omarchy/Arch packages keep repo priority for identical names.
- Live BlackArch package names will be resolved against the repository
  during implementation; the spec names categories, not a frozen
  guarantee of every candidate string.
- Desktop session checks may be partially observed over SSH; remaining
  graphical checks are still required on the clean-room VM.
- No formal affiliation with Omarchy, BlackArch, or Arch Linux exists.

## Constitution Check

| Constraint | Applies? | How this feature complies |
| --- | --- | --- |
| Omarchy remains Omarchy | Yes | Additive repo + packages + CLI only; no desktop surgery |
| Conflict priority | Yes | Exclude conflicting packages; never rewrite Omarchy to fit them |
| Official BlackArch, verified | Yes | Live official SHA1 plus keyring signature wrap |
| Fail closed | Yes | Arch, Omarchy evidence, hash, pacman state |
| Idempotent and reversible | Yes | Skip strap when repo enabled; surgical uninstall |
| Minimal default footprint | Yes | `core` only by default; `all` is curated profiles |
| Additive integration only | Yes | No menu/theme/keybind changes in v0.1 |
| Public/private separation | Yes | `private/` gitignored; public docs sanitized |
| Tests before release | Yes | Baseline compare + clean-room README execution |
| Evidence-backed claims | Yes | README limited to tested behavior |

## Out of Scope

- Building a Linux distribution or ISO
- Installing the full BlackArch group
- Omarchy menu entries, Hyprland shortcuts, themed terminals (stretch)
- Changing Omarchy mirrors to "real-time Arch" to resolve skew
- Hardening Omarchy (firewall, mandatory access control, disabling
  features)
- Replacing Omarchy packages with "more secure" alternatives
- ARM or non-Omarchy Arch hosts
- One-line `curl | sudo bash` install
- Operator homelab VM build tooling (local `private/operator` only)

## Open Questions

None that block v0.1 design. Package names in profiles are resolved
against live repositories during implementation; unresolved names are
dropped from the shipped default with a recorded reason.
