# Package profiles

Profiles are compatibility-certified subsets of BlackArch for Omarchy,
not the full BlackArch catalog.

| Profile | Role |
| --- | --- |
| `core` | Default professional baseline |
| `web` | Web assessment extras |
| `recon` | OSINT / recon extras |
| `network` | Network discovery extras |
| `wireless` | Wireless extras |
| `reversing` | Reverse engineering extras |
| `forensics` | Forensics extras |
| `password` | Password and hash extras |
| `all` | All of the rows above |

`all` does not mean `pacman -S blackarch`. `catalog` walks the
BlackArch `blackarch` group one package at a time and skips conflicts;
it never installs the `blackarch` metapackage.

Install > Security tools > **All** is a submenu of the live BlackArch
group. Its top row **All** runs `blackomarchy install catalog`. Each
extra profile (web, recon, …) still fans out from `packages/<profile>.txt`.

Candidate names are resolved at install time. Missing names and
conflicts are recorded in `/var/lib/blackomarchy/exclusions`. See
`docs/compatibility.md` for classifications after live testing.
