#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
fail=0
for t in "$HERE"/test_*.sh; do
  echo "RUN $(basename "$t")"
  if ! bash "$t"; then
    echo "FAIL $(basename "$t")"
    fail=1
  fi
done
exit "$fail"
