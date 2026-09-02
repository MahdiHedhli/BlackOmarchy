# Uninstall

From the project checkout:

```bash
sudo ./uninstall.sh
```

From the Omarchy menu: Remove > Black omARCHy.

This removes:

- the `[blackarch]` pacman stanza (parser, not a blunt sed)
- packages listed in `/var/lib/blackomarchy/manifest`
- the `blackomarchy` CLI, reappend helper, and `/usr/local/share/blackomarchy`
- the user-owned `pre-refresh-pacman.d` and `post-update.d` hooks
- Security / profile rows from the menu overlay
- the SDDM greeter and Plymouth splash logo overlays (Omarchy's original
  `logo.png` files are restored and initramfs is rebuilt)
- agent skills copied into `~/.agents/skills/` and the Grok / Claude /
  Cursor / Codex / OpenCode / Gemini skill directories

It keeps, so re-add is the same gesture as any other optional app:

- `/usr/local/bin/blackomarchy-omarchy-install`
- Install > Black omARCHy in the menu overlay
- `~/.local/share/blackomarchy-src` (seeded checkout)

It does not:

- restore an older Omarchy channel or mirror configuration unless the
  rest of `pacman.conf` still matches the install-time backup
- delete `/etc/pacman.d/gnupg`
- edit Hyprland or Omarchy-owned files

BlackArch keyring files under `/usr/share/pacman/keyrings/` are left
in place. They do not affect pacman once the `[blackarch]` stanza is
gone. Re-install from Install > Black omARCHy re-appends the stanza
without re-running `strap.sh` when those files are still present.
