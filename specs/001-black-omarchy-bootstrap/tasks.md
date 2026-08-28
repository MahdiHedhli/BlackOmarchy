# Tasks: Black omARCHy v0.1 bootstrap

**Input**: `specs/001-black-omarchy-bootstrap/` spec, plan, research,
data-model, contracts

**Prerequisites**: constitution.md, spec.md, plan.md

## Phase 1: Setup

- [ ] T001 Confirm `.gitignore` excludes `private/`, VM env files, and
      Spec Kit machine-local pointers
- [ ] T002 [P] Add MIT `LICENSE` and affiliation-safe copyright notice
- [ ] T003 [P] Add `config/paths.conf` with install/state paths only
- [ ] T004 Create empty public tree: `lib/`, `packages/`, `docs/`,
      `tests/{unit,integration,vm}`, `assets/`

## Phase 2: Foundational libraries

- [ ] T005 Implement `lib/common.sh` (logging, die, require_root,
      quoting-safe tempdirs, umask 077)
- [ ] T006 [P] Implement `lib/detect.sh` (x86_64, Arch, Omarchy
      evidence, fail closed)
- [ ] T007 [P] Implement `lib/pacman.sh` (stanza parse, duplicate
      detection, no -Syu, omarchy-pkg-add wrapper, conflict capture)
- [ ] T008 [P] Implement `lib/backup.sh` (timestamped copies of
      pacman.conf and related files)
- [ ] T009 [P] Implement `lib/baseline.sh` (capture + compare +
      expected-delta allowlist)
- [ ] T010 Implement `lib/blackarch.sh` (live SHA1 parse, keyring
      signature wrap, skip strap when repo enabled, execute strap.sh,
      post-check Omarchy repos and keyring files)
- [ ] T011 Implement `lib/packages.sh` (profile load, resolve, classify,
      manifest write)
- [ ] T012 Unit tests for detect, SHA1 parser, pacman stanza helpers,
      profile parser under `tests/unit/`

**Checkpoint**: libraries testable without installing BlackArch

## Phase 3: US1 Additive bootstrap (P1)

- [ ] T013 Write `packages/core.txt` with conservative candidates
- [ ] T014 Implement `bootstrap.sh` wiring detect → backup → baseline →
      verify strap → execute → refresh → core install → CLI install →
      compare → summary
- [ ] T015 Implement `lib/install_cli.sh` installing CLI and profiles
      to `/usr/local`
- [ ] T016 Refuse `--overwrite='*'` and full BlackArch group installs
- [ ] T017 Document architecture in `docs/architecture.md`

## Phase 4: US2 Fail closed and idempotence (P1)

- [ ] T018 Bootstrap second-run path skips duplicate `[blackarch]` and
      does not rewrite Omarchy mirrors
- [ ] T019 Hash-mismatch fixture test in `tests/unit/`
- [ ] T020 Unsupported arch/OS tests in `tests/unit/`
- [ ] T021 Pacman.conf post-condition checks fail the run on Omarchy
      repo drift

## Phase 5: US3 CLI and optional profiles (P2)

- [ ] T022 [P] Write remaining profile files: web, recon, network,
      wireless, reversing, forensics, password
- [ ] T023 Implement `blackomarchy` dispatcher per `contracts/cli.md`
- [ ] T024 `install all` expands curated profiles only
- [ ] T025 `status` / `verify` / `doctor` / `profiles` / `remove`
- [ ] T026 `docs/package-profiles.md` and `docs/compatibility.md`
      (classifications filled from VM evidence, not guesses)

## Phase 6: US4 Uninstall (P2)

- [ ] T027 Implement `uninstall.sh` from backup + manifest
- [ ] T028 Do not delete `/etc/pacman.d/gnupg`; do not touch Omarchy
      files
- [ ] T029 `docs/uninstall.md`

## Phase 7: VM evidence and Omarchy non-regression

- [ ] T030 [P] `tests/vm/` harness using env vars, never hardcoded
      infrastructure
- [ ] T031 VM A: iterative bootstrap, package name resolution, conflict
      classification
- [ ] T032 VM B: README as written on a clean snapshot; baseline
      compare; reboot into graphical session; representative tools;
      real `omarchy update`; uninstall
- [ ] T033 Record compatibility evidence in `docs/compatibility.md`
      using only sanitized names and results
- [ ] T034 Secret scan of the public tree and `git grep` for values
      from local operator files without copying those values into
      tracked files

## Phase 8: Public README, review, release

- [ ] T035 Draft README covering required sections; no fake marketing;
      no remote root pipe
- [ ] T036 Humanizer pass on README
- [ ] T037 Gate 2 adversarial review of the implementation
- [ ] T038 Repair blocking findings and re-review
- [ ] T039 Orphan or otherwise publish git history that excludes
      operator files and secrets
- [ ] T040 Create public GitHub repository `BlackOmarchy` under the
      authenticated account and push `main`

## Stretch (after definition of done)

- [ ] T041 Optional original SVG identity under `assets/` if quality
      is high enough to include
- [ ] T042 CI shellcheck
- [ ] T043 Optional Omarchy menu extension via official JSONC overlay
      only if it does not patch Omarchy-owned files
