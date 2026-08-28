#!/usr/bin/env bash
# User-owned Omarchy hook. Delegates to a root-owned helper.
set -euo pipefail
exec /usr/local/sbin/blackomarchy-reappend-repo
