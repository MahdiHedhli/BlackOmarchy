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
   -> install user-owned pre-refresh-pacman hook
   -> compare baseline
   -> done
```

The layer owns:

- `[blackarch]` in pacman.conf
- `/etc/pacman.d/blackarch-mirrorlist` (via upstream package)
- `/var/lib/blackomarchy/`
- `/usr/local/bin/blackomarchy`
- `/usr/local/share/blackomarchy/`
- `~/.config/omarchy/hooks/pre-refresh-pacman.d/blackomarchy-blackarch.sh`

It does not own Hyprland, Omarchy shell, themes, menus, keybindings,
mirrors, or the Omarchy update path.

Package installs never pass `--sysupgrade` or `--overwrite='*'`. A
transaction that would upgrade an already-installed package is skipped.
