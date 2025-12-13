#!/usr/bin/env bash
set -euo pipefail

# Bootstrap common dependencies on Linux.
# Safe defaults:
# - Installs only a small "core" set unless --full is provided.
# - Supports --dry-run.
# - Soft-fails when no supported package manager is found.

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap-linux.sh [--full] [--dry-run]

  --full     Install optional tools used by some helpers (sshuttle, 7z, unrar, iwgetid, etc)
  --dry-run  Print the install commands without running them
EOF
}

full=0
dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) full=1 ;;
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

# Prefer explicit manager commands to keep behavior predictable.
if command -v apt-get >/dev/null 2>&1; then
  core_pkgs=(shellcheck curl wget unzip xz-utils)
  opt_pkgs=(sshuttle p7zip-full unrar wireless-tools iproute2)
  run sudo apt-get update
  run sudo apt-get install -y "${core_pkgs[@]}"
  if [[ "$full" -eq 1 ]]; then
    run sudo apt-get install -y "${opt_pkgs[@]}"
  fi
  exit 0
fi

if command -v dnf >/dev/null 2>&1; then
  core_pkgs=(ShellCheck curl wget unzip xz)
  opt_pkgs=(sshuttle p7zip p7zip-plugins unrar wireless-tools iproute)
  run sudo dnf install -y "${core_pkgs[@]}"
  if [[ "$full" -eq 1 ]]; then
    run sudo dnf install -y "${opt_pkgs[@]}"
  fi
  exit 0
fi

if command -v yum >/dev/null 2>&1; then
  core_pkgs=(ShellCheck curl wget unzip xz)
  opt_pkgs=(sshuttle p7zip p7zip-plugins unrar wireless-tools iproute)
  run sudo yum install -y "${core_pkgs[@]}"
  if [[ "$full" -eq 1 ]]; then
    run sudo yum install -y "${opt_pkgs[@]}"
  fi
  exit 0
fi

if command -v pacman >/dev/null 2>&1; then
  core_pkgs=(shellcheck curl wget unzip xz)
  opt_pkgs=(sshuttle p7zip unrar wireless_tools iproute2)
  run sudo pacman -Sy --noconfirm "${core_pkgs[@]}"
  if [[ "$full" -eq 1 ]]; then
    run sudo pacman -Sy --noconfirm "${opt_pkgs[@]}"
  fi
  exit 0
fi

if command -v zypper >/dev/null 2>&1; then
  core_pkgs=(ShellCheck curl wget unzip xz)
  opt_pkgs=(sshuttle p7zip unrar wireless-tools iproute2)
  run sudo zypper --non-interactive install "${core_pkgs[@]}"
  if [[ "$full" -eq 1 ]]; then
    run sudo zypper --non-interactive install "${opt_pkgs[@]}"
  fi
  exit 0
fi

if command -v apk >/dev/null 2>&1; then
  core_pkgs=(shellcheck curl wget unzip xz)
  opt_pkgs=(sshuttle p7zip unrar wireless-tools iproute2)
  run sudo apk add "${core_pkgs[@]}"
  if [[ "$full" -eq 1 ]]; then
    run sudo apk add "${opt_pkgs[@]}"
  fi
  exit 0
fi

echo "No supported package manager found. Install at least: shellcheck curl wget" >&2
exit 1
