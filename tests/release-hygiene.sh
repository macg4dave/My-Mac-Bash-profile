#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "release-hygiene: missing required file: $f" >&2
    exit 1
  fi
  if [[ ! -s "$f" ]]; then
    echo "release-hygiene: required file is empty: $f" >&2
    exit 1
  fi
}

require_contains() {
  local f="$1"
  local needle="$2"
  if ! grep -qF "$needle" "$f" 2>/dev/null; then
    echo "release-hygiene: expected '$needle' in $f" >&2
    exit 1
  fi
}

require_file "$repo_root/docs/v2.0/release_process.md"
require_file "$repo_root/docs/v2.0/migration_from_v1.md"
require_file "$repo_root/docs/v2.0/deprecation_policy.md"

require_file "$repo_root/docs/v1.0/CHANGELOG.md"
require_contains "$repo_root/docs/v1.0/CHANGELOG.md" "## Unreleased"

# Ensure Makefile test target runs the full test suite (including perf checks).
require_file "$repo_root/Makefile"
require_contains "$repo_root/Makefile" "tests/perf-startup.sh"
require_contains "$repo_root/Makefile" "tests/safe-source.sh"
require_contains "$repo_root/Makefile" "tests/missing-deps.sh"

echo "release-hygiene: ok"
