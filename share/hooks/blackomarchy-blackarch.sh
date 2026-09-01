#!/bin/bash
# Called by `omarchy refresh pacman` AFTER the channel template is copied
# to /etc/pacman.conf and BEFORE pacman -Syyuu. Matches Omarchy's
# add-custom-repo.sample contract: runs as the invoking user with a warm
# sudo cache. BlackArch is appended LAST so core/extra/omarchy win.

[[ -f /var/lib/blackomarchy/version ]] || exit 0
HELPER=/usr/local/sbin/blackomarchy-reappend-repo
[[ -x $HELPER ]] || exit 0
sudo "$HELPER"
