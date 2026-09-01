#!/bin/bash
# Called by `omarchy update` via omarchy-hook post-update.
# If a migration rewrote pacman.conf, put [blackarch] back before
# the next package transaction. Recapture the Omarchy pin so verify
# does not treat a successful omarchy update as layer drift.

[[ -f /var/lib/blackomarchy/version ]] || exit 0
HELPER=/usr/local/sbin/blackomarchy-reappend-repo
[[ -x $HELPER ]] && sudo "$HELPER"
BRAND=/usr/local/sbin/blackomarchy-apply-login-branding
[[ -x $BRAND ]] && sudo "$BRAND" apply
if [[ -x /usr/local/bin/blackomarchy ]]; then
  sudo /usr/local/bin/blackomarchy recapture-baseline
fi
