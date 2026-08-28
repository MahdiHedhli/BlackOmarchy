# Gate 1 adversarial review — Black omARCHy v0.1 bootstrap

**Reviewer role**: security auditor
**Date**: 2026-08-28
**Scope**: specification/plan artifacts only. No product source was implemented or patched. Independent confirmation of `https://blackarch.org/downloads.html` and `https://blackarch.org/strap.sh` (VERSION=20251011) plus public Omarchy docs/source. No SSH, no VM credentials, no `private/` files.

## Summary

The architecture is the right shape: additive layer, official strap.sh, no `curl | sh`, no `-Syu`, no `--overwrite='*'`, conflict-exclusion instead of Omarchy surgery, fail-closed host detection, and tests that are supposed to prove Omarchy did not change. It cannot proceed to implementation until four design holes are closed in the spec/plan. Dominant risks are (1) hash-verifying strap.sh and then letting it install an **unsigned** keyring tarball as root, (2) `pacman -Syy` plus profile installs performing a **partial upgrade** of already-installed Omarchy/Arch packages without snapshot/migrations, (3) uninstall **restoring a whole pre-install `pacman.conf`**, which can roll Omarchy's own repo/channel config backward, and (4) re-running bootstrap still **executes strap.sh**, which is not idempotent even when `[blackarch]` already exists.

## Attempts to refute

### 1. Safety of the repository-bootstrap approach (official strap.sh after SHA1 verification)

**Verdict: holds with changes**

**Evidence.** Live `https://blackarch.org/downloads.html` still publishes SHA1 `00688950aaf5e5804d2abebb8d3d3ea1d28525ed` for strap.sh, matching `research.md:8-10`. Independently fetched `https://blackarch.org/strap.sh` matches `research.md:13-24`: `VERSION=20251011`; `verify_keyring` is defined and **commented out** at the call site; the `.sig` is downloaded then deleted; `tar xfz` extracts `https://www.blackarch.org/keyring/blackarch-keyring-$VERSION.tar.gz` into `/usr/share/pacman/keyrings/`; `pacman-key --populate` runs with no keyring argument; `sed -i '/blackarch/{N;d}' /etc/pacman.conf` rewrites the stanza; `pacman -Syy` then `pacman -S --noconfirm blackarch-mirrorlist`; `pacman_upgrade` (`pacman -Su`) is defined and **not called**. `constitution.md:90-92` and `plan.md:60-62` already know the keyring check is disabled and treat script SHA1 as the compensating control.

That compensation does not cover the actual TCB expansion. SHA1 is retrieved from the **same origin** as strap.sh, so it detects split-brain/corruption, not site or CDN compromise. After the wrapper's hash check, strap.sh fetches the keyring from **`www.blackarch.org`**, a different host than `blackarch.org/strap.sh`, with `curl -s -O` (no `-f`, no checksum). The verified script then untars that blob as root (`--strip-components=1 -C /usr/share/pacman/keyrings/`) and populates pacman trust. A crafted tarball is a tar-slip and a trust-injection: it becomes a signing key for every later BlackArch package. Official downloads.html also tells operators to run `pacman -Syu` and `--overwrite='*'` after strap.sh; the spec correctly forbids both, which is good, but it does not wrap the unsigned extract.

**What would break.** A compromised or substituted keyring on `www.blackarch.org` (or a failed download saved as an HTML body named `.tar.gz`) is installed as trusted pacman keys. Subsequent `pacman -S` of "verified" BlackArch packages is then attacker-signed. The SHA1 check of strap.sh never sees that substitution.

### 2. Assumptions about Omarchy detection

**Verdict: holds with changes**

**Evidence.** `plan.md:126-135` and `spec.md:160-164` require the constitution triad (`pacman -Q omarchy`, `/usr/share/omarchy/version`, `command -v omarchy`) plus `uname -m == x86_64` and `ID=arch`. Cosmetic markers are correctly rejected (`constitution.md:105-107`). Packaged Omarchy 4.x does ship `/usr/share/omarchy/version` (omarchy PKGBUILD). Public Omarchy update docs also state that edge/dev install `omarchy-dev` / `omarchy-settings-dev` instead of `omarchy`, and that `omarchy-version` may derive from `pacman -Q` rather than a version file. Detection as written will refuse those hosts as "not Omarchy".

**What would break.** A supported-looking Omarchy edge/dev workstation is rejected with a false "not Omarchy" error, or a future package that drops the version file fails closed (acceptable) without a clear unsupported-channel message. Stock detection is otherwise fail-closed and not spoofable by hostname/wallpaper.

### 3. pacman/repository assumptions (guard, -Syu, repo order, strap.sh sed)

**Verdict: holds with changes**

**Evidence.** Public `omarchy-update-pacman-guard` exits 0 unless the parent pacman argv is **sync and sysupgrade**. `pacman -S --needed`, `pacman -Sy`, and `pacman -Syy` are allowed. `omarchy-pkg-add` is `sudo pacman -S --noconfirm --needed` (`research.md:57-58` confirmed). Repo **order** assumption holds: `pacman.conf(5)` and ArchWiki state the first repository that contains a given name wins **regardless of version**, so appending `[blackarch]` does not steal `extra/nmap` on `-S` or `-Syu`. `omarchy update` itself does **not** rewrite `pacman.conf`; `omarchy-refresh-pacman` **does** (`cp -f` of `pacman-$channel.conf`), then runs the documented `pre-refresh-pacman` hook that exists specifically for custom repositories. The spec never mentions that hook.

The dangerous assumption is "refresh without `-Syu` is therefore safe." `strap.sh` always runs `pacman -Syy` (all repos, forced). Bootstrap then installs profile packages (`plan.md:141-142`, `spec.md:177-185`). Arch's documented partial-upgrade failure mode is exactly `-Sy` + `-S`: newly synced `extra`/`core` metadata lets a BlackArch tool upgrade already-installed libraries (python, openssl, libpcap, etc.) **without** Omarchy's snapshot, migrations, or `omarchy update`. Conflict classification via `pacman -Si` name conflicts (`spec.md:145-146`, `plan.md:169-172`) does not see "this install would upgrade an already-installed package."

`sed -i '/blackarch/{N;d}'` is as blunt as research says. On a stock Omarchy `pacman-stable.conf` there is no `blackarch` substring, so first-run is safe. Any comment or Include line containing that substring deletes that line **and the next line**, which can delete `[omarchy]`. The wrapper diffs after the damage (`plan.md:159-160`).

`spec.md:257-260` documents an exception: `OMARCHY_ALLOW_DIRECT_PACMAN` may be set if "a required BlackArch strap step cannot proceed otherwise." strap.sh does not need that variable. The exception is a ready-made bypass of the guard.

**What would break.** Core/extra packages change under the operator without `omarchy update`. Later `omarchy refresh pacman` / channel switch / `omarchy reinstall` wipes `[blackarch]`. A sed false positive leaves a broken `[omarchy]` stanza; fail-closed then exits with pacman already damaged. An implementer hitting friction sets `OMARCHY_ALLOW_DIRECT_PACMAN=1` and performs a real sysupgrade.

### 4. Idempotence

**Verdict: holds with changes**

**Evidence.** Constitution V (`constitution.md:113-119`) forbids duplicate stanzas, Omarchy repo rewrite, destructive reconfigure, and upgrade-as-side-effect. strap.sh skips the stanza if `grep -q "\[blackarch\]"` (`research.md:19-20`, confirmed). It still always: re-fetches and extracts the keyring, runs `pacman-key --populate`, runs `pacman -Syy`, installs `blackarch-mirrorlist`, and `mv`s a `.pacnew` over `/etc/pacman.d/blackarch-mirrorlist` if present. `plan.md:149-160` still executes `sh strap.sh` as the bootstrap path. `tasks.md` T018 only says the second run skips a duplicate stanza. `grep "\[blackarch\]"` also matches a commented-out stanza, so strap.sh may skip adding a repo that is not actually enabled.

**What would break.** Second bootstrap is not a no-op: keyring files are overwritten, every database is force-refreshed, operator mirrorlist edits are clobbered, and a commented `[blackarch]` leaves the host without a working repo while bootstrap reports success.

### 5. Secret handling

**Verdict: holds with changes**

**Evidence.** `.gitignore:2,9,14` excludes `private/`, `*.env`, and `tests/vm/local.env`. Constitution VIII and `spec.md:207-208` / `FR-019` are clear. `plan.md:215-217` parameterizes VM tests by env. `tasks.md` T034 and T039 (orphan history) are the right release controls. Gaps: `.gitignore` ignores `*_ed25519` / `*_ed25519.pub` only — not RSA/ECDSA/ed448 keys, not `known_hosts` outside `build/` and `private/`. `plan.md:197-198` has `blackomarchy doctor` secret-scan "the project checkout if present" with no rule forbidding opening `private/` or printing matched values. `constitution.md:102-103` requires failure messages that do not leak local secrets.

**What would break.** An operator key that is not ed25519, or a `known_hosts` copy at the repo root, can be committed. `doctor` run in a working tree that still contains gitignored files can print addresses/credentials into a terminal transcript that later lands in an issue or log.

### 6. VM testing strategy (as specified)

**Verdict: holds with changes**

**Evidence.** Two-VM split, env-parameterized harness, no hardcoded infrastructure (`plan.md:215-221`, `tasks.md` T030-T032) is sound and matches Constitution VIII. Constitution IX (`constitution.md:178-187`) and `spec.md:53-56` / `SC-001` / `SC-005` require proving Omarchy UX and `omarchy update` are unregressed, not only that tools install. `tasks.md` T032 weakens that to "`omarchy update` **dry viability**" plus reboot and representative tools. Graphical session-over-SSH limits are honestly documented (`spec.md:152-154`, `plan.md:247-248`) but remaining session checks are still mandatory.

**What would break.** v0.1 ships with tools that work and a desktop that drifted (theme, default apps, Hyprland hash, update path) because VM B never actually ran `omarchy update` or a graphical session. README claims then outrun tests.

### 7. Rollback design

**Verdict: holds with changes**

**Evidence.** Manifest-driven package removal and "do not `rm -rf /etc/pacman.d/gnupg`" are correct (`plan.md:200-207`, `constitution.md:125-126`, `data-model.md:54-55`). The restore policy is not: "Restore pacman.conf from backup if the only extra stanza is blackarch" (`plan.md:202-203`, `spec.md:131-133`). After install, `omarchy update` or a channel change can legitimately rewrite `[omarchy] Server=` and mirrorlist. Restoring the pre-install backup then **reverts Omarchy**, which Constitution I/V forbids. strap.sh-installed `blackarch-mirrorlist` is not in the profile manifest. Bootstrap writes the manifest as a late pipeline step (`tasks.md` T014, `plan.md:12-16`); a mid-run failure has BlackArch enabled, some packages installed, and uninstall has nothing to read. Fail-closed after strap.sh sed (`plan.md:159-160`) does not say "restore this run's backup." Omarchy hosts typically have snapper; bootstrap does not take a snapshot.

**What would break.** Uninstall on a host that has since changed channel/mirrors rolls Omarchy pacman config back to install-day. A failed bootstrap leaves a half-applied layer that `uninstall.sh` cannot reverse. `blackarch-mirrorlist` remains as an explicit package.

### 8. Package curation strategy

**Verdict: holds with changes**

**Evidence.** Treating profiles as compatibility certificates, excluding `blackarch` / `blackarch-officials`, WMs, themes, kernels, and browser replacements (`plan.md:174-179`, `constitution.md:58-70`, `spec.md:105-109`) is the right product filter. Classification is name-level (`pacman -Si`, Conflicts) and default profiles may only ship PASS / PASS WITH DEPENDENCIES after VM evidence (`data-model.md:77-78`). Missing: file-level conflicts, "would upgrade already-installed packages," default-enabled systemd units, SUID helpers, and NetworkManager replacements. `omarchy-pkg-add` fails the **entire argv** if any name is missing, which fights `spec.md:142-144` (skip missing names, do not abort the profile unless it becomes empty).

**What would break.** A single missing or file-conflicting candidate aborts the whole `core` install, or a tool classified PASS still upgrades glibc/python/openssl or enables a listener, and that ships as "Omarchy unchanged."

### 9. Omarchy remains Omarchy (additive layer only)

**Verdict: holds with changes**

**Evidence.** Spec, constitution check table, and out-of-scope list (`spec.md:270-296`, `plan.md:49-55`, `plan.md:230`) correctly forbid desktop surgery, mirror switching, hardening, and replacing Omarchy components. Tests are *described* as baseline compare of `/usr/share/omarchy`, Hyprland/user omarchy configs, omarchy packages, and update path (`data-model.md:81-93`, `plan.md:181-187`). The holes in targets 1, 3, 4, 6, and 7 are exactly how Omarchy would stop being Omarchy without anyone editing a Hyprland file: unsigned keys, partial upgrades, strap.sh re-exec, `pacman.conf` restore, and tests that only prove tools installed. `FR-012` (`spec.md:191-193`) says "fail or warn per drift policy" while Constitution IV requires unexpected Omarchy-owned change to **terminate**. The data-model table then marks those rows as fail; the "or warn" is how an implementer ships a warning.

**What would break.** A converted host still launches Hyprland but has drifted libraries, a rewritten or restored `pacman.conf`, a BlackArch-trusted keyring of unknown provenance, or an `omarchy update` that now conflicts. That is a different workstation that happens to look like Omarchy.

## Issues

### Issue 1 -- Severity: blocking

- File: `specs/001-black-omarchy-bootstrap/plan.md:149-160`
- Description: Hash-verifying strap.sh and executing it is treated as sufficient trust. Official strap.sh then downloads an **unverified** keyring tarball from `www.blackarch.org` (different host), deletes the `.sig` without checking it, and extracts it as root into the pacman keyring. Constitution III (`constitution.md:90-92`) records the commented `verify_keyring` and only insists on script SHA1. That does not authenticate the keys that will sign every later package. `curl -s -O` without `-f` can also save an error page as `*.tar.gz`.
- Suggestion: After SHA1-verifying strap.sh, the wrapper MUST verify `blackarch-keyring-$VERSION.tar.gz` against the `.sig` using the fingerprint **taken from the verified script** (currently `4345771566D76038C7FEB43863EC0ADBEA87E4E3`), or abort. Do not execute strap.sh if that verification cannot be performed. Record VERSION, script SHA1, keyring fingerprint, and verification time in state. This is a wrap of the official bootstrap, not a replica of it. Pinning SHA1 of strap.sh to the HTML page remains required and remains same-origin (residual TLS trust in blackarch.org — document it).
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 2 -- Severity: blocking

- File: `specs/001-black-omarchy-bootstrap/spec.md:177-185`
- Description: FR-008 forbids `pacman -Syu` as a side effect but allows metadata refresh plus `pacman -S --needed`. Combined with strap.sh's `pacman -Syy` (`research.md:23-24`) this is Arch's partial-upgrade footgun. Profile installs can upgrade already-installed Omarchy/Arch packages as dependencies without `omarchy update`'s snapshot or migrations. Conflict classification (`spec.md:145-146`, `plan.md:169-172`) only looks at missing names and package Conflicts, not the transaction's upgrade set. That violates Constitution I (do not bypass Omarchy's update/snapshot path) and Constitution V (no upgrade as a side effect).
- Suggestion: Before installing any candidate, print the transaction (`pacman -Sp` / `--print-format` or equivalent) and classify CONFLICT/ISOLATE if any **already-installed** package would be upgraded, replaced, or removed. Install per-package, not as one `omarchy-pkg-add` argv. Never set `OMARCHY_ALLOW_DIRECT_PACMAN` (`spec.md:257-260` exception must be deleted). If strap.sh cannot proceed without a sysupgrade, abort for architectural review.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 3 -- Severity: blocking

- File: `specs/001-black-omarchy-bootstrap/plan.md:202-203`
- Description: Uninstall restores the pre-install `pacman.conf` backup whenever the only extra stanza is `[blackarch]`. After conversion, Omarchy legitimately changes that file (channel `Server=`, `omarchy-refresh-pacman`, mirrorlist refresh). Restoring the backup rewrites Omarchy-owned repository configuration — the thing Constitution I and V forbid. User story 4 scenario 2 (`spec.md:131-133`) encodes the same mistake ("match the captured pre-install configuration").
- Suggestion: Always delete the `[blackarch]` block with a real stanza parser (not `sed '/blackarch/{N;d}'`). Restore a whole-file backup only if the non-blackarch bytes still match the backup. Record `blackarch-mirrorlist` and keyring files added by strap.sh in the manifest so uninstall can reverse **Black omARCHy** additions without guessing Omarchy's original file.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 4 -- Severity: blocking

- File: `specs/001-black-omarchy-bootstrap/plan.md:149-160`
- Description: Idempotence is specified as "strap.sh skips `[blackarch]` if present." That is not Constitution V. A second `sh strap.sh` still reinstalls the keyring, `pacman-key --populate`s, force-refreshes every database, reinstalls `blackarch-mirrorlist`, and overwrites the BlackArch mirrorlist from `.pacnew`. T018 (`tasks.md`) only mentions skipping a duplicate stanza. strap.sh's `grep "\[blackarch\]"` also treats a commented stanza as present.
- Suggestion: If `pacman-conf --repo-list` already contains exactly one enabled `blackarch` and Omarchy repos are intact, **do not execute strap.sh**. Only run profile/CLI reconcile. Require an uncommented, parseable stanza; a commented match is ambiguous and must fail closed or repair surgically without sed-N-delete.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 5 -- Severity: major

- File: `specs/001-black-omarchy-bootstrap/plan.md:159-160`
- Description: Omarchy-repo integrity is checked **after** strap.sh mutates `/etc/pacman.conf`. There is no "on any failure after backup, restore this run's backup and exit non-zero." Manifest write is at the end of the pipeline, so a failed core install leaves packages and a live BlackArch repo that `uninstall.sh` cannot see (`data-model.md:54-55`).
- Suggestion: Backup first. After strap.sh failure or unexpected drift, restore `pacman.conf` (and only that run's copies). Append to the manifest as each package succeeds. Document that a failed bootstrap is reversible with `uninstall.sh` plus the in-progress manifest. Taking an Omarchy snapper snapshot before mutation is recommended where snapper exists; do not fail closed solely because snapper is absent.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 6 -- Severity: major

- File: `specs/001-black-omarchy-bootstrap/tasks.md:81-83`
- Description: T032 reduces User Story 1 scenario 3 and Constitution IX to "`omarchy update` dry viability." Public `omarchy-update` does a real `pacman -Syu` (guard-allowed via `OMARCHY_UPDATE_PACMAN=1`) **with `[blackarch]` enabled**. That is the first time BlackArch packages participate in Omarchy's blessed upgrade. Skipping it means v0.1 can ship an additive layer that breaks the update path the constitution exists to preserve. Graphical UX is also allowed to remain "documented remaining checks."
- Suggestion: VM B MUST actually run `omarchy update` (or record a release-blocking incompatibility, per `spec.md:53-56`). It MUST also reboot into the graphical session and compare the baseline hashes under `/usr/share/omarchy` and `~/.config/{hypr,omarchy}`. "Dry viability" is not a test. SSH-only evidence is insufficient for SC-001/SC-005.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 7 -- Severity: major

- File: `specs/001-black-omarchy-bootstrap/research.md:63-71`
- Description: Repo order prevents same-name takeovers, but durability of the stanza is unplanned. `omarchy-refresh-pacman` overwrites `/etc/pacman.conf` from a template, then runs `~/.config/omarchy/hooks/pre-refresh-pacman` / `pre-refresh-pacman.d/` — Omarchy's documented extension point for custom repositories. v0.1 skips menu JSONC as unnecessary (`research.md:75-77`) and never mentions this hook. Channel change, `omarchy reinstall`, or `omarchy refresh pacman` will silently drop BlackArch. That is not "changing Omarchy"; it is failing to use the additive extension point Omarchy already provides.
- Suggestion: Either install a reversible `pre-refresh-pacman.d` drop-in that re-appends a known-good `[blackarch]` stanza (user-owned, not an Omarchy-owned file), or document as a v0.1 limitation that channel switch / `omarchy refresh pacman` / reinstall removes the layer and `blackomarchy verify` must detect that as drift. Do not claim the update path keeps BlackArch without testing those commands.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 8 -- Severity: major

- File: `specs/001-black-omarchy-bootstrap/plan.md:197-198`
- Description: `doctor` "secrets scan of project checkout if present" can read gitignored `private/` and print matches. Constitution VIII/IV forbid emitting local secrets. `.gitignore:10-11` only ignores `*_ed25519` keys.
- Suggestion: Doctor must not open `private/`, `*.env`, or key files, and must never print matched secret values (filename + "redacted" at most). Expand `.gitignore` to `id_rsa`, `id_ecdsa`, `*.pem`, `*.key`, and `known_hosts`. Keep T034/T039; the scan of git history must compare against `private/` **without** copying those values into tracked files or review artifacts.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 9 -- Severity: major

- File: `specs/001-black-omarchy-bootstrap/plan.md:167-176`
- Description: Curation does not define a transaction policy for file conflicts, dependency upgrades, Replaces/Provides against installed Omarchy packages, or packages that enable services. `omarchy-pkg-add` abort-on-first-missing-name contradicts `spec.md:142-144`. Official BlackArch docs recommend `--overwrite='*'` because file collisions are common; forbidding the flag without per-package catch-and-classify will either abort `core` wholesale or tempt an overwrite.
- Suggestion: Resolve and install one package at a time. On file conflict, dep-upgrade of an installed package, or Conflicts/Replaces against `omarchy` / `omarchy-settings` / other installed Omarchy-owned packages: record CONFLICT, skip, continue. Refuse packages that ship enabled systemd units, kernels, DMs, or NetworkManager replacements even if pacman does not report a name conflict. Fill `docs/compatibility.md` only from VM evidence.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 10 -- Severity: minor

- File: `specs/001-black-omarchy-bootstrap/spec.md:191-193`
- Description: FR-012 says "fail or warn per drift policy" then correctly says unexpected Omarchy-owned changes are failures. Constitution IV does not allow a warning. `data-model.md:88-93` already marks those rows as fail.
- Suggestion: Delete "or warn." Unexpected Omarchy drift is a non-zero exit. Expected deltas stay the allowlist in `data-model.md:81-87`.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 11 -- Severity: minor

- File: `specs/001-black-omarchy-bootstrap/plan.md:126-135`
- Description: Detection requires `pacman -Q omarchy`. Omarchy edge/dev uses `omarchy-dev`. Fail-closed is acceptable for v0.1 if the error says "unsupported channel/package set" rather than "not Omarchy." Public update-process docs also claim there is no runtime version file; packaged 4.x does install one. VM evidence must confirm the triad on the real target image.
- Suggestion: Document stable/rc (`omarchy` + `omarchy-settings`) as the only supported package set. Probe `omarchy-dev` only to emit a precise refusal.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 12 -- Severity: minor

- File: `specs/001-black-omarchy-bootstrap/plan.md:152-154`
- Description: `downloads.html` lists many SHA1s (ISOs first). A parser that takes the first 40-hex will hash-check strap.sh against the Full ISO digest and fail closed (safe but brittle). A looser parser could accept the wrong line.
- Suggestion: Unit fixtures must be a realistic page containing ISO hashes plus the `echo <40 hex> strap.sh` snippet. Parser matches that snippet only. `curl --proto '=https' --tlsv1.2 -fsSL` for both page and script; no HTTP fallback.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

### Issue 13 -- Severity: nit

- File: `specs/001-black-omarchy-bootstrap/research.md:8-10`
- Description: Upstream publishes SHA1, not SHA256. Chosen-prefix SHA1 collisions are real in the abstract; an attacker who can change only the script and not the HTML still has to match a published digest. Same-origin live parse makes collision less relevant than site compromise. Residual, not a reason to invent a second hash the vendor does not publish.
- Suggestion: Keep live official SHA1 as required by Constitution III. Do not pretend it is independent attestation. The keyring signature check (Issue 1) is the actual extra control.
- Status: addressed (spec/plan/constitution revised 2026-08-28)

## Residual risks tests must catch

These are not spec defects if the blocking issues are fixed; they will still bite implementation:

- Live strap.sh hash changes; parser and network tests must tolerate a new official digest and must fail closed on an unparsable page.
- `pacman-key --populate` with no TTY may prompt for local-sign of new master keys during strap.sh; non-interactive bootstrap must not hang or auto-trust extra keys.
- Once `[blackarch]` is enabled, `omarchy update`'s `-Syu` will upgrade **BlackArch-unique** packages and their deps under Omarchy's snapshot path. That is acceptable only if VM B shows no Omarchy-owned package removed/replaced.
- BlackArch tools that share a name with `extra` stay on the Omarchy/Arch version (first repo wins). Profiles must not assume the BlackArch build of `nmap` et al. is what got installed.
- Graphical UX cannot be fully asserted over SSH; remaining session checks on VM B are part of the release bar, not a footnote.

## Proceed?

**No.** Revise spec.md, plan.md, research.md, data-model.md, and tasks.md for Issues 1–4 before writing bootstrap code. Issues 5–9 should land in the same revision so Gate 2 is not spent rediscovering them. The additive-layer thesis does not need to change; the trust wrap, transaction policy, uninstall parser, and second-run skip do.
