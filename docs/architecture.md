# Architecture

Black omARCHy is an additive layer on a packaged Omarchy 4.x install.

```
verify host is x86_64 Omarchy
   -> backup pacman.conf
   -> capture Omarchy baseline
   -> if blackarch repo missing:
         download official strap.sh
         verify SHA1 from blackarch.org/downloads.html
         verify keyring tarball with fingerprint from the script
         run strap.sh
         confirm keyring files and Omarchy repos
   -> install curated core packages one at a time
   -> install blackomarchy CLI
   -> install user-owned Omarchy extension files (hooks + menu overlay)
   -> compare baseline
   -> done
```

The layer owns:

- `[blackarch]` in pacman.conf (always last)
- `/etc/pacman.d/blackarch-mirrorlist` (via upstream package)
- `/var/lib/blackomarchy/`
- `/usr/local/bin/blackomarchy`
- `/usr/local/bin/blackomarchy-omarchy-install`
- `/usr/local/sbin/blackomarchy-reappend-repo`
- `/usr/local/share/blackomarchy/`
- `~/.config/omarchy/hooks/pre-refresh-pacman.d/blackomarchy-blackarch.sh`
- `~/.config/omarchy/hooks/post-update.d/blackomarchy-post-update.sh`
- Black omARCHy keys in `~/.config/omarchy/extensions/omarchy-menu.jsonc`
- SDDM greeter `logo.png` overlay (Omarchy wordmark plus a BLACK caption
  and the BlackArch katana through the A). `Main.qml` is not patched.
  Uninstall restores the backed-up Omarchy logo.

It does not own Hyprland, Omarchy shell, themes, keybindings,
mirrors, or the Omarchy update binary. Extension files live under
the user-owned `~/.config/omarchy/` tree Omarchy already documents.

`omarchy update` is `pacman -Syu` plus migrations and
`post-update.d`. With `[blackarch]` present, BlackArch packages
update in that same transaction. `omarchy refresh pacman` copies a
channel template over `pacman.conf`; the official
`pre-refresh-pacman.d` hook puts `[blackarch]` back, still last,
before the upgrade runs. `post-update.d` does the same if a
migration rewrote the file.

Add and remove use the same menu overlay Chrome and 1Password use:
Install > Black omARCHy (`disabled` while present) and Remove >
Black omARCHy (`when` present).

Package installs never pass `--sysupgrade` or `--overwrite='*'`. A
transaction that would upgrade an already-installed package is skipped.
