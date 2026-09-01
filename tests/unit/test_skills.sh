#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)

[[ -f $HERE/share/skills/black-omarchy/SKILL.md ]] || exit 1
[[ -f $HERE/share/skills/black-omarchy-pentest/SKILL.md ]] || exit 1
[[ -f $HERE/share/skills/black-omarchy-pentest/references/tools.md ]] || exit 1

# Repo Grok discovery tree must match the install payload.
diff -rq "$HERE/share/skills" "$HERE/.grok/skills" >/dev/null

python3 - <<PY
from pathlib import Path
root = Path("$HERE")
for path in [
    root / "share/skills/black-omarchy/SKILL.md",
    root / "share/skills/black-omarchy-pentest/SKILL.md",
]:
    text = path.read_text()
    assert text.startswith("---\n"), path
    parts = text.split("---\n", 2)
    assert len(parts) >= 3, path
    header = parts[1]
    assert "name:" in header and "description:" in header, path
PY

echo "ok agent skills"
