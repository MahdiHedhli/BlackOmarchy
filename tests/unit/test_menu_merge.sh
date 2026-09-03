#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

printf 'zzuf\n0d1n\nall\n' >"$tmp/catalog.txt"
python3 "$HERE/share/merge-omarchy-menu.py" \
  "$HERE/share/omarchy-menu-blackomarchy.jsonc" \
  "$tmp/omarchy-menu.jsonc" install "$HERE/packages" "$tmp/catalog.txt"

python3 - "$tmp/omarchy-menu.jsonc" <<'PY'
import json, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
# header comments then JSON
body = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("//"))
data = json.loads(body)
for key in ("install.blackomarchy", "remove.blackomarchy", "install.security", "install.security.all", "install.security.all.all", "security"):
    assert key in data, key
assert data["install.blackomarchy"].get("disabled")
assert data["remove.blackomarchy"].get("when")
assert "when" not in data["install.blackomarchy"]
assert "action" not in data["install.security.web"], "web must be a submenu"
assert "action" not in data["install.security.all"], "All must be a submenu"
assert data["install.security.web.all"]["action"]
assert "install.security.web.sqlmap" in data
assert "sudo blackomarchy install web sqlmap" in data["install.security.web.sqlmap"]["action"]
assert "sudo blackomarchy install catalog" in data["install.security.all.all"]["action"]
assert "action" not in data["install.security.all.0"]
assert "install.security.all.0.0d1n" in data
assert "install.security.all.z.zzuf" in data
assert "install.security.all.0d1n" not in data
assert "install.security.all.all.all" not in data
assert "sudo blackomarchy install catalog 0d1n" in data["install.security.all.0.0d1n"]["action"]
assert "install.security.password.cewl" in data
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
