#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 "$HERE/share/merge-omarchy-menu.py" \
  "$HERE/share/omarchy-menu-blackomarchy.jsonc" \
  "$tmp/omarchy-menu.jsonc" install

python3 - "$tmp/omarchy-menu.jsonc" <<'PY'
import json, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
# header comments then JSON
body = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("//"))
data = json.loads(body)
for key in ("install.blackomarchy", "remove.blackomarchy", "install.security", "security"):
    assert key in data, key
assert data["install.blackomarchy"].get("disabled")
assert data["remove.blackomarchy"].get("when")
assert "when" not in data["install.blackomarchy"]
PY

# Uninstall keeps the Install catalog row so re-add matches other apps.
python3 "$HERE/share/merge-omarchy-menu.py" \
  "$HERE/share/omarchy-menu-blackomarchy.jsonc" \
  "$tmp/omarchy-menu.jsonc" uninstall

python3 - "$tmp/omarchy-menu.jsonc" <<'PY'
import json, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
body = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("//"))
data = json.loads(body)
assert "install.blackomarchy" in data
assert "remove.blackomarchy" not in data
assert "security" not in data
assert "install.security" not in data
assert data["install.blackomarchy"].get("disabled")
PY

echo "ok menu merge"
