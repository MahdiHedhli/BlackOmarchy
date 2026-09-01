# Agent skills

Black omARCHy ships two skills so Grok (and Claude/Cursor-compatible
agents) can use this workstation without assuming Kali.

They install into the operator home on bootstrap:

- `~/.grok/skills/black-omarchy/`
- `~/.grok/skills/black-omarchy-pentest/`
- the same names under `~/.claude/skills/` and `~/.agents/skills/`

In this repository they also live at `.grok/skills/` (copies of
`share/skills/`) so a clone opened in Grok loads them.

| Skill | When |
| --- | --- |
| `black-omarchy` | Host, CLI, profiles, updates, Omarchy invariants |
| `black-omarchy-pentest` | Authorized collaborative/semi-autonomous testing |

`black-omarchy-pentest` will not scan until authorization and scope are
on record. It will not generate exploit source.

## What we looked at on GitHub (2026-09)

There is **no BlackArch-specific** agent skill pack. Community pentest
skills are almost all Kali- or generic-Linux-oriented.

| Repo | Why it was considered | Verdict for v0.1 |
| --- | --- | --- |
| [transilienceai/communitytools](https://github.com/transilienceai/communitytools) | Coordinator / executor / validator roles, MIT, engagement bookkeeping | Optional later; not Omarchy-aware; too large to vendor |
| [x-glacier/kali-pentest](https://github.com/x-glacier/kali-pentest) | 200+ CLI tools, approval gates, playbooks | Kali paths/`apt`; map later, do not copy |
| [trailofbits/skills](https://github.com/trailofbits/skills) | High-quality audit/review skills | Code-audit, not this host's tool layer |
| [openclaw/skills nmap-pentest-scans](https://github.com/openclaw/skills) | Scoped Nmap planning | Overlaps our pentest skill; keep ours host-specific |
| [AeonDave/malskill](https://github.com/AeonDave/malskill) | One skill per tool | Useful catalog; we only document tools we actually ship |
| [securityfortech/awesome-security-skills](https://github.com/securityfortech/awesome-security-skills) | Index of security SKILL.md repos | Pointer list, not a pack to install |
| [0x0pointer/skills](https://github.com/0x0pointer/skills), [Orizon-eu/claude-code-pentest](https://github.com/Orizon-eu/claude-code-pentest) | Autonomous "give it a domain" chains | Too aggressive; Kali/generic; skip |
| [mukul975/Anthropic-Cybersecurity-Skills](https://github.com/mukul975/Anthropic-Cybersecurity-Skills) | 800+ framework-mapped skills | Noise; not a host adapter |
| [zhaoxuya520/reverse-skill](https://github.com/zhaoxuya520/reverse-skill) | Notes BlackArch works if you swap `apt`→`pacman` | Confirms we need our own adapter |

Do not clone those trees into this repo. If an operator wants a Kali
pack, they install it themselves and still follow `black-omarchy`
(pacman, curated profiles, no Omarchy restyle).
