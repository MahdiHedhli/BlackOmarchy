#!/usr/bin/env bash
# Official BlackArch strap.sh wrap: live SHA1 + keyring signature.

if [[ -n ${BLACKOMARCHY_BLACKARCH_LOADED:-} ]]; then
  return 0 2>/dev/null || true
fi
BLACKOMARCHY_BLACKARCH_LOADED=1

parse_strap_sha1_from_page() {
  local page=$1 hash
  hash=$(grep -Eo 'echo[[:space:]]+[0-9a-f]{40}[[:space:]]+strap\.sh' "$page" \
    | awk '{print $2}' | head -n 1)
  [[ $hash =~ ^[0-9a-f]{40}$ ]] || return 1
  printf '%s\n' "$hash"
}

verify_sha1_file() {
  local expected=$1 file=$2
  local line
  line=$(printf '%s  %s\n' "$expected" "$file")
  if have_cmd sha1sum && sha1sum --help >/dev/null 2>&1; then
    printf '%s' "$line" | sha1sum -c --status
  elif have_cmd shasum; then
    printf '%s' "$line" | shasum -a 1 -c >/dev/null
  elif have_cmd sha1sum; then
    printf '%s' "$line" | sha1sum -c >/dev/null
  else
    die "sha1sum or shasum is required"
  fi
}

fetch_official_strap_sha1() {
  local tmp page hash
  tmp=$(make_priv_tempdir)
  page="$tmp/downloads.html"
  https_get "$BLACKARCH_DOWNLOADS_URL" "$page"
  hash=$(parse_strap_sha1_from_page "$page") \
    || die "could not parse official strap.sh SHA1 from downloads.html"
  rm -rf "$tmp"
  printf '%s\n' "$hash"
}

# Trusted BlackArch keyring signing keys (full 40-character primary-key
# fingerprints). VALIDSIG reports the primary fingerprint, so entries must be
# primary keys, not subkeys.
# Source: https://github.com/BlackArch/blackarch-site/blob/master/strap.sh
ALLOWED_KEYRING_SIGNERS=(
  8F9A9793CB8591147C2EC70566E0CDBD1E01F333
  A0917C4147A37007CB54C1CFD295AA940EFDDF62
  4345771566D76038C7FEB43863EC0ADBEA87E4E3
  F9A6E68A711354D84A9B91637533BAFE69A25079
)

signer_allowed() {
  local fp=$1 s
  for s in "${ALLOWED_KEYRING_SIGNERS[@]}"; do
    [[ $(upper_hex "$fp") == "$s" ]] && return 0
  done
  return 1
}

gpg_recv_fingerprint() {
  local homedir=$1 fp=$2 server
  for server in hkps://keyserver.ubuntu.com hkps://keys.openpgp.org; do
    if gpg --no-options --homedir "$homedir" --batch --pinentry-mode loopback \
      --keyserver-options timeout=15 --keyserver "$server" \
      --recv-keys "$fp" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

parse_keyring_package_filename() {
  local description filename
  description=$(bsdtar -xOf "$1" 'blackarch-keyring-*/desc' 2>/dev/null) || return 1
  filename=$(printf '%s\n' "$description" | awk '/^%FILENAME%$/ { getline; print }')
  # Repository metadata is untrusted until the package signature is checked.
  # Accept one package basename only; never let metadata choose a local path.
  [[ $filename =~ ^blackarch-keyring-[0-9][A-Za-z0-9._+-]*-any\.pkg\.tar\.(zst|xz|gz)$ ]] || return 1
  printf '%s\n' "$filename"
}

keyring_files_match() {
  local package=$1
  local extracted dest base
  extracted=$(make_priv_tempdir)

  # Extract only the three required files, not unrelated package contents.
  bsdtar -xf "$package" -C "$extracted" \
    usr/share/pacman/keyrings/blackarch.gpg \
    usr/share/pacman/keyrings/blackarch-trusted \
    usr/share/pacman/keyrings/blackarch-revoked 2>/dev/null || {
    rm -rf "$extracted"
    return 1
  }

  dest=$(blackomarchy_path /usr/share/pacman/keyrings)

  for base in blackarch.gpg blackarch-trusted blackarch-revoked; do
    [[ -f $extracted/usr/share/pacman/keyrings/$base &&
       ! -L $extracted/usr/share/pacman/keyrings/$base &&
       -f $dest/$base && ! -L $dest/$base ]] || {
      rm -rf "$extracted"
      return 1
    }

    cmp -s "$extracted/usr/share/pacman/keyrings/$base" "$dest/$base" || {
      rm -rf "$extracted"
      return 1
    }
  done

  rm -rf "$extracted"
  return 0
}

should_run_strap() {
  if blackarch_ambiguous; then
    die "ambiguous [blackarch] configuration in pacman.conf (commented or disabled stanza)"
  fi
  if repo_enabled blackarch; then
    require_omarchy_repos
    assert_single_blackarch
    return 1
  fi
  return 0
}

verify_keyring_package() {
  local pkg=$1
  local sig=$2
  local homedir signer status fpr

  have_cmd gpg || die "gpg is required to verify the BlackArch keyring"
  [[ -s $pkg && -s $sig ]] || die "BlackArch keyring package or signature is missing or empty"

  homedir=$(make_priv_tempdir)
  chmod 700 "$homedir"

  for fpr in "${ALLOWED_KEYRING_SIGNERS[@]}"; do
    gpg_recv_fingerprint "$homedir" "$fpr" || true
  done

  if ! status=$(
    gpg --no-options --homedir "$homedir" --batch \
      --status-fd 1 \
      --verify "$sig" "$pkg" 2>/dev/null
  ); then
    rm -rf "$homedir"
    die "BlackArch keyring signature verification failed (invalid signature or unavailable key)"
  fi

  # VALIDSIG alone is insufficient: GPG may also report an expired/revoked key.
  if printf '%s\n' "$status" | grep -Eq '^\[GNUPG:\] (BADSIG|ERRSIG|EXPSIG|EXPKEYSIG|REVKEYSIG|KEYREVOKED|KEYEXPIRED|SIGEXPIRED|NO_PUBKEY|FAILURE)( |$)'; then
    rm -rf "$homedir"
    die "BlackArch keyring signature is invalid, expired, or revoked"
  fi

  signer=$(printf '%s\n' "$status" |
    awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" { print $NF }')

  if [[ ! $signer =~ ^[0-9A-Fa-f]{40}$ ]]; then
    rm -rf "$homedir"
    die "could not verify BlackArch keyring signature"
  fi

  signer=$(upper_hex "$signer")

  if ! signer_allowed "$signer"; then
    rm -rf "$homedir"
    die "BlackArch keyring signed by untrusted key $signer"
  fi

  rm -rf "$homedir"

  printf '%s\n' "$signer"
}

run_official_strap() {
  local work sha1 keyring_pkg keyring_url
  have_cmd bsdtar || die "bsdtar is required to inspect the BlackArch keyring package"
  have_cmd setsid || die "setsid (util-linux) is required to isolate the BlackArch bootstrap"
  work=$(make_priv_tempdir)

  sha1=$(fetch_official_strap_sha1)
  log "official strap.sh SHA1 $sha1"

  https_get "$BLACKARCH_STRAP_URL" "$work/strap.sh"
  verify_sha1_file "$sha1" "$work/strap.sh" \
    || die "strap.sh SHA1 does not match the official downloads page"

  # Discover the current blackarch-keyring package from the
  # official BlackArch repository database, matching the current
  # upstream strap.sh implementation.
  local repo
  repo="${BLACKARCH_MIRROR_BASE:-https://blackarch.org/blackarch/blackarch/os/$(uname -m)}"

  log "fetching BlackArch repository database"
  https_get "$repo/blackarch.db" "$work/blackarch.db"

  keyring_pkg=$(parse_keyring_package_filename "$work/blackarch.db") \
    || die "could not find a safe blackarch-keyring package filename in the repository database"

  keyring_url="$repo/$keyring_pkg"

  log "verifying $keyring_pkg"

  https_get "$keyring_url" "$work/$keyring_pkg"
  https_get "$keyring_url.sig" "$work/$keyring_pkg.sig"

  local signer
  signer=$(verify_keyring_package \
    "$work/$keyring_pkg" \
    "$work/$keyring_pkg.sig") \
    || die "BlackArch keyring package verification failed"

  log "keyring signature ok ($signer)"

  local before after
  before=$(mktemp)
  snapshot_packages >"$before" 2>/dev/null || true

  unset OMARCHY_ALLOW_DIRECT_PACMAN OMARCHY_UPDATE_PACMAN

  # Current upstream asks for a full upgrade via /dev/tty. A separate session
  # has no controlling terminal, so upstream takes its explicit 'n' fallback.
  # Execute the hash-verified script unchanged; updates remain omarchy update.
  if ! setsid --wait sh "$work/strap.sh" </dev/null; then
    rm -rf "$work" "$before"
    fail_restore "official BlackArch strap.sh failed"
  fi

  if ! keyring_files_match "$work/$keyring_pkg"; then
    rm -rf "$work" "$before"
    fail_restore "installed BlackArch keyring does not match the independently verified package"
  fi

  after=$(mktemp)
  snapshot_packages >"$after" 2>/dev/null || true

  local changed
  changed=$(comm -13 <(sort "$after") <(sort "$before") || true)

  if [[ -n $changed ]]; then
    rm -rf "$work" "$before" "$after"
    fail_restore "strap.sh changed already-installed packages"
  fi

  printf '%s\n' "$sha1" >"$(state_dir)/verified-strap.sha1"
  printf '%s\n' "$signer" >"$(state_dir)/keyring-fingerprint"
  printf '%s\n' "$keyring_pkg" >"$(state_dir)/keyring-package"

  append_manifest_line $'package\tblackarch-mirrorlist\tPASS WITH DEPENDENCIES\tblackarch'

  rm -rf "$work" "$before" "$after"

  require_omarchy_repos
  assert_single_blackarch
  repo_enabled blackarch || fail_restore "strap.sh did not enable the blackarch repository"

  local expected_server actual_server
  if [[ -n ${BLACKOMARCHY_CURRENT_BACKUP:-} && -f $BLACKOMARCHY_CURRENT_BACKUP/omarchy-server ]]; then
    expected_server=$(cat "$BLACKOMARCHY_CURRENT_BACKUP/omarchy-server")
    actual_server=$(omarchy_server_line)

    if [[ $expected_server != "$actual_server" ]]; then
      fail_restore "Omarchy Server= line changed during strap.sh"
    fi
  fi

  log "BlackArch repository enabled"
}

blackarch_keyring_present() {
  local dest f
  dest=$(blackomarchy_path /usr/share/pacman/keyrings)
  [[ -d $dest ]] || return 1
  for f in "$dest"/blackarch*; do
    [[ -f $f ]] && return 0
  done
  return 1
}

ensure_blackarch_repo() {
  require_omarchy_repos
  if repo_enabled blackarch; then
    log "enabled blackarch repository already present; skipping strap.sh"
    assert_single_blackarch
    return 0
  fi
  if blackarch_ambiguous; then
    die "ambiguous [blackarch] configuration in pacman.conf (commented or disabled stanza)"
  fi
  # Channel refresh copies a template over pacman.conf and drops [blackarch].
  # Keyring + mirrorlist survive; put the stanza back instead of re-running strap.
  if [[ -f $(blackomarchy_path /etc/pacman.d/blackarch-mirrorlist) ]] && blackarch_keyring_present; then
    log "BlackArch keyring present; re-appending [blackarch] after pacman.conf rewrite"
    append_blackarch_stanza
    assert_single_blackarch
    repo_enabled blackarch || die "failed to re-enable the blackarch repository"
    return 0
  fi
  run_official_strap
}
