#!/bin/bash
# Omarchy post-boot hook. Re-apply the greeter wordmark in case a
# packaged refresh restored the stock logo after the last login.
[[ -f /var/lib/blackomarchy/version ]] || exit 0
BRAND=/usr/local/sbin/blackomarchy-apply-login-branding
[[ -x $BRAND ]] && sudo "$BRAND" apply
