---
name: black-omarchy
description: >
  Operate a Black omARCHy workstation (Omarchy desktop plus the official
  BlackArch repository and curated tools). Use when the user mentions
  Black omARCHy, blackomarchy, BlackArch on Omarchy, installing or
  removing security profiles, verifying the layer, omarchy update with
  BlackArch, or asks how this host differs from Kali. Slash: /black-omarchy
---

# Black omARCHy host

This machine is **Omarchy**. Black omARCHy is an additive layer: official
BlackArch repo, curated packages, a thin CLI. It is not a distro, not
Kali, not a fork.

## First checks

```bash
blackomarchy status
blackomarchy doctor
command -v nmap sqlmap hashcat
```

If `blackomarchy` is missing, the layer is not installed. Install from
the Omarchy menu (**Install > Black omARCHy**) or:

```bash
git clone https://github.com/MahdiHedhli/BlackOmarchy.git
cd BlackOmarchy
sudo ./bootstrap.sh
```

## CLI

| Command | Role |
| --- | --- |
| `blackomarchy status` | Repos, version, profiles |
| `blackomarchy verify` | Omarchy baseline + single `[blackarch]` |
| `sudo blackomarchy recapture-baseline` | Refresh the Omarchy pin after install or `omarchy update` |
| `blackomarchy doctor` | Hooks, helper, login overlay |
| `blackomarchy profiles` | Curated profile names |
| `sudo blackomarchy install <profile>` | `core`, `web`, `recon`, `network`, `wireless`, `reversing`, `forensics`, `password`, or `all` |
| `sudo blackomarchy remove <profile>` | Remove packages recorded for that profile |

`all` means every curated profile, not `pacman -S blackarch`.

Package lists live in `packages/*.txt` (installed copy:
`/usr/local/share/blackomarchy/packages/`). Conflicts are skipped; they
are recorded in `/var/lib/blackomarchy/exclusions`.

## Update path

Keep using `omarchy update`. With `[blackarch]` last in `pacman.conf`,
BlackArch packages update in that `pacman -Syu`. Do not run a raw
`pacman -Syu` for the user. Do not set `OMARCHY_ALLOW_DIRECT_PACMAN`.

If a channel refresh dropped `[blackarch]`, the
`pre-refresh-pacman.d` / `post-update.d` hooks re-append it last.
Repair with `sudo /usr/local/sbin/blackomarchy-reappend-repo` only when
those hooks should have run and the stanza is missing.

## Hard rules

- Do not restyle, harden, or replace Omarchy (Hyprland, themes, update
  binary, login QML, keybindings).
- Do not `apt`. This is Arch/Omarchy. Extra packages:
  `omarchy-pkg-add <name>` or `sudo blackomarchy install <profile>`.
- Same-name packages resolve from `core` / `extra` / `omarchy` first
  because `[blackarch]` is last. That is intentional.
- Do not install `blackarch` or `blackarch-officials` metapackages.
- Offensive work uses the `black-omarchy-pentest` skill, which requires
  an authorization gate first.
