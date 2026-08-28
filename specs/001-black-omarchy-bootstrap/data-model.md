# Data model: Black omARCHy v0.1

## Paths

| Path | Owner | Purpose |
| --- | --- | --- |
| `/var/lib/blackomarchy/` | Black omARCHy | State root |
| `/var/lib/blackomarchy/baseline/` | Black omARCHy | Pre-install Omarchy snapshot |
| `/var/lib/blackomarchy/backups/<utc-stamp>/` | Black omARCHy | pacman.conf and related copies |
| `/var/lib/blackomarchy/manifest` | Black omARCHy | What we installed |
| `/var/lib/blackomarchy/exclusions` | Black omARCHy | Packages skipped and why |
| `/var/lib/blackomarchy/version` | Black omARCHy | Installed layer version |
| `/usr/local/share/blackomarchy/` | Black omARCHy | Profiles and libraries |
| `/usr/local/bin/blackomarchy` | Black omARCHy | CLI |
| `/etc/pacman.conf` `[blackarch]` | BlackArch via strap.sh | Repo stanza |
| `/etc/pacman.d/blackarch-mirrorlist` | BlackArch | Mirrors |

No files under `/usr/share/omarchy`, `/etc/skel`, or
`~/.config/hypr` are owned by this project.

## Baseline snapshot

Files (sanitized; no IPs, hostnames, or user secrets):

- `os-release` copy
- `uname`
- `omarchy-version`
- `pacman.conf` copy
- `pacman-conf --repo-list` output
- `omarchy-server` line extracted from pacman.conf
- `explicit-packages` (`pacman -Qqe`)
- `omarchy-packages` (`pacman -Q omarchy omarchy-settings omarchy-keyring` as present)
- `hashes.tsv` of selected Omarchy-owned paths
- optional user config hashes for `~/.config/hypr` and
  `~/.config/omarchy` belonging to `SUDO_USER`, if those trees exist

Hash list is a allowlist of Omarchy-owned paths, not a whole-disk
inventory.

## Manifest

One record per added package:

```
package<TAB>profile<TAB>classification<TAB>source-repo
```

CLI and supporting files listed separately:

```
file<TAB>path<TAB>sha256
```

Uninstall reads only this manifest plus backups. It does not guess
Omarchy's original package set. The manifest is appended after each
successful package install so a failed run is still reversible.
`blackarch-mirrorlist` and the pre-refresh hook are recorded.

## Package profile file

```
# comment
nmap
sqlmap
```

Empty lines and `#` comments ignored. Names resolved at install time.

## Compatibility classification

Stored in `docs/compatibility.md` and `exclusions`:

- PASS
- PASS WITH DEPENDENCIES
- ISOLATE
- CONFLICT
- UNTESTED

Default profiles may contain only PASS or PASS WITH DEPENDENCIES
after clean-room evidence. Candidates start as UNTESTED until then.

## Drift policy

| Change | Result |
| --- | --- |
| `[blackarch]` added once | expected |
| BlackArch keyring / mirrorlist added | expected |
| Manifest packages added | expected |
| CLI paths added | expected |
| Omarchy repo/server line changed | fail |
| Duplicate `[blackarch]` | fail |
| Omarchy package removed | fail |
| Hash change under `/usr/share/omarchy` | fail |
| User Hyprland/omarchy config hash change | fail |
| Unexpected extra pacman.conf mutations | fail |

Whole-file pacman.conf restore is permitted only when the
non-`[blackarch]` bytes still match the backup. Otherwise uninstall
deletes the `[blackarch]` stanza with a parser.
