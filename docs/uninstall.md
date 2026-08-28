# Uninstall

From the project checkout:

```bash
sudo ./uninstall.sh
```

This removes:

- the `[blackarch]` pacman stanza (parser, not a blunt sed)
- packages listed in `/var/lib/blackomarchy/manifest`
- the `blackomarchy` CLI and `/usr/local/share/blackomarchy`
- the user-owned `pre-refresh-pacman.d` hook

It does not:

- restore an older Omarchy channel or mirror configuration unless the
  rest of `pacman.conf` still matches the install-time backup
- delete `/etc/pacman.d/gnupg`
- edit Hyprland or Omarchy-owned files

BlackArch keyring files under `/usr/share/pacman/keyrings/` are left
in place. They do not affect pacman once the `[blackarch]` stanza is
gone.
