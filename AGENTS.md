# Black omARCHy

This repository and, after bootstrap, this host are **Omarchy** plus an
additive BlackArch layer. Not a distro, not Kali, not a fork.

## Skills

Standard Agent Skills (`SKILL.md` + optional `references/`). Any coding
agent that loads skills from a well-known directory can use them.

Canonical copy: `share/skills/`

Also mirrored at `.agents/skills/` (vendor-neutral) and `.grok/skills/`
(Grok). Bootstrap installs the same folders into the operator home for
Grok, Claude Code, Cursor, Codex, OpenCode, and Gemini CLI.

| Skill | Role |
| --- | --- |
| `black-omarchy` | Host, CLI, profiles, `omarchy update`, Omarchy invariants |
| `black-omarchy-pentest` | Authorized collaborative / semi-autonomous testing |

If your agent does not auto-discover those paths, point it at
`share/skills/` or `~/.agents/skills/`.

Details: `docs/agent-skills.md`
