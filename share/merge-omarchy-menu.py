#!/usr/bin/env python3
"""Merge Black omARCHy keys into ~/.config/omarchy/extensions/omarchy-menu.jsonc."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PREFIXES = (
    "install.blackomarchy",
    "remove.blackomarchy",
    "install.security",
    "remove.security",
    "security",
)


def strip_jsonc(text: str) -> str:
    lines = []
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("//"):
            continue
        lines.append(line)
    return "\n".join(lines)


def ours(key: str) -> bool:
    return any(key == p or key.startswith(p + ".") for p in PREFIXES)


def load_jsonc(path: Path) -> dict:
    if not path.exists():
        return {}
    text = path.read_text()
    try:
        data = json.loads(strip_jsonc(text))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: merge-omarchy-menu.py <ours.jsonc> <target.jsonc> <mode>", file=sys.stderr)
        return 2
    ours_path = Path(sys.argv[1])
    target = Path(sys.argv[2])
    mode = sys.argv[3]
    incoming = load_jsonc(ours_path)
    existing = load_jsonc(target)
    if mode == "uninstall":
        for key in list(existing):
            if ours(key) and key != "install.blackomarchy":
                del existing[key]
        if "install.blackomarchy" in incoming:
            existing["install.blackomarchy"] = incoming["install.blackomarchy"]
    else:
        existing.update(incoming)
    target.parent.mkdir(parents=True, exist_ok=True)
    header = (
        "// Extended by Black omARCHy. Other keys in this file are yours.\n"
        "// Install/Remove > Black omARCHy uses this overlay.\n"
    )
    target.write_text(header + json.dumps(existing, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
