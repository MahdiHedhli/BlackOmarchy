#!/bin/bash
# Called by `omarchy update` via omarchy-hook post-update.
# Re-append [blackarch] if a migration rewrote pacman.conf, refresh the
# Black omARCHy layer from git, then restore the login wordmark.
# A failed layer pull must not fail the Omarchy update.

[[ -f /var/lib/blackomarchy/version ]] || exit 0
HELPER=/usr/local/sbin/blackomarchy-reappend-repo
[[ -x $HELPER ]] && sudo "$HELPER"
if [[ -x /usr/local/bin/blackomarchy-update ]]; then
  /usr/local/bin/blackomarchy-update || echo "blackomarchy-update skipped or failed"
else
  BRAND=/usr/local/sbin/blackomarchy-apply-login-branding
  [[ -x $BRAND ]] && sudo "$BRAND" apply
  if [[ -x /usr/local/bin/blackomarchy ]]; then
    sudo /usr/local/bin/blackomarchy recapture-baseline
  fi
fi
