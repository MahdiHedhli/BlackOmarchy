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

parse_sig_issuer_fingerprint() {
  local sig=$1 fpr
  fpr=$(gpg --batch --list-packets "$sig" 2>/dev/null \
    | awk '/issuer fpr v4/ {
        gsub(/[^0-9A-Fa-f]/, "", $NF)
        print $NF
        exit
      }')
  [[ $fpr =~ ^[0-9A-Fa-f]{40}$ ]] || return 1
  printf '%s\n' "$(upper_hex "$fpr")"
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
  local homedir=$1 fp=$2
  local server
  for server in hkps://keyserver.ubuntu.com hkps://keys.openpgp.org; do
    if gpg --homedir "$homedir" --batch --pinentry-mode loopback \
      --keyserver "$server" --recv-keys "$fp" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

verify_keyring_tarball() {
  local tarfile=$1 sigfile=$2 strap_fingerprint=$3
  have_cmd gpg || die "gpg is required to verify the BlackArch keyring"
  local issuer
  issuer=$(parse_sig_issuer_fingerprint "$sigfile") \
    || die "could not parse issuer fingerprint from BlackArch keyring signature"
  if [[ -n $strap_fingerprint && $(upper_hex "$issuer") != "$(upper_hex "$strap_fingerprint")" ]]; then
    log "strap.sh lists key $strap_fingerprint; live keyring is signed by $issuer"
  fi
  signer_allowed "$issuer" || die "keyring signer $issuer is not in the BlackArch allowlist"
  local homedir
  homedir=$(make_priv_tempdir)
  chmod 700 "$homedir"
  export GNUPGHOME=$homedir
  gpg_recv_fingerprint "$homedir" "$issuer" \
    || { unset GNUPGHOME; rm -rf "$homedir"; die "could not retrieve BlackArch keyring signing key $issuer"; }
  local got
  got=$(gpg --homedir "$homedir" --batch --with-colons --fingerprint "$issuer" \
    | awk -F: '/^fpr:/ {print $10; exit}')
  if [[ $(upper_hex "$got") != "$(upper_hex "$issuer")" ]]; then
    unset GNUPGHOME
    rm -rf "$homedir"
    die "retrieved GPG fingerprint does not match the keyring signature issuer"
  fi
  if ! gpg --homedir "$homedir" --batch --verify "$sigfile" "$tarfile" >/dev/null 2>&1; then
    unset GNUPGHOME
    rm -rf "$homedir"
    die "BlackArch keyring signature verification failed"
  fi
  unset GNUPGHOME
  rm -rf "$homedir"
  printf '%s\n' "$issuer"
}

extract_keyring_names() {
  tar tzf "$1" | awk -F/ '{print $NF}' | grep -E '^blackarch' || true
}

keyring_files_match() {
  local package=$1
  local extracted dest f
  extracted=$(make_priv_tempdir)

  bsdtar -xf "$package" -C "$extracted" || {
    rm -rf "$extracted"
    return 1
  }

  dest=$(blackomarchy_path /usr/share/pacman/keyrings)

  for f in "$extracted"/usr/share/pacman/keyrings/blackarch*; do
    [[ -e $f ]] || continue

    local base
    base=$(basename "$f")

    [[ -f $dest/$base ]] || {
      rm -rf "$extracted"
      return 1
    }

    cmp -s "$f" "$dest/$base" || {
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

  homedir=$(make_priv_tempdir)
  chmod 700 "$homedir"

  for fpr in "${ALLOWED_KEYRING_SIGNERS[@]}"; do
    if ! gpg --homedir "$homedir" \
      --batch \
      --pinentry-mode loopback \
      --keyserver hkps://keyserver.ubuntu.com \
      --recv-keys "$fpr" >/dev/null 2>&1; then

      gpg --homedir "$homedir" \
        --batch \
        --pinentry-mode loopback \
        --keyserver hkps://keys.openpgp.org \
        --recv-keys "$fpr" >/dev/null 2>&1 || true
    fi
  done

  status=$(
    gpg --homedir "$homedir" \
      --status-fd 1 \
      --verify "$sig" "$pkg" 2>/dev/null || true
  )

  signer=$(printf '%s\n' "$status" |
    awk '$2 == "VALIDSIG" { print $NF; exit }')

  if [[ -z $signer ]]; then
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

  keyring_pkg=$(
    bsdtar -xOf "$work/blackarch.db" 'blackarch-keyring-*/desc' 2>/dev/null |
      awk '/^%FILENAME%$/ { getline; print; exit }'
  )

  [[ -n $keyring_pkg ]] \
    || die "could not find blackarch-keyring in the BlackArch repository database"

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

  if ! sh "$work/strap.sh"; then
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
