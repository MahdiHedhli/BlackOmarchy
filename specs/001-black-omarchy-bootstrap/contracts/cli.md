# Contract: `blackomarchy` CLI

Thin dispatcher. Exit 0 on success, non-zero on failure. Human text on
stdout; errors on stderr. No JSON required in v0.1.

```
blackomarchy status
blackomarchy verify
blackomarchy profiles
blackomarchy install <profile>
blackomarchy remove <profile>
blackomarchy doctor
blackomarchy help
```

`profile` is one of: `core`, `web`, `recon`, `network`, `wireless`,
`reversing`, `forensics`, `password`, `all`.

`all` expands to the curated profiles above, never the BlackArch
`blackarch` group.

`install` and `remove` require root. `status`, `verify`, `profiles`,
`doctor` should run without root where possible; `verify` may report
limited results without read access to `/var/lib/blackomarchy`.

`bootstrap.sh` is the first-run installer and may be invoked instead
of `blackomarchy install core` on a virgin host. After first run,
profile changes go through the CLI.

`uninstall.sh` is the documented reversal path for the whole layer.
