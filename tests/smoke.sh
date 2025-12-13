#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Avoid network calls during tests.
export NETINFO_EXTERNAL_IP=0

# Source the profile in a non-interactive context.
# shellcheck source=/dev/null
source "$repo_root/.bash_profile"

# Verify key helpers are defined.
for fn in sysinfo netinfo extract; do
  if ! declare -F "$fn" >/dev/null; then
    echo "Expected function '$fn' to be defined" >&2
    exit 1
  fi
done

# Verify extract completion helper is defined (registration is interactive-only).
if ! declare -F _extract_completion >/dev/null; then
  echo "Expected function '_extract_completion' to be defined" >&2
  exit 1
fi

# Ensure netinfo runs without blowing up.
netinfo >/dev/null

# Ensure netinfo machine output works.
netinfo_kv="$(netinfo --kv)"
echo "$netinfo_kv" | grep -q '^os=' || { echo "netinfo --kv missing os=" >&2; exit 1; }
echo "$netinfo_kv" | grep -q '^local_ip=' || { echo "netinfo --kv missing local_ip=" >&2; exit 1; }
echo "$netinfo_kv" | grep -q '^external_ip=' || { echo "netinfo --kv missing external_ip=" >&2; exit 1; }

# Ensure sysinfo runs without blowing up.
# Some environments may not have all optional tools; sysinfo should still print.
sysinfo >/dev/null

# Ensure sysinfo machine output works.
sysinfo_kv="$(sysinfo --kv)"
echo "$sysinfo_kv" | grep -q '^os=' || { echo "sysinfo --kv missing os=" >&2; exit 1; }
echo "$sysinfo_kv" | grep -q '^ram_total=' || { echo "sysinfo --kv missing ram_total=" >&2; exit 1; }
echo "$sysinfo_kv" | grep -q '^net_rx=' || { echo "sysinfo --kv missing net_rx=" >&2; exit 1; }
echo "$sysinfo_kv" | grep -q '^net_tx=' || { echo "sysinfo --kv missing net_tx=" >&2; exit 1; }

# Ensure extract help works.
extract --help >/dev/null

# Ensure installer dry-run works and does not modify the filesystem.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

install_target="$tmpdir/bash_profile"
install_out="$(bash "$repo_root/scripts/install.sh" --repo "$repo_root" --target "$install_target" --dry-run)"
echo "$install_out" | grep -q 'Installing symlink:' || { echo "install.sh --dry-run missing 'Installing symlink'" >&2; exit 1; }
echo "$install_out" | grep -q '^ln -s ' || { echo "install.sh --dry-run did not print ln -s" >&2; exit 1; }
if [[ -e "$install_target" || -L "$install_target" ]]; then
  echo "install.sh --dry-run modified filesystem: $install_target exists" >&2
  exit 1
fi

# Ensure installer --install-dir deploys a copy into a home-style directory.
install_dir="$tmpdir/home-install"
install_dir_out="$(bash "$repo_root/scripts/install.sh" --repo "$repo_root" --install-dir "$install_dir" --target "$install_target")"

# If we unexpectedly failed, surface context.
[[ -n "$install_dir_out" ]] || true

if [[ ! -L "$install_target" ]]; then
  echo "install.sh --install-dir did not create a symlink target: $install_target" >&2
  exit 1
fi

installed_profile_target="$(readlink "$install_target" 2>/dev/null || true)"
if [[ "$installed_profile_target" != "$install_dir/.bash_profile" ]]; then
  echo "install.sh --install-dir symlink target mismatch: got '$installed_profile_target'" >&2
  exit 1
fi

for p in "$install_dir/.bash_profile" "$install_dir/profile.d" "$install_dir/scripts"; do
  [[ -e "$p" ]] || { echo "Expected installed path missing: $p" >&2; exit 1; }
done

# Verify module toggling works (in a clean subshell).
(
  export NETINFO_EXTERNAL_IP=0
  export BASH_PROFILE_MODULES_DISABLE="netinfo"

  # Subshells inherit function definitions; clear them so we can observe what
  # the profile loader actually defines when modules are toggled.
  unset -f netinfo sysinfo extract 2>/dev/null || true

  # shellcheck source=/dev/null
  source "$repo_root/.bash_profile"
  if declare -F netinfo >/dev/null; then
    echo "Expected netinfo to be disabled via BASH_PROFILE_MODULES_DISABLE" >&2
    exit 1
  fi
  if ! declare -F sysinfo >/dev/null; then
    echo "Expected sysinfo to still be defined when netinfo is disabled" >&2
    exit 1
  fi
)

echo "ok"
