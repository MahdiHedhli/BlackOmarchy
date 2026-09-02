# Black omARCHy

![Black omARCHy login](docs/images/login.png)

An additive BlackArch layer for [Omarchy](https://omarchy.org).

**Project site:** [mahdihedhli.github.io/BlackOmarchy](https://mahdihedhli.github.io/BlackOmarchy/)

It is a bootstrap, a small CLI, and a set of package lists that have to
earn their place on an Omarchy host. It is not a Linux distribution, not
an ISO, and not a restyle of Omarchy.

After a successful install you should still have the same Omarchy
desktop, applications, keybindings, and update command. You also have
the official BlackArch repository and a curated tool set.

v0.1 is experimental. Treat it that way.

## What this is not

- Not affiliated with, endorsed by, or part of Omarchy, BlackArch, or
  Arch Linux.
- Not a fork of Omarchy and not a "hardened Omarchy".
- Not an installer for the complete BlackArch package group.
- Not a one-line `curl | sudo bash` product.

If a BlackArch package would change Omarchy, that package is excluded.

## Relationship to upstream projects

| Project | Role |
| --- | --- |
| [Omarchy](https://omarchy.org) | The desktop and the supported Arch-based host. Owned by its authors. |
| [Arch Linux](https://archlinux.org) | The package manager and base that Omarchy already uses. |
| [BlackArch](https://blackarch.org) | The unofficial Arch user repository of security tools. |

Black omARCHy only adds the official BlackArch repository, required
signing material, curated packages, and its own CLI and state files.

## Prerequisites

- A clean, supported Omarchy 4.x install (packaged `omarchy`, not
  `omarchy-dev`). v0.1 was checked on 4.0.1 and 4.0.2. The latest
  ISO is currently 4.0.2; we do not pin a single patch level.
- `x86_64`
- Root via `sudo`
- Network access to `blackarch.org` and `www.blackarch.org`

## Installation

Copy the repository to the Omarchy machine, read `bootstrap.sh`, then
run it.

```bash
git clone https://github.com/MahdiHedhli/BlackOmarchy.git
cd BlackOmarchy
less bootstrap.sh
sudo ./bootstrap.sh
```

The script:

1. Checks architecture and Omarchy evidence
2. Backs up pacman configuration
3. Records an Omarchy baseline
4. Downloads official `strap.sh` and checks it against the SHA1
   currently published on the BlackArch downloads page
5. Verifies the BlackArch keyring tarball with the fingerprint named in
   that script
6. Runs the verified strap script if the BlackArch repo is not already
   enabled
7. Installs the `core` profile one package at a time, skipping anything
   that would upgrade or replace already-installed software
8. Installs the `blackomarchy` CLI, Omarchy menu overlay, login
   wordmark, update hooks, and Agent Skills
9. Compares the Omarchy baseline and exits non-zero on unexpected drift

Re-running bootstrap is safe. It will not duplicate `[blackarch]` or
re-run `strap.sh` when the repo is already enabled. Re-run it after
pulling this repo to refresh CLI, hooks, login overlay, and skills.

After install, Omarchy's menu grows additive entries (no upstream files
are patched):

- Install > Black omARCHy
- Remove > Black omARCHy
- Install > Security tools (extra profiles)
- Security (status, verify, and a few installed tools)

Install and Remove use the same floating terminal Omarchy uses for
Chrome, 1Password, and other optional apps. After the first bootstrap,
add/remove is that menu path. Uninstall keeps the Install row so
re-add is the same gesture.

The SDDM login screen and Plymouth reboot/unlock splash keep Omarchy's
greeter, script, and colors. Bootstrap overlays `logo.png` only: a
quiet BLACK caption above the pixel OMARCHY wordmark, with the
BlackArch katana through the A. Plymouth is baked into initramfs once
(`plymouth-set-default-theme` plus `limine-mkinitcpio` or
`mkinitcpio -P`) so the mark survives reboot. Uninstall restores
Omarchy's logos and rebuilds initramfs. `omarchy update` re-applies
the overlay if a packaged refresh overwrote it. `Main.qml` is not
patched.

## Agent skills

Bootstrap installs two standard Agent Skills (`SKILL.md` folders), not
Grok-only:

| Skill | Role |
| --- | --- |
| `black-omarchy` | This host: CLI, profiles, `omarchy update`, Omarchy invariants |
| `black-omarchy-pentest` | Authorized collaborative / semi-autonomous testing |

They land in the directories common agents already scan (`~/.agents/skills`,
`~/.grok/skills`, `~/.claude/skills`, `~/.cursor/skills`, `~/.codex/skills`,
OpenCode, Gemini). A clone of this repo also has `.agents/skills/` plus
[AGENTS.md](AGENTS.md) / [CLAUDE.md](CLAUDE.md).

`black-omarchy-pentest` will not scan until authorization and scope are
on record. It will not generate exploit source. Details:
[docs/agent-skills.md](docs/agent-skills.md).

## Updating

Keep using Omarchy's update command:

```bash
omarchy update
```

That is `pacman -Syu` plus migrations. With `[blackarch]` last in
`pacman.conf`, BlackArch **packages** update in the same transaction.
Do not replace this with a raw `pacman -Syu`.

After packages, Omarchy runs `post-update.d`. Our hook:

1. Re-appends `[blackarch]` if a migration rewrote `pacman.conf`
2. Runs `blackomarchy-update` (fast-forward the seeded git tree, then
   `bootstrap.sh`) so CLI, hooks, skills, and the login wordmark match
   this repo
3. If the git pull cannot run, still restores the login overlay and
   refreshes the baseline pin

A failed layer pull does not fail the Omarchy update.

To refresh the layer without an Omarchy upgrade:

```bash
blackomarchy update
```

That is the same as `blackomarchy-update`. First-time source is
`~/.local/share/blackomarchy-src` (cloned from GitHub on install).

`omarchy refresh pacman` still copies a channel template over
`pacman.conf`. The `pre-refresh-pacman.d` hook puts `[blackarch]` back
last before `-Syyuu`.

Logout uses SDDM. Reboot and disk-unlock use Plymouth, which lives in
initramfs — overlaying the greeter file alone does not survive reboot.

If either screen still shows stock OMARCHY:

```bash
sudo /usr/local/sbin/blackomarchy-apply-login-branding apply
```

That copies the wordmark onto SDDM and Plymouth, then rebuilds
initramfs and refreshes the live UKI Blake2b hash in `limine.conf`.
A oneshot before `sddm` re-applies the greeter overlay on boot so a
packaged refresh cannot keep the stock login logo. The Plymouth bake
is skipped when the live splash already matches.

If reboot stops on `Blake2b hash for URI ... does not match`, press
`Y` once to continue, then:

```bash
sudo /usr/local/sbin/blackomarchy-apply-login-branding sync-limine
```

## Package profiles

Default install is `core` only.

```bash
blackomarchy profiles
sudo blackomarchy install web
sudo blackomarchy install recon
sudo blackomarchy install network
sudo blackomarchy install wireless
sudo blackomarchy install reversing
sudo blackomarchy install forensics
sudo blackomarchy install password
sudo blackomarchy install all
```

`all` means every Black omARCHy curated profile. It does not mean every
BlackArch package.

See [docs/package-profiles.md](docs/package-profiles.md) and
[docs/compatibility.md](docs/compatibility.md).

## Verification

```bash
blackomarchy status
blackomarchy verify
blackomarchy doctor
```

`verify` fails if Omarchy-owned files under `/usr/share/omarchy`, the
Omarchy repo `Server=` line, or the `omarchy` packages drifted. That is
not a “you must be on the newest ISO” check.

A fresh install can rewrite files under `~/.config/omarchy` (our menu
overlay and hooks, plus Omarchy’s own pacman hooks). If `verify` says
**Omarchy user configuration changed**, the layer is still installed.
Refresh the pin:

```bash
sudo blackomarchy recapture-baseline
blackomarchy verify
```

## Uninstall

```bash
sudo ./uninstall.sh
```

Details: [docs/uninstall.md](docs/uninstall.md).

## Security model

- No `curl | sh`.
- `strap.sh` is hash-checked against the live official downloads page.
- The keyring tarball is signature-checked before `strap.sh` is allowed
  to install it.
- Bootstrap never sets `OMARCHY_ALLOW_DIRECT_PACMAN`.
- Conflicts are skipped, not overwritten.
- Local operator files live in `private/` and are gitignored.

The downloads-page SHA1 is same-origin with `strap.sh`. It catches
corruption and split-brain, not a compromise of blackarch.org itself.

## Known limitations

- x86_64 and packaged Omarchy 4.x only (checked on 4.0.1 and 4.0.2)
- `omarchy-dev` is refused
- Some profile candidates will be missing or excluded on a given host
- BlackArch tools that share a name with Arch `extra` keep the
  Omarchy/Arch version because `[blackarch]` is appended last
- v0.1 does not add Hyprland themes or keybindings; the menu, login
  wordmark, and Agent Skills are overlays and uninstall cleanly
- `hydra` pulls a large extra dependency set (including freerdp and
  subversion). That did not upgrade Omarchy's own packages.
- `omarchy update -y` over a non-interactive SSH session may still hit
  a nested sudo prompt. The Omarchy system-package updater
  (`omarchy-update-system-pkgs`) completed with BlackArch enabled.

## Contributing

Read `.specify/memory/constitution.md` and
`specs/001-black-omarchy-bootstrap/spec.md` before proposing changes.
The design test is: does Black omARCHy require this, or are we trying
to make Omarchy look like a security distribution?

## Disclaimer

Black omARCHy is an independent integration project. Omarchy, BlackArch,
and Arch Linux names are used for identification only. Security tools
can be misused; you are responsible for how you use them.
