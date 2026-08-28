# Sanitized VM evidence (v0.1)

Operator hosts and addresses are not recorded here.

## Packaged Omarchy 4.0.1-1, x86_64, ID=omarchy

Iterative host and a previously unmodified clone both ran the documented
`sudo ./bootstrap.sh` path.

Observed:

- Official strap.sh SHA1 matched the live downloads page
  (`00688950aaf5e5804d2abebb8d3d3ea1d28525ed`).
- Keyring tarball signed by allowlisted BlackArch Master
  `CBA3C7D4798912702DCF568E67D8BDF42AD93F4E`.
- `[blackarch]` present once; `core extra multilib omarchy` still
  present.
- `omarchy` / `omarchy-settings` remained `4.0.1-1`.
- `blackomarchy verify` passed after install, after a second bootstrap
  (strap.sh skipped), and after reboot.
- Representative tools ran (`nmap`, `sqlmap`, `yara`).
- `hyprland` remained installed; `/usr/share/omarchy/shell` remained.
- `omarchy-update-system-pkgs` completed a no-op system upgrade with
  BlackArch enabled.
- `omarchy update -y` over non-interactive SSH created a snapper
  snapshot then hit a nested sudo password prompt. That is an SSH
  session limitation of the wrapper, not a pacman/BlackArch failure.
- Uninstall removed the `[blackarch]` stanza and CLI. Omarchy packages
  remained.

See `docs/compatibility.md` for package rows.
