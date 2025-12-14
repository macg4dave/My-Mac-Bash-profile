#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Run everything with a fake HOME so sourcing the profile cannot touch the
# real user's dotfiles or caches.
tmp_home="$(mktemp -d)"
tmpdir=""
cleanup() {
  [[ -n "${tmpdir:-}" ]] && rm -rf "$tmpdir"
  rm -rf "$tmp_home"
}
trap cleanup EXIT
export HOME="$tmp_home"
export XDG_CACHE_HOME="$tmp_home/.cache"
export XDG_CONFIG_HOME="$tmp_home/.config"
export XDG_STATE_HOME="$tmp_home/.local/state"
mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"

# Avoid network calls during tests.
export NETINFO_EXTERNAL_IP=0

# Syntax-check all bash entrypoints (fast, no side effects).
bash -n "$repo_root/.bash_profile"
for f in "$repo_root"/profile.d/*.sh "$repo_root"/scripts/*.sh "$repo_root"/tests/*.sh; do
  [[ -e "$f" ]] || continue
  bash -n "$f"
done

# Source the profile via a symlink (matches typical install behavior).
ln -s "$repo_root/.bash_profile" "$HOME/.bash_profile"

# Source the profile in a non-interactive context.
# shellcheck source=/dev/null
source "$HOME/.bash_profile"

# Verify key helpers are defined.
for fn in sysinfo netinfo extract pathinfo; do
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
echo "$netinfo_kv" | grep -q '^local_hostname=' || { echo "netinfo --kv missing local_hostname=" >&2; exit 1; }
echo "$netinfo_kv" | grep -q '^local_ip=' || { echo "netinfo --kv missing local_ip=" >&2; exit 1; }
echo "$netinfo_kv" | grep -q '^external_ip=' || { echo "netinfo --kv missing external_ip=" >&2; exit 1; }

# Ensure netinfo works as a standalone script.
netinfo_script_kv="$(NETINFO_EXTERNAL_IP=0 bash "$repo_root/profile.d/netinfo.sh" --kv)"
echo "$netinfo_script_kv" | grep -q '^local_hostname=' || { echo "netinfo.sh --kv missing local_hostname=" >&2; exit 1; }
echo "$netinfo_script_kv" | grep -q '^local_ip=' || { echo "netinfo.sh --kv missing local_ip=" >&2; exit 1; }
echo "$netinfo_script_kv" | grep -q '^external_ip=' || { echo "netinfo.sh --kv missing external_ip=" >&2; exit 1; }

# Ensure sysinfo runs without blowing up.
# Some environments may not have all optional tools; sysinfo should still print.
sysinfo >/dev/null

# Ensure sysinfo produces human output (not empty).
sysinfo_human="$(sysinfo --plain)"
if [[ -z "${sysinfo_human//[[:space:]]/}" ]]; then
  echo "sysinfo --plain produced no output" >&2
  exit 1
fi
echo "$sysinfo_human" | grep -Eq '(^|[[:space:]])OS[:[:space:]]' || {
  echo "sysinfo --plain output missing OS field" >&2
  printf '%s\n' "$sysinfo_human" >&2
  exit 1
}

# Ensure sysinfo machine output works.
sysinfo_kv="$(sysinfo --kv)"
echo "$sysinfo_kv" | grep -q '^os=' || { echo "sysinfo --kv missing os=" >&2; exit 1; }
echo "$sysinfo_kv" | grep -q '^ram_total=' || { echo "sysinfo --kv missing ram_total=" >&2; exit 1; }
echo "$sysinfo_kv" | grep -q '^net_rx=' || { echo "sysinfo --kv missing net_rx=" >&2; exit 1; }
echo "$sysinfo_kv" | grep -q '^net_tx=' || { echo "sysinfo --kv missing net_tx=" >&2; exit 1; }

# Ensure sysinfo works as a standalone script.
sysinfo_script_kv="$(bash "$repo_root/profile.d/sysinfo.sh" --kv)"
echo "$sysinfo_script_kv" | grep -q '^os=' || { echo "sysinfo.sh --kv missing os=" >&2; exit 1; }
echo "$sysinfo_script_kv" | grep -q '^ram_total=' || { echo "sysinfo.sh --kv missing ram_total=" >&2; exit 1; }
echo "$sysinfo_script_kv" | grep -q '^net_rx=' || { echo "sysinfo.sh --kv missing net_rx=" >&2; exit 1; }
echo "$sysinfo_script_kv" | grep -q '^net_tx=' || { echo "sysinfo.sh --kv missing net_tx=" >&2; exit 1; }

sysinfo_script_human="$(bash "$repo_root/profile.d/sysinfo.sh" --plain)"
if [[ -z "${sysinfo_script_human//[[:space:]]/}" ]]; then
  echo "sysinfo.sh --plain produced no output" >&2
  exit 1
fi
echo "$sysinfo_script_human" | grep -Eq '(^|[[:space:]])OS[:[:space:]]' || {
  echo "sysinfo.sh --plain output missing OS field" >&2
  printf '%s\n' "$sysinfo_script_human" >&2
  exit 1
}

# Ensure extract help works.
extract --help >/dev/null

# Ensure pathinfo help works.
pathinfo --help >/dev/null

# Ensure installer dry-run works and does not modify the filesystem.
tmpdir="$(mktemp -d)"

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
install_dir_out="$(bash "$repo_root/scripts/install.sh" --repo "$repo_root" --install-dir "$install_dir" --target "$install_target" --bootstrap none)"

# If we unexpectedly failed, surface context.
[[ -n "$install_dir_out" ]] || true

if [[ ! -L "$install_target" ]]; then
  echo "install.sh --install-dir did not create a symlink target: $install_target" >&2
  exit 1
fi

installed_profile_target="$(readlink "$install_target" 2>/dev/null || true)"

# On macOS, /var is commonly a symlink to /private/var; the installer resolves
# physical paths (cd -P), so normalize our expectation the same way.
install_dir_phys="$install_dir"
if [[ -d "$install_dir" ]]; then
  install_dir_phys="$(cd -P -- "$install_dir" 2>/dev/null && pwd || echo "$install_dir")"
fi

if [[ "$installed_profile_target" != "$install_dir_phys/.bash_profile" ]]; then
  echo "install.sh --install-dir symlink target mismatch: got '$installed_profile_target'" >&2
  exit 1
fi

for p in "$install_dir/.bash_profile" "$install_dir/profile.d" "$install_dir/scripts"; do
  [[ -e "$p" ]] || { echo "Expected installed path missing: $p" >&2; exit 1; }
done

# Ensure script help flags work (argument parsing sanity checks).
bash "$repo_root/scripts/install.sh" --help >/dev/null
bash "$repo_root/scripts/bootstrap-linux.sh" --help >/dev/null
bash "$repo_root/scripts/bootstrap-macos.sh" --help >/dev/null

# Ensure bootstrap-linux dry-run prints expected commands (without executing).
stub_bin="$tmp_home/stub-bin"
mkdir -p "$stub_bin"
cat >"$stub_bin/apt-get" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$stub_bin/apt-get"

bootstrap_linux_out="$(PATH="$stub_bin:$PATH" bash "$repo_root/scripts/bootstrap-linux.sh" --dry-run)"
echo "$bootstrap_linux_out" | grep -q '^sudo apt-get update$' || { echo "bootstrap-linux --dry-run missing apt-get update" >&2; exit 1; }
echo "$bootstrap_linux_out" | grep -q '^sudo apt-get install -y ' || { echo "bootstrap-linux --dry-run missing apt-get install" >&2; exit 1; }

bootstrap_linux_full_out="$(PATH="$stub_bin:$PATH" bash "$repo_root/scripts/bootstrap-linux.sh" --dry-run --full)"
echo "$bootstrap_linux_full_out" | grep -q 'p7zip' || { echo "bootstrap-linux --full --dry-run missing optional packages" >&2; exit 1; }

# If we are on macOS with Homebrew, ensure bootstrap-macos dry-run prints commands.
if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
  bootstrap_macos_out="$(bash "$repo_root/scripts/bootstrap-macos.sh" --dry-run)"
  echo "$bootstrap_macos_out" | grep -q '^brew update$' || { echo "bootstrap-macos --dry-run missing brew update" >&2; exit 1; }
  echo "$bootstrap_macos_out" | grep -q '^brew install ' || { echo "bootstrap-macos --dry-run missing brew install" >&2; exit 1; }
fi

# Verify module toggling works (in a clean subshell).
(
  export NETINFO_EXTERNAL_IP=0
  export BASH_PROFILE_MODULES_DISABLE="netinfo"

  # Subshells inherit function definitions; clear them so we can observe what
  # the profile loader actually defines when modules are toggled.
  unset -f netinfo sysinfo extract 2>/dev/null || true

  # shellcheck source=/dev/null
  source "$HOME/.bash_profile"
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
