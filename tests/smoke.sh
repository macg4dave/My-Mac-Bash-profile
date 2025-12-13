#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Avoid network calls during tests.
export NETINFO_EXTERNAL_IP=0

# Source the profile in a non-interactive context.
# shellcheck source=/dev/null
source "$repo_root/.bash_profile"

# Verify key helpers are defined.
for fn in sysinfo netinfo gohome stophome make_ssh extract; do
  if ! declare -F "$fn" >/dev/null; then
    echo "Expected function '$fn' to be defined" >&2
    exit 1
  fi
done

# Basic behavior checks (input validation).
if gohome >/dev/null 2>&1; then
  echo "Expected gohome to fail when GOHOME_* vars are missing" >&2
  exit 1
fi

if make_ssh --dry-run >/dev/null 2>&1; then
  echo "Expected make_ssh --dry-run without args to fail" >&2
  exit 1
fi

out="$(make_ssh --dry-run testhost example.com testuser 2222 ~/.ssh/id_ed25519)"
case "$out" in
  *"Host testhost"*"HostName example.com"*) : ;;
  *)
    echo "Unexpected make_ssh --dry-run output:" >&2
    printf "%s\n" "$out" >&2
    exit 1
    ;;
 esac

# Ensure netinfo runs without blowing up.
netinfo >/dev/null

# Ensure sysinfo runs without blowing up.
# Some environments may not have all optional tools; sysinfo should still print.
sysinfo >/dev/null

echo "ok"
