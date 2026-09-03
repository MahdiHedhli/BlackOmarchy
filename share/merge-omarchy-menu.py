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

# Menu categories under Install > Security tools. core is bootstrap-only.
SECURITY_PROFILES = (
    "web",
    "recon",
    "network",
    "wireless",
    "reversing",
    "forensics",
    "password",
)

PKG_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]*$")
LAYER_WHEN = "test -f /var/lib/blackomarchy/version"
RESERVED_CHILD = {"all"}


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


def load_profile_packages(packages_dir: Path, name: str) -> list[str]:
    path = packages_dir / f"{name}.txt"
    if not path.is_file():
        return []
    pkgs = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        pkg = line.split()[0]
        if PKG_NAME.match(pkg):
            pkgs.append(pkg)
    return pkgs


def expand_security_tools(menu: dict, packages_dir: Path | None) -> None:
    if packages_dir is None or not packages_dir.is_dir():
        return
    present = LAYER_WHEN
    for profile in SECURITY_PROFILES:
        parent = f"install.security.{profile}"
        row = menu.get(parent)
        if not isinstance(row, dict):
            continue
        action = row.pop("action", None)
        all_key = f"{parent}.all"
        if all_key not in menu and action:
            menu[all_key] = {
                "icon": row.get("icon", "󰯂"),
                "label": "All",
                "description": f"Install the curated {profile} profile",
                "when": row.get("when", present),
                "action": action,
            }
        elif all_key not in menu:
            menu[all_key] = {
                "icon": row.get("icon", "󰯂"),
                "label": "All",
                "description": f"Install the curated {profile} profile",
                "when": row.get("when", present),
                "action": (
                    "omarchy-launch-floating-terminal-with-presentation "
                    f"'sudo blackomarchy install {profile}'"
                ),
            }
        icon = row.get("icon", "󰯂")
        when = row.get("when", present)
        for pkg in load_profile_packages(packages_dir, profile):
            if pkg in RESERVED_CHILD:
                continue
            key = f"{parent}.{pkg}"
            menu[key] = {
                "icon": icon,
                "label": pkg,
                "when": when,
                "checked": f"pacman -Qq {pkg} >/dev/null 2>&1",
                "action": (
                    "omarchy-launch-floating-terminal-with-presentation "
                    f"'sudo blackomarchy install {profile} {pkg}'"
                ),
            }


def load_catalog(path: Path | None) -> list[str]:
    if path is None or not path.is_file():
        return []
    pkgs: list[str] = []
    seen: set[str] = set()
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        pkg = line.split()[0]
        if pkg in RESERVED_CHILD or pkg in seen or not PKG_NAME.match(pkg):
            continue
        seen.add(pkg)
        pkgs.append(pkg)
    pkgs.sort()
    return pkgs


def catalog_bucket(pkg: str) -> tuple[str, str]:
    ch = pkg[0].lower()
    if ch.isdigit():
        return "0", "0-9"
    if "a" <= ch <= "z":
        return ch, ch.upper()
    return "_", "#"


def expand_blackarch_catalog(menu: dict, catalog_path: Path | None) -> None:
    parent = "install.security.all"
    row = menu.get(parent)
    if not isinstance(row, dict):
        return
    # A parent with `action` is a leaf in Omarchy's menu; children never show.
    row.pop("action", None)
    present = LAYER_WHEN
    prefix = parent + "."
    all_key = f"{parent}.all"
    for key in list(menu):
        if key.startswith(prefix) and key != all_key:
            del menu[key]
    if all_key not in menu:
        menu[all_key] = {
            "icon": row.get("icon", "󰯂"),
            "label": "All",
            "description": (
                "Install every listed BlackArch package that does not "
                "conflict with Omarchy (not the blackarch metapackage)"
            ),
            "when": row.get("when", present),
            "action": (
                "omarchy-launch-floating-terminal-with-presentation "
                "'sudo blackomarchy install catalog'"
            ),
        }
    icon = row.get("icon", "󰯂")
    when = row.get("when", present)
    buckets: dict[str, str] = {}
    for pkg in load_catalog(catalog_path):
        bid, blabel = catalog_bucket(pkg)
        bkey = f"{parent}.{bid}"
        if bid not in buckets:
            buckets[bid] = blabel
            menu[bkey] = {
                "icon": icon,
                "label": blabel,
                "when": when,
            }
        menu[f"{bkey}.{pkg}"] = {
            "icon": icon,
            "label": pkg,
            "checked": f"omarchy-pkg-present {pkg}",
            "action": (
                "omarchy-launch-floating-terminal-with-presentation "
                f"'sudo blackomarchy install catalog {pkg}'"
            ),
        }


def main() -> int:
    if len(sys.argv) not in (4, 5, 6):
        print(
            "usage: merge-omarchy-menu.py <ours.jsonc> <target.jsonc> <mode> [packages_dir] [catalog]",
            file=sys.stderr,
        )
        return 2
    ours_path = Path(sys.argv[1])
    target = Path(sys.argv[2])
    mode = sys.argv[3]
    packages_dir = Path(sys.argv[4]) if len(sys.argv) >= 5 else None
    catalog_path = Path(sys.argv[5]) if len(sys.argv) == 6 else None
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
        expand_security_tools(existing, packages_dir)
        expand_blackarch_catalog(existing, catalog_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    header = (
        "// Extended by Black omARCHy. Other keys in this file are yours.\n"
        "// Install/Remove > Black omARCHy uses this overlay.\n"
    )
    target.write_text(header + json.dumps(existing, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
