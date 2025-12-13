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

echo "ok"
