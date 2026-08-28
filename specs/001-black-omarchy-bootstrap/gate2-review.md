# Gate 2 adversarial review — Black omARCHy v0.1 implementation

**Reviewer role**: security auditor
**Date**: 2026-08-28
**Scope**: implementation and release artifacts. Read bootstrap, uninstall, CLI, `lib/*.sh`, hooks, packages, tests, README, docs, specs, `.gitignore`, and the constitution. Did not read `private/`. Did not use implementer summaries as evidence. Independently fetched live `https://blackarch.org/strap.sh` (VERSION=20251011) and `https://blackarch.org/downloads.html`.

## Summary

The implementation is the additive layer the constitution asked for. It does not pipe remote content into a shell. It does not set `OMARCHY_ALLOW_DIRECT_PACMAN`. It does not pass `--overwrite='*'` or `--sysupgrade`. Official strap.sh is executed only after a live downloads-page SHA1 check and an independent keyring signature check, and only when `pacman-conf` does not already list an enabled `blackarch` repo. Re-runs skip strap.sh. Uninstall uses a stanza parser and restores a whole `pacman.conf` backup only when non-blackarch bytes still match. Profile installs are one package at a time and skip a transaction that would upgrade an already-installed *named* package.

There are **no blocking findings** that are live-exploitable against the documented operator path, or that silently reintroduce `curl | sh`, `-Syu`, `--overwrite='*'`, or `OMARCHY_ALLOW_DIRECT_PACMAN`. Gate 1's four blocking design holes are present in the code in the form the revised spec required.

There are major holes that should be repaired before treating v0.1 as constitution-IX complete: keyring trust is "any keyserver key that signed this tarball" rather than an allowlist of BlackArch keys; `blackomarchy install` can run strap.sh with no backup; baseline-drift `fail_restore` rips `[blackarch]` out while leaving packages and the CLI in place; the pre-refresh hook is a user-writable `sudo tee -a` onto `/etc/pacman.conf`; transaction classification does not see Replaces/removals; checked-in tests do not prove the README's Omarchy-unchanged or `omarchy update` claims.

## Attempts to refute

### 1. Credential leakage / public-private split

**Verdict: holds**

`.gitignore` excludes `private/`, `*.env`, `tests/vm/local.env`, `build/`, images, common key names (`id_rsa`, `id_ecdsa`, `id_ed448`, `*_ed25519`, `*.pem`, `*.key`), and `known_hosts`. `blackomarchy doctor` does not open `private/` and prints that it does not print secret values. Failure messages use package names, URLs, and fingerprints, not operator inventory. Tracked docs use synthetic clone paths only. This review did not open `private/` or `tests/vm/local.env`.

### 2. curl-pipe-shell, -Syu, --overwrite, OMARCHY_ALLOW_DIRECT_PACMAN

**Verdict: holds**

`bootstrap.sh` tells the operator not to pipe it into sudo. Downloads use `curl --proto '=https' --tlsv1.2 -fsSL --output FILE URL` then `sh "$work/strap.sh"` on a local verified file. Live official strap.sh (`VERSION=20251011`) defines `pacman_upgrade` (`pacman -Su` after reading `/dev/tty`) and **does not call it**. It runs `pacman -Syy` then `pacman -S --noconfirm blackarch-mirrorlist`. Project code never passes `-Syu` / `--sysupgrade` / `--overwrite='*'`. `OMARCHY_ALLOW_DIRECT_PACMAN` and `OMARCHY_UPDATE_PACMAN` are unset in bootstrap, CLI install, uninstall, and immediately before strap.sh.

Live downloads.html still publishes SHA1 `00688950aaf5e5804d2abebb8d3d3ea1d28525ed` for strap.sh and still tells operators to run `pacman -Syu` and `--overwrite='*'`. The project correctly does not follow those extra instructions.

### 3. Strap wrap / keyring signature (Gate 1 Issue 1)

**Verdict: holds with changes**

The wrapper downloads the keyring tarball and `.sig` with `-f` *before* executing strap.sh, verifies the signature in a throwaway `GNUPGHOME`, records SHA1 / fingerprints / VERSION, then after strap.sh compares installed `/usr/share/pacman/keyrings/blackarch*` bytes to the independently verified tarball and `fail_restore`s on mismatch. That is a real wrap, not SHA1-and-pray.

The trust anchor is the **issuer fingerprint parsed from the live `.sig`**, fetched from Ubuntu/MIT keyservers. If that issuer differs from the `recv-keys` fingerprint in verified strap.sh, the code **logs and continues** (`lib/blackarch.sh:85-87`). Spec FR-006a documents this because the strap.sh fingerprint `4345771566D76038C7FEB43863EC0ADBEA87E4E3` is stale relative to the 20251011 tarball (research.md: signed by `CBA3C7D4798912702DCF568E67D8BDF42AD93F4E`). That exception is in the spec; the constitution's "verify with the fingerprint the script names" is therefore not a silent violation.

The remaining defect: there is still **no allowlist**. Any key that can produce a signature over a file named `blackarch-keyring-$VERSION.tar.gz` and is retrievable from a keyserver is accepted. That is weaker than pinning BlackArch Master. A compromise of `www.blackarch.org` (different host from `blackarch.org/strap.sh`) plus an attacker key on the keyserver still injects pacman trust. Same-origin SHA1 of strap.sh does not see that substitution; the post-check also passes if strap.sh installs the same attacker tarball. See Issue 1.

Live strap.sh still comments out `verify_keyring`, still `curl -s -O` without `-f`, still `tar xfz` into `/usr/share/pacman/keyrings/`, still `pacman-key --populate` with no keyring argument, still `sed -i '/blackarch/{N;d}' /etc/pacman.conf`.

### 4. Idempotence / duplicate `[blackarch]`

**Verdict: holds with changes**

`should_run_strap` fails closed on a commented/disabled `[blackarch]` match, skips strap.sh when the repo is enabled, and asserts a single uncommented stanza after a first run. Second bootstrap therefore does not re-exec strap.sh. That closes Gate 1 Issue 4 for the bootstrap path.

`install_cli` / the pre-refresh hook still append a new manifest `file` line on every run. `blackomarchy install` can still execute strap.sh if the repo is missing, **without** `create_backup`. The hook reimplements stanza append with `tee -a` instead of `append_blackarch_stanza`. See Issues 2, 5, 8.

### 5. Partial upgrade / package policy (Gate 1 Issue 2)

**Verdict: holds with changes**

`classify_candidate` prints the transaction via `pacman -S --print --print-format '%n' --needed` and conflicts if any **other already-installed name** appears. Denied metapackages/kernels/DMs/WMs/NetworkManager/omarchy packages exist. File conflicts fail the per-package `pacman -S` / `omarchy-pkg-add` and are recorded as exclusions rather than `--overwrite='*'`. `core` is small; `all` expands curated profiles only.

`--print-format '%n'` does not list packages that would be **removed or replaced** under a different name. `package_replaces_omarchy` only greps Replaces/Conflicts for the substring `omarchy`. FR-010 also requires refusing enabled systemd units; `classify_candidate` never inspects `.service` files. Optional profiles (`kismet` in `wireless.txt`, several names absent from `docs/compatibility.md`) can still ship a listener or a Replaces transaction. See Issues 3 and 11.

### 6. Uninstall / recoverability (Gate 1 Issue 3 / 5)

**Verdict: holds with changes**

Uninstall strips `[blackarch]` with awk, not `sed '{N;d}'`. Whole-file restore happens only when `cmp` of stripped files matches. `blackarch-mirrorlist` is appended to the manifest when strap.sh runs. Keyring files and `/etc/pacman.d/gnupg` are left in place.

`fail_restore` only copies this run's `pacman.conf` backup. Bootstrap order is strap → profile packages → CLI/hook → `baseline_compare`. A late baseline failure restores pacman.conf (BlackArch repo gone) and leaves installed packages, CLI, and the user hook. `blackomarchy install` never calls `create_backup`, so a strap failure on that path cannot restore. `remove_package_if_safe` ends in `|| true`, so uninstall can exit 0 with packages still present. Pacman.conf rewrite uses `cat tmp >conf` (non-atomic truncate). See Issues 2, 4, 7, 12.

### 7. Omarchy-owned mutation / extension hook (Gate 1 Issue 7)

**Verdict: holds with changes**

No edits to Hyprland, `/usr/share/omarchy` contents, menus, themes, or Omarchy ALPM hooks. The intended durability path is a user drop-in under `~/.config/omarchy/hooks/pre-refresh-pacman.d/`, which is Omarchy's documented custom-repo extension point.

That drop-in is user-writable, `0755`, and when not already root runs `sudo tee -a /etc/pacman.conf`. If `omarchy-hook` runs as root (typical for `omarchy update` / `omarchy refresh pacman`), root is executing a file the operator user can replace — a persistence gadget on top of Omarchy's own hook model. `install -d` of the hook path can create `~/.config/omarchy` as root and only `chown`s the `hooks` subdirectory. Baseline compare hashes three Omarchy files, not the `/usr/share/omarchy` tree the data-model says is a fail row. See Issues 5, 6, 9.

### 8. Tests vs README claims (Constitution IX)

**Verdict: does not hold**

Checked-in unit tests cover: SHA1 snippet parse vs a fixture that also contains ISO hashes, hash *mismatch* refuse, profile name/`all` expansion, stanza strip. There is no success-path SHA1 test, no detect fail-closed test (T020), no keyring/fingerprint test, no transaction-upgrade test, no strap-skip test, no uninstall restore-policy test.

`tests/vm/run-remote.sh` rsyncs the tree and runs `sudo bash …/bootstrap.sh`. It does not compare baseline, reboot, run `core` tools, run `omarchy update`, or uninstall. `docs/compatibility.md` records package classifications on Omarchy 4.0.1-1 and that `verify` passed after a second bootstrap. It does not record a real `omarchy update`, a graphical session, or uninstall. README still claims the desktop, keybindings, and update command remain. That outruns tested behavior. See Issue 10.

Product bootstrap itself has no hidden dependency on operator VMs; only the public test harness does, via gitignored env.

## Issues

### Issue 1 -- Severity: major
- File: lib/blackarch.sh:85
- Description: After parsing the issuer fingerprint from the keyring `.sig`, a mismatch with the `recv-keys` fingerprint from verified strap.sh is only logged. The wrapper then `gpg --recv-keys` **that issuer** from Ubuntu/MIT keyservers (including plaintext `hkp://` fallbacks) and accepts any tarball whose signature checks out. `research.md` already knows the live signer is `CBA3C7D4798912702DCF568E67D8BDF42AD93F4E` and that the strap.sh fingerprint is stale. Neither value is used as an allowlist. Combined with strap.sh fetching the keyring from `www.blackarch.org` (different host than `blackarch.org/strap.sh`) with `curl -s -O` and with `verify_keyring` still commented out upstream, a substituted tarball+sig on the keyring host becomes pacman trust if the attacker key is on a keyserver. The post-install byte compare cannot catch this: it compares the installed files to the same independently downloaded (attacker) tarball.
- Suggestion: Allowlist the issuer against the fingerprint named in verified strap.sh **or** the documented BlackArch Master fingerprint (or both). Abort on any other signer. Keep the live SHA1 parse. Do not treat keyserver presence as identity.
- Status: addressed (post-review patch 2026-08-28)

### Issue 2 -- Severity: major
- File: blackomarchy:98
- Description: `cmd_install` calls `ensure_blackarch_repo` then `install_profile` without `create_backup` and without capturing `BLACKOMARCHY_CURRENT_BACKUP`. `fail_restore` therefore cannot restore `pacman.conf` if strap.sh's `sed -i '/blackarch/{N;d}'` or a later keyring mismatch fires on this path. Contracts say bootstrap is first-run and CLI is for profiles afterwards, but the CLI will happily run official strap.sh on a host whose `[blackarch]` is missing (fresh machine, or after `omarchy refresh pacman` if the hook failed).
- Suggestion: Share one "mutate pacman" prelude: backup, then strap-or-skip, then profiles. Refuse to execute strap.sh unless `current_backup_dir` is set. `blackomarchy install` should create a backup or require an existing healthy blackarch repo and skip strap.
- Status: addressed (post-review patch 2026-08-28)

### Issue 3 -- Severity: major
- File: lib/pacman.sh:146
- Description: `transaction_upgrades_installed` only reports already-installed names that appear in `pacman -S --print --print-format '%n'`. That catches same-name upgrades of dependencies. It does not catch a new package that **Replaces** or otherwise **removes** an installed package under a different name, and `package_replaces_omarchy` only looks for the substring `omarchy` in Replaces/Conflicts. FR-010 and Constitution V require skip-on-replace-or-remove of already-installed software. `add_package` will then run `omarchy-pkg-add` / `pacman -S --noconfirm --needed` and commit that replacement.
- Suggestion: Inspect the full transaction (install + remove sets, `Replaces`, `Conflicts` against `pacman -Q`). Classify CONFLICT if any already-installed package would be upgraded, replaced, or removed, not only if a printed `%n` is already present and is not the candidate.
- Status: addressed (post-review patch 2026-08-28)

### Issue 4 -- Severity: major
- File: bootstrap.sh:41
- Description: On unexpected Omarchy baseline drift after a successful repo add and profile/CLI install, `fail_restore` copies this run's pre-change `pacman.conf` back and dies. Packages already recorded in the manifest, `/usr/local/bin/blackomarchy`, `/usr/local/share/blackomarchy`, and the user hook remain. The host is then a BlackArch-packaged system **without** the `[blackarch]` stanza (partial upgrade risk on the next sync, and a lie relative to `blackomarchy status`). Constitution V requires a reversible, coherent layer, not a half-applied one whose "restore" only rewinds one file.
- Suggestion: On late failure, either leave the layer installed and fail `verify` (so uninstall still has a repo + manifest to reverse), or reverse in order: hook, CLI, manifest packages, then pacman.conf. Do not restore pacman.conf alone after packages have been committed.
- Status: addressed (post-review patch 2026-08-28)

### Issue 5 -- Severity: major
- File: share/hooks/blackomarchy-blackarch.sh:17
- Description: The pre-refresh drop-in appends to `/etc/pacman.conf` with `>>` as root or `sudo tee -a` as a user. It does not use `append_blackarch_stanza`, does not take a lock, and does not treat an ambiguous/commented stanza as fail-closed. The installed file is `0755` under the operator's `~/.config/omarchy/hooks/`. If Omarchy runs `pre-refresh-pacman.d` during a privileged refresh, root executes a user-replaceable script that mutates pacman configuration; if it runs as the user, the script prompts sudo. Duplicate `[blackarch]` is possible if `pacman-conf` is missing and `grep '^\[blackarch\]'` misses a variant header. This is the durability path README claims for `omarchy update`.
- Suggestion: Install the hook non-writable by the user, or have it call a root-owned helper under `/usr/local/share/blackomarchy` that uses the same `append_blackarch_stanza` / ambiguous-stanza checks as `lib/pacman.sh`. Never `sudo tee -a` from a home-directory script. Abort rather than append when the Include file is missing.
- Status: addressed (post-review patch 2026-08-28)

### Issue 6 -- Severity: major
- File: lib/install_cli.sh:17
- Description: `install -d -m 0755 "$home/.config/omarchy/hooks/pre-refresh-pacman.d"` as root creates missing parents. `chown -R` is applied only to `$home/.config/omarchy/hooks`, not to `~/.config/omarchy`. A clean host that has not yet created that directory (SSH bootstrap before first graphical session — the documented VM-B order) is left with a root-owned Omarchy user-config directory. Baseline capture happens *before* hook install, so `omarchy-user.hashes` is absent and `baseline_compare` will not see the new tree. That is an Omarchy UX break introduced by v0.1, not an upstream file patch.
- Suggestion: If `~/.config/omarchy` does not exist, skip the hook (repo still works until `omarchy refresh pacman`) or create and `chown` from `~/.config/omarchy` downward as `SUDO_USER`. Never leave a root-owned Omarchy config dir in a user home.
- Status: addressed (post-review patch 2026-08-28)

### Issue 7 -- Severity: major
- File: lib/pacman.sh:170
- Description: `remove_package_if_safe` runs `pacman -Rns --noconfirm` then `pacman -R --noconfirm` and swallows all failures with `|| true`. Uninstall iterates the manifest and always ends with `log "Black omARCHy removed"` plus deletion of the CLI even when removals failed (foreign dependents, pacman lock, name mismatch). `-Rns` can also remove newly-unneeded dependencies that were not in the manifest. Constitution V's reversibility is then best-effort and silent.
- Suggestion: Treat a still-installed manifest package as a failed uninstall (non-zero) unless it is required by a non-manifest package, in which case record it and continue. Do not `-Rns` blindly; remove the named package and only those deps this layer introduced.
- Status: addressed (post-review patch 2026-08-28)

### Issue 8 -- Severity: major
- File: lib/blackarch.sh:200
- Description: Plan/spec require that after any `pacman.conf` edit, `[core] extra multilib omarchy` are present, `[blackarch]` is present once, **and** the Omarchy `Server=` line is unchanged. After strap.sh the code only calls `require_omarchy_repos`, `assert_single_blackarch`, and `repo_enabled blackarch`. Live strap.sh `sed -i '/blackarch/{N;d}'` deletes a matching line **and the next line**. A false-positive `blackarch` substring can delete the `[omarchy]` header or its `Server=` line; `repo_enabled omarchy` may still pass if a later fragment parses, and `Server=` drift is not checked until `baseline_compare` at the end of bootstrap (after packages). That is Gate 1 Issue 5, only half-fixed.
- Suggestion: Immediately after strap.sh (success or fail path), diff `omarchy_server_line` against this run's backup and `fail_restore` on mismatch before any `pacman -S`.
- Status: addressed (post-review patch 2026-08-28)

### Issue 9 -- Severity: major
- File: lib/baseline.sh:31
- Description: "Omarchy-owned file hashes" are three paths: `/usr/share/omarchy/version`, the update-guard hook, and `/etc/profile.d/omarchy.sh`. Data-model drift policy says a hash change under `/usr/share/omarchy` fails. A package or strap side effect that rewrites other files in that tree, default apps, or systemd units shipped by `omarchy` / `omarchy-settings` is invisible to `verify` and to bootstrap's final compare. Hyprland / user omarchy hashes are skipped entirely when `SUDO_USER` is unset (root shell without sudo).
- Suggestion: Hash the `/usr/share/omarchy` tree (or a documented allowlist that is actually that tree), keep the three files, and fail closed on unexpected paths. Require `SUDO_USER` for baseline of the operator session, or document that `sudo -i` leaves desktop configs untested.
- Status: addressed (post-review patch 2026-08-28)

### Issue 10 -- Severity: major
- File: tests/vm/run-remote.sh:27
- Description: Constitution IX forbids README claims that outrun tested behavior. README asserts clone-read-run safety, skip-upgrade package installs, re-run safety, `verify` detecting Omarchy drift, and that the operator should still use `omarchy update` with the same desktop. Unit tests do not execute strap wrap, transaction policy, strap skip, uninstall restore policy, or host detection. The VM harness only runs bootstrap over SSH. `docs/compatibility.md` is package classification plus `verify` after a second bootstrap; it does not record reboot, graphical session, real `omarchy update`, or uninstall. T020, T032, and the success-path SHA1 check are unimplemented. Experimental labeling does not replace those tests; it only prevents marketing as stable.
- Suggestion: Extend unit tests to detect fail-closed, matching SHA1, fingerprint allowlist, stanza restore policy, and "print transaction would upgrade → skip". Make `run-remote.sh` (or a sibling) actually run verify, representative `core` tools, `omarchy update`, reboot/session checks, and uninstall on VM B, with results sanitized into `docs/compatibility.md`. Trim README claims that remain untested.
- Status: addressed (post-review patch 2026-08-28)

### Issue 11 -- Severity: minor
- File: lib/packages.sh:56
- Description: FR-010 says refuse packages that ship enabled systemd units, kernels, DMs, or NetworkManager replacements even without a name conflict. `classify_candidate` never looks at `.service` files or `systemctl is-enabled`. `packages/wireless.txt` includes `kismet`; several optional-profile names have no row in `docs/compatibility.md`. Default `core` is evidence-backed; `install all` is not.
- Suggestion: Query the candidate package file list for `usr/lib/systemd/system/*.service` and skip if any unit would enable on install. Restrict shipped optional profiles to names with compatibility rows, or mark them UNTESTED and refuse to install without `--allow-untested`.
- Status: addressed (post-review patch 2026-08-28)

### Issue 12 -- Severity: minor
- File: lib/pacman.sh:71
- Description: `remove_blackarch_stanza_from_file` and uninstall's stripped-file compare use `mktemp` then `cat "$tmp" >"$conf"`. That truncates `/etc/pacman.conf` in place (non-atomic). Interrupt or a full-disk write leaves a truncated pacman.conf. Temp files for package snapshots and stripped confs are created with the process umask, not `make_priv_tempdir`.
- Suggestion: Write to a sibling temp on the same filesystem and `mv -f` over the target, preserving owner/mode. Use `make_priv_tempdir` for any file that is a copy of system config.
- Status: addressed (post-review patch 2026-08-28)

### Issue 13 -- Severity: minor
- File: lib/common.sh:59
- Description: `make_priv_tempdir` sets `umask 077` in the current shell and never restores it. Official strap.sh saves that umask, sets `0022` for its own extract, then `reset_umask` **before** `pacman -S blackarch-mirrorlist`. The rest of bootstrap (profile installs, CLI, hook) therefore runs with umask 077. Pacman package extracts typically honor archive modes, but any files created by redirection, `gpg`, or helper tools inherit 077. Not a demonstrated Omarchy break; it is still global process state leaking into upstream strap.sh.
- Suggestion: `local` is not valid for umask; save/restore `OLD_UMASK` in the function (as strap.sh itself does) so only the tempdir creation is tight.
- Status: addressed (post-review patch 2026-08-28)

### Issue 14 -- Severity: minor
- File: lib/pacman.sh:29
- Description: `grep -c "^\[${name}\]" … || printf '0\n'`: GNU `grep -c` with zero matches prints `0` and exits 1, so the function prints `0\n0`. `blackomarchy status` then shows a second `0`. `assert_single_blackarch` is saved by `if [[` not aborting on the malformed integer, but this is a brittle parser for the duplicate-stanza guard.
- Suggestion: `n=$(grep -c … || true)` and default empty to 0; never `|| printf` after `grep -c`.
- Status: addressed (post-review patch 2026-08-28)

### Issue 15 -- Severity: minor
- File: uninstall.sh:7
- Description: Several tests use unquoted `[[ -f $path ]]` / `[[ -n $backup && -f $backup/pacman.conf ]]` (`uninstall.sh:7,37,49,53`, `blackomarchy:13,17`, `lib/install_cli.sh:20,23`, `lib/baseline.sh:53,99`). A checkout path with whitespace (this workspace's directory name) makes `[[ -f` see extra arguments and take the `/usr/local/share/blackomarchy` fallback, or skip `paths.conf`. README's `BlackOmarchy` clone path has no space, so the documented path works.
- Suggestion: Quote every `[[ -f "$path" ]]` and `[[ -d "$path" ]]`. Drop the `eval printf '~$user'` fallback in `invoking_home` (`lib/common.sh:80`); `getent` is present on Omarchy.
- Status: addressed (post-review patch 2026-08-28)

### Issue 16 -- Severity: minor
- File: bootstrap.sh:45
- Description: FR-013 requires a completion summary that includes what was added and what was excluded. Bootstrap prints "done", repo enabled, default profile, CLI hints, and "Omarchy … were not modified". Exclusions live only in `/var/lib/blackomarchy/exclusions`. Re-running `install_cli` appends duplicate `file` manifest lines (`lib/install_cli.sh:49-51`); harmless for uninstall's hardcoded rm, but the manifest is not idempotent (Constitution V).
- Suggestion: Print exclusion counts and a pointer to the exclusions file. Make `append_manifest_line` unique on kind+name.
- Status: addressed (post-review patch 2026-08-28)

### Issue 17 -- Severity: nit
- File: lib/baseline.sh:27
- Description: `hash_tree` pipes `find -print0 | sort -z | xargs -0 -n 1 sha256sum` without `xargs -r`. GNU xargs with no files runs `sha256sum` once against stdin. Empty config dirs can produce a spurious `-` hash. Compare is consistent if both sides are empty in the same way.
- Suggestion: Add `-r` (and a `sha256sum`/`shasum` probe once, not per file).
- Status: addressed (post-review patch 2026-08-28)

### Issue 18 -- Severity: nit
- File: lib/pacman.sh:77
- Description: `append_blackarch_stanza` is the careful helper (enabled/ambiguous checks) and is unused. The hook inlines a weaker append. `https_get_stdout` is unused. `plan.md:215` still describes `doctor` as scanning the checkout for secrets; the implementation correctly does not. `tasks.md` items remain unchecked. Manifest on-disk format (`package<TAB>name<TAB>class<TAB>profile`) does not match `data-model.md`. None of these change runtime trust by themselves.
- Suggestion: Delete dead helpers or use them from the hook. Align plan/data-model with the code. Check off tasks that are actually done.
- Status: addressed (post-review patch 2026-08-28)

## Residual risks

These are not implementation defects if Issues 1–10 stay tracked:

- Downloads-page SHA1 is same-origin with strap.sh. It catches corruption and split-brain, not a compromise of blackarch.org TLS/CDN. README already says this.
- Official strap.sh still uses blunt `sed -i '/blackarch/{N;d}'`, `curl -s -O` without `-f`, and `pacman-key --populate` with no keyring argument. A non-interactive SSH bootstrap can hang or auto-trust keys on populate; there is no timeout wrapper.
- Once `[blackarch]` is enabled, a later real `omarchy update` (`pacman -Syu` with the Omarchy guard env) is the first time BlackArch participates in Omarchy's blessed upgrade. That is acceptable only with VM-B evidence (Issue 10).
- Same-named tools resolve from Arch `extra` because `[blackarch]` is appended. Profiles must not claim the BlackArch build of `nmap` et al. `docs/compatibility.md` already records extra-first; keep README language that way.
- `tests/vm/run-remote.sh` `rsync --delete` will wipe `BLACKOMARCHY_REMOTE_DIR` on the operator VM if that variable is pointed at a home directory. Operator-local only; not the public bootstrap path.
- Graphical UX cannot be fully proven over SSH. Remaining session checks are still part of the release bar, not a footnote.

## Proceed?

**Not as a constitution-IX release until Issues 1–10 are fixed or explicitly accepted in the spec.** There is no blocking finding that reintroduces a forbidden bootstrap primitive (`curl | sh`, `-Syu` as a project side effect, `--overwrite='*'`, `OMARCHY_ALLOW_DIRECT_PACMAN`, duplicate first-run stanza, or uninstall rolling Omarchy mirrors by default). Experimental v0.1 can continue on a lab host. Shipping the README's "same Omarchy, keep using `omarchy update`" sentence without Issue 10 evidence, and without pinning the keyring signer (Issue 1), is the Gate 2 line that should not be crossed.
