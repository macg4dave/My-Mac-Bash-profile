#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

startup_budget=0.9

# Create an isolated HOME to avoid touching the real user environment.
tmp_home="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_home"
}
trap cleanup EXIT

export HOME="$tmp_home"
export XDG_CACHE_HOME="$tmp_home/.cache"
export XDG_CONFIG_HOME="$tmp_home/.config"
export XDG_STATE_HOME="$tmp_home/.local/state"
mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"

# Avoid network calls when measuring startup.
export NETINFO_EXTERNAL_IP=0

ln -sf "$repo_root/.bash_profile" "$HOME/.bash_profile"

TIMEFORMAT=%R
elapsed="$( { time bash -c 'source "$HOME/.bash_profile" >/dev/null 2>&1'; } 2>&1 )"
elapsed="$(printf '%s' "$elapsed" | tr -d '[:space:]')"

printf 'startup perf: %.3fs (budget %.3fs)
' "$elapsed" "$startup_budget"

if ! awk -v val="$elapsed" -v budget="$startup_budget" 'BEGIN {exit (val != "" && val <= budget) ? 0 : 1}'; then
  echo "startup perf exceeded: ${elapsed}s > ${startup_budget}s" >&2
  exit 1
fi
