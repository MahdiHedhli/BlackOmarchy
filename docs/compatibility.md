# Compatibility record

Classifications below are from a packaged Omarchy 4.0.1-1 x86_64 host
with BlackArch enabled after verified strap.sh. Same-named packages
resolved from Arch `extra` first because `[blackarch]` is appended.

| Package | Classification | Notes |
| --- | --- | --- |
| nmap | PASS | extra |
| masscan | PASS | extra |
| tcpdump | PASS | extra |
| wireshark-cli | PASS WITH DEPENDENCIES | extra; adds wireshark group |
| nikto | PASS WITH DEPENDENCIES | extra |
| sqlmap | PASS | extra |
| gobuster | PASS | extra |
| ffuf | PASS | extra |
| whatweb | PASS WITH DEPENDENCIES | extra |
| theharvester | PASS WITH DEPENDENCIES | extra |
| enum4linux-ng | PASS WITH DEPENDENCIES | extra |
| impacket | PASS | already present or extra |
| netexec | PASS | extra |
| hashcat | PASS | extra |
| john | PASS WITH DEPENDENCIES | extra |
| hydra | PASS WITH DEPENDENCIES | extra; large new dep set (freerdp, subversion), no Omarchy package upgrades |
| radare2 | PASS WITH DEPENDENCIES | extra |
| binwalk | PASS | extra |
| testdisk | PASS WITH DEPENDENCIES | extra |
| sleuthkit | PASS WITH DEPENDENCIES | extra |
| foremost | PASS | extra |
| yara | PASS | extra |
| perl-image-exiftool | PASS | extra |
| traceroute | PASS | extra |
| gdb | PASS | already installed |
| whois | PASS | already installed |
| python-impacket | UNTESTED | name not in configured repositories |
| exiftool | UNTESTED | use perl-image-exiftool |
| gnu-netcat | UNTESTED | name not in configured repositories |
| blackarch / blackarch-officials | CONFLICT | denied metapackages |

No CONFLICT rows were observed for the default `core` candidates on this
host. Omarchy packages remained `omarchy 4.0.1-1` and
`omarchy-settings 4.0.1-1`. `blackomarchy verify` passed after install
and after a second bootstrap.
