#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmp_home="$(mktemp -d)"
before_list="$tmp_home/before.txt"
after_list="$tmp_home/after.txt"
before_filtered="$tmp_home/before_filtered.txt"
after_filtered="$tmp_home/after_filtered.txt"
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

stub_root="$tmp_home/.safe-source-stubs"
stub_bin="$stub_root/bin"
stub_log="$stub_root/log"
mkdir -p "$stub_bin" "$stub_log"
export SAFE_SOURCE_STUB_LOG="$stub_log"

blocked_commands=(curl wget ip route networksetup iwgetid ipconfig ifconfig netstat osascript diskutil sw_vers vm_stat top dscacheutil killall)
for cmd in "${blocked_commands[@]}"; do
  cat <<'EOF' > "$stub_bin/$cmd"
#!/usr/bin/env bash
set -euo pipefail
log_dir="${SAFE_SOURCE_STUB_LOG:-}"
mkdir -p "$log_dir"
touch "$log_dir/$cmd"
echo "Blocked $cmd invoked during safe-source guard" >&2
exit 1
EOF
  chmod +x "$stub_bin/$cmd"
done

ln -sf "$repo_root/.bash_profile" "$HOME/.bash_profile"

PATH="$stub_bin:$PATH"

# Capture state before sourcing so we can detect stray writes.
find "$tmp_home" -mindepth 1 -print | sed "s#^$tmp_home/##" | sort > "$before_list"

allowed_pattern='^(\.bash_profile$|\.cache/|\.config/|\.local/state/|\.safe-source-stubs/|before\.txt$|after\.txt$|before_filtered\.txt$|after_filtered\.txt$)'
grep -Ev "$allowed_pattern" "$before_list" | sort > "$before_filtered"

# Source with blocked commands at the front of PATH.
source "$HOME/.bash_profile"

# Verify no forbidden commands ran (a stub exiting would have failed earlier).
if [[ -n "$(find "$stub_log" -mindepth 1 -print -quit)" ]]; then
  echo "safe-source guard: blocked command executed" >&2
  ls -1 "$stub_log"
  exit 1
fi

find "$tmp_home" -mindepth 1 -print | sed "s#^$tmp_home/##" | sort > "$after_list"
grep -Ev "$allowed_pattern" "$after_list" | sort > "$after_filtered"

if ! diff -u "$before_filtered" "$after_filtered" >/dev/null 2>&1; then
  echo "safe-source guard: unexpected files created outside allowed directories" >&2
  diff -u "$before_filtered" "$after_filtered" >&2
  exit 1
fi

echo "safe-source guard: ok"