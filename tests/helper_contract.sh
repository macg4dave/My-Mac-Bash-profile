#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

export NETINFO_EXTERNAL_IP=0

ln -sf "$repo_root/.bash_profile" "$HOME/.bash_profile"

# shellcheck source=/dev/null
source "$HOME/.bash_profile"

helpers=(sysinfo netinfo extract flushdns jd jdir)
for helper in "${helpers[@]}"; do
  "$helper" --help >/dev/null
done

expected_netinfo=(local_hostname default_interface gateway local_ip vpn_interfaces external_ip external_hostname city)
netinfo_keys=()
while IFS='=' read -r key _; do
  [[ -n "$key" ]] || continue
  netinfo_keys+=("$key")
done < <(netinfo --kv)

if [[ "${#netinfo_keys[@]}" -ne "${#expected_netinfo[@]}" ]]; then
  printf 'helper_contract: netinfo --kv key count mismatch\n' >&2
  printf 'expected: %s\n' "${expected_netinfo[*]}" >&2
  printf 'actual:   %s\n' "${netinfo_keys[*]}" >&2
  exit 1
fi

for idx in "${!expected_netinfo[@]}"; do
  if [[ "${netinfo_keys[idx]}" != "${expected_netinfo[idx]}" ]]; then
    printf 'helper_contract: netinfo --kv order changed at position %s\n' "$((idx + 1))" >&2
    printf 'expected: %s\n' "${expected_netinfo[*]}" >&2
    printf 'actual:   %s\n' "${netinfo_keys[*]}" >&2
    exit 1
  fi
done

expected_sysinfo=(os os_version boot_volume volume_size volume_used volume_free uptime load_avg cpu_user cpu_sys cpu_idle ram_used ram_free ram_total net_rx net_tx)
sysinfo_keys=()
while IFS='=' read -r key _; do
  [[ -n "$key" ]] || continue
  sysinfo_keys+=("$key")
done < <(sysinfo --kv)

if [[ "${#sysinfo_keys[@]}" -ne "${#expected_sysinfo[@]}" ]]; then
  printf 'helper_contract: sysinfo --kv key count mismatch\n' >&2
  printf 'expected: %s\n' "${expected_sysinfo[*]}" >&2
  printf 'actual:   %s\n' "${sysinfo_keys[*]}" >&2
  exit 1
fi

for idx in "${!expected_sysinfo[@]}"; do
  if [[ "${sysinfo_keys[idx]}" != "${expected_sysinfo[idx]}" ]]; then
    printf 'helper_contract: sysinfo --kv order changed at position %s\n' "$((idx + 1))" >&2
    printf 'expected: %s\n' "${expected_sysinfo[*]}" >&2
    printf 'actual:   %s\n' "${sysinfo_keys[*]}" >&2
    exit 1
  fi
done

echo "helper_contract: ok"
