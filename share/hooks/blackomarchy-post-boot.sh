#!/bin/bash
# Omarchy post-boot hook. Re-apply the greeter wordmark and bake
# Plymouth into initramfs if a packaged refresh restored stock logos
# after the last login. A no-op when the baked digest already matches.
[[ -f /var/lib/blackomarchy/version ]] || exit 0
BRAND=/usr/local/sbin/blackomarchy-apply-login-branding
[[ -x $BRAND ]] && sudo "$BRAND" apply
