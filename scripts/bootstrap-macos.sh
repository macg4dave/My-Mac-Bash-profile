#!/usr/bin/env bash
set -euo pipefail

# Bootstrap common dependencies on macOS.
# Safe defaults:
# - Uses Homebrew when available.
# - Supports --dry-run.

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap-macos.sh [--dry-run]

  --dry-run  Print the install commands without running them
EOF
}

dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

run() {
  if [[ "$dry_run" -eq 1 ]]; then
    local q=()
    local a
    for a in "$@"; do
      q+=("$(printf '%q' "$a")")
    done
    printf '%s\n' "${q[*]}"
  else
    "$@"
  fi
}

if [[ "$(uname -s 2>/dev/null)" != "Darwin" ]]; then
  echo "This script is for macOS (Darwin)." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install it from https://brew.sh/ and re-run." >&2
  exit 1
fi

# Core tools used by the profile helpers.
# - shellcheck: linting
# - coreutils: provides numfmt (used by sysinfo on macOS when available)
# - wget/curl: netinfo external IP fallback
run brew update
run brew install shellcheck coreutils wget curl

cat <<'EOF'

Optional:
- sshuttle (used by gohome/stophome):
    python3 -m pip install --user sshuttle
EOF
