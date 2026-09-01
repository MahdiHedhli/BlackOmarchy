#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)

[[ -f $HERE/share/skills/black-omarchy/SKILL.md ]] || exit 1
[[ -f $HERE/share/skills/black-omarchy-pentest/SKILL.md ]] || exit 1
[[ -f $HERE/share/skills/black-omarchy-pentest/references/tools.md ]] || exit 1

# Discovery trees must match the install payload (ignore share/skills/README.md).
for name in black-omarchy black-omarchy-pentest; do
  diff -rq "$HERE/share/skills/$name" "$HERE/.grok/skills/$name" >/dev/null
  diff -rq "$HERE/share/skills/$name" "$HERE/.agents/skills/$name" >/dev/null
done

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
