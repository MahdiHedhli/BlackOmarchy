#!/usr/bin/env bash
# Copy the public tree to a VM and run bootstrap. Requires tests/vm/local.env.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
envfile="$HERE/tests/vm/local.env"
[[ -f $envfile ]] || { echo "missing tests/vm/local.env" >&2; exit 1; }
# shellcheck disable=SC1090
source "$envfile"
: "${BLACKOMARCHY_SSH_HOST:?}"
: "${BLACKOMARCHY_SSH_USER:?}"
ssh_opts=(-o IdentitiesOnly=yes -o StrictHostKeyChecking=yes)
if [[ -n ${BLACKOMARCHY_SSH_IDENTITY:-} ]]; then
  ssh_opts+=(-i "$BLACKOMARCHY_SSH_IDENTITY")
fi
if [[ -n ${BLACKOMARCHY_SSH_KNOWN_HOSTS:-} ]]; then
  ssh_opts+=(-o "UserKnownHostsFile=$BLACKOMARCHY_SSH_KNOWN_HOSTS")
fi
remote_dir=${BLACKOMARCHY_REMOTE_DIR:-/home/omarchy/BlackOmarchy}
rsync -az --delete \
  --exclude '.git' \
  --exclude 'private' \
  --exclude 'build' \
  --exclude 'tests/vm/local.env' \
  -e "ssh ${ssh_opts[*]}" \
  "$HERE/" \
  "${BLACKOMARCHY_SSH_USER}@${BLACKOMARCHY_SSH_HOST}:${remote_dir}/"
ssh "${ssh_opts[@]}" "${BLACKOMARCHY_SSH_USER}@${BLACKOMARCHY_SSH_HOST}" \
  "sudo bash ${remote_dir}/bootstrap.sh"
