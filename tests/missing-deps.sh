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

missing_outdir="$tmp_home/missing-deps-output"
mkdir -p "$missing_outdir"
export MISSING_DEPS_OUT="$missing_outdir"

bash <<'BASH'
set -euo pipefail
blocked_commands=(curl wget ip route networksetup iwgetid ipconfig ifconfig netstat osascript diskutil sw_vers vm_stat top dscacheutil numfmt)
command() {
  if [[ "$1" == "-v" || "$1" == "-V" ]]; then
    local target="$2"
    for blocked in "${blocked_commands[@]}"; do
      [[ "$target" == "$blocked" ]] && return 1
    done
  fi
  builtin command "$@"
}

source "$HOME/.bash_profile"
netinfo --kv > "$MISSING_DEPS_OUT/netinfo.txt"
sysinfo --kv > "$MISSING_DEPS_OUT/sysinfo.txt"
BASH

netinfo_output="$missing_outdir/netinfo.txt"
sysinfo_output="$missing_outdir/sysinfo.txt"

if [[ ! -s "$netinfo_output" ]]; then
  echo "missing-deps guard: netinfo did not produce output" >&2
  exit 1
fi

for key in default_interface gateway local_ip external_ip; do
  if ! grep -q "^${key}=N/A" "$netinfo_output"; then
    echo "missing-deps guard: '$key' did not report N/A" >&2
    exit 1
  fi
done

if [[ ! -s "$sysinfo_output" ]]; then
  echo "missing-deps guard: sysinfo did not produce output" >&2
  exit 1
fi

for required in os ram_total ram_used net_rx net_tx; do
  if ! grep -q "^${required}=" "$sysinfo_output"; then
    echo "missing-deps guard: sysinfo missing field ${required}" >&2
    exit 1
  fi
done

echo "missing-deps guard: ok"
