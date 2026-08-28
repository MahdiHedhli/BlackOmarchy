# Research: Black omARCHy v0.1

## R1. Official BlackArch bootstrap

**Decision**: Download `https://blackarch.org/strap.sh`, parse the SHA1
from `https://blackarch.org/downloads.html` (install-on-Arch section:
`echo <sha1> strap.sh | sha1sum -c` only, never the first SHA1 on the
page), verify the script, then independently verify
`blackarch-keyring-$VERSION.tar.gz` with the fingerprint named in the
verified script. Execute strap.sh only after both checks. After
execution, compare installed keyring files to the verified tarball.

If `pacman-conf --repo-list` already has enabled `blackarch`, skip
strap.sh.

**Observed** (2026-08-28): SHA1 `00688950aaf5e5804d2abebb8d3d3ea1d28525ed`.
This value is not a permanent pin; bootstrap always re-reads the official
page.

**strap.sh behavior (VERSION=20251011)**:

- Fetches `blackarch-keyring-$VERSION.tar.gz` and `.sig`
- `verify_keyring` exists but is **commented out** at the call site.
  The `recv-keys` fingerprint in strap.sh (`4345771566D76038C7FEB43863EC0ADBEA87E4E3`)
  is stale. The 20251011 keyring tarball is signed by
  `CBA3C7D4798912702DCF568E67D8BDF42AD93F4E` (BlackArch Master).
  Black omARCHy parses the issuer from the `.sig` and verifies against
  that key.
- Installs keyring into `/usr/share/pacman/keyrings/` and
  `pacman-key --populate`
- If `[blackarch]` is absent: writes `/etc/pacman.d/blackarch-mirrorlist`
  and appends `[blackarch]` / `Include = ...` to pacman.conf
- The stanza rewrite uses `sed -i '/blackarch/{N;d}'` which is blunt;
  we snapshot pacman.conf and refuse unexpected Omarchy-repo drift
- Runs `pacman -Syy` (refresh), then `pacman -S --noconfirm blackarch-mirrorlist`
- `pacman_upgrade` (`pacman -Su`) is defined but **not called**

**Alternatives considered**: Reimplement repo add without strap.sh
(more control, diverges from "use official bootstrap"). Rejected for
v0.1 unless strap.sh cannot be executed safely after wrapping.

## R2. Omarchy detection and layout (v4 / Quattro)

**Decision**: Detect packaged Omarchy, not hostname.

Evidence used:

- `pacman -Q omarchy`
- `/usr/share/omarchy/version`
- `omarchy` on PATH

Supporting, not sufficient: `omarchy-settings`,
`/usr/share/libalpm/hooks/00-omarchy-update-guard.hook`,
`[omarchy]` repo in pacman.conf.

Omarchy v4 ships as Arch packages. System files live under `/usr` and
`/etc`. User overlays live under `~/.config/omarchy/`. Updates go
through `omarchy update`.

## R3. Pacman guard vs additive installs

**Decision**: Never run a system upgrade from Black omARCHy. Use
Omarchy's additive package helper when present.

`omarchy-update-pacman-guard` aborts only when the parent pacman
command is a sync **and** a sysupgrade (`-Syu` / `--sysupgrade`).
`pacman -S --needed` and `pacman -Sy` are allowed.

`omarchy-pkg-add` is `pacman -S --noconfirm --needed` plus a post-query
check. That is the preferred installer for profiles.

`OMARCHY_ALLOW_DIRECT_PACMAN=1` is not used for upgrades. It is not
part of the default bootstrap path.

## R4. Repository priority and package skew

**Decision**: Leave Omarchy mirrors and repo order alone. BlackArch is
appended, so same-named packages resolve to Arch/Omarchy first.

Omarchy stable mirrors Arch with a delay. BlackArch packages that need
newer shared libraries than Omarchy currently provides are classified
`CONFLICT` or `ISOLATE` and excluded. Switching the host to live Arch
mirrors is an architectural decision and is out of scope for v0.1.

## R5. What must not change

Official Omarchy extension point exists:
`~/.config/omarchy/extensions/omarchy-menu.jsonc`. v0.1 still skips
menu integration because it is unnecessary for core functionality.

Do not edit Hyprland config, shell, themes, keybindings, Docker,
SDDM, limine, snapper, or Omarchy ALPM hooks.

## R6. Secret handling

Operator VM inventory, addresses, and credentials exist only in
gitignored `private/`. Public tests take connection parameters from
environment or `tests/vm/local.env` (gitignored). Spec Kit artifacts
must not quote that file.

## R7. Omarchy pacman refresh hook

`omarchy-refresh-pacman` copies a channel template over
`/etc/pacman.conf` then runs `omarchy-hook pre-refresh-pacman`, which
executes `~/.config/omarchy/hooks/pre-refresh-pacman` and
`~/.config/omarchy/hooks/pre-refresh-pacman.d/*`.

v0.1 installs a reversible drop-in in that `.d` directory so a channel
refresh re-appends `[blackarch]` without patching Omarchy-owned files.

## R8. License and affiliation

MIT for project-owned scripts and docs. Upstream names are
trademarks of their owners. README states independent integration,
no endorsement.
