#!/usr/bin/env bash
set -euo pipefail

# Conservative installer for this repo.
# - Installs by symlinking the repo's `.bash_profile` into place.
# - Makes a timestamped backup before changing an existing target.
# - Idempotent: if already installed, does nothing.
# - Optional: can run bootstrap scripts (off by default).

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [options]

Options:
  --repo <path>        Path to the repo root (default: auto-detect from this script)
  --install-dir <path> Copy runtime files into this directory, then link the target to it
  --target <path>      Where to install the symlink (default: $HOME/.bash_profile)
  --dry-run, -n        Print what would change, but do not modify anything
  --no-backup          Do not create backups when replacing an existing target
  --force              Replace an existing target even if it is not a file/symlink

Bootstrap (optional):
  --bootstrap <auto|linux|macos|none>   Run bootstrap script after install (default: none)
  --full                               When bootstrapping on Linux, request optional packages

Exit codes:
  0 success
  1 runtime error
  2 usage
EOF
}

# --------
# helpers
# --------

log() { printf '%s\n' "$*"; }

run() {
  if [[ "${dry_run}" -eq 1 ]]; then
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

now_stamp() {
  date +%Y%m%d-%H%M%S 2>/dev/null || echo "now"
}

unique_backup_path() {
  # Usage: unique_backup_path <path>
  # Returns a non-existing path by appending .N if needed.
  local base="$1"
  local candidate="$base"
  local n=1
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    candidate="$base.$n"
    n=$((n + 1))
  done
  printf '%s' "$candidate"
}

deploy_install_dir() {
  # Usage: deploy_install_dir <src_repo_root> <install_dir>
  # Copies runtime files into install_dir.
  local src_root="$1"
  local install_dir="$2"

  if [[ -e "$install_dir" && ! -d "$install_dir" ]]; then
    echo "Install dir exists and is not a directory: $install_dir" >&2
    exit 1
  fi

  if [[ -d "$install_dir" ]]; then
    # By default, do not overwrite an existing install directory.
    # This keeps the installer conservative and idempotent.
    if [[ "$force" -ne 1 ]]; then
      log "Install dir already exists; leaving in place (use --force to redeploy): $install_dir"
      return 0
    fi

    if [[ "$backup" -eq 1 ]]; then
      bkp_dir="$(unique_backup_path "$install_dir.bak.$(now_stamp)")"
      log "Backing up existing install dir $install_dir -> $bkp_dir"
      run mv "$install_dir" "$bkp_dir"
    else
      run rm -rf "$install_dir"
    fi
  fi

  run mkdir -p "$install_dir"

  # Copy the runtime pieces.
  run cp -p "$src_root/.bash_profile" "$install_dir/.bash_profile"
  run cp -R "$src_root/profile.d" "$install_dir/profile.d"
  run cp -R "$src_root/scripts" "$install_dir/scripts"

  # Ensure scripts remain executable (portable loop, no find -exec assumptions).
  if [[ -d "$install_dir/scripts" ]]; then
    for f in "$install_dir/scripts"/*.sh; do
      [[ -e "$f" ]] || continue
      run chmod +x "$f" || true
    done
  fi
}

is_same_symlink() {
  # Usage: is_same_symlink <link> <expected_target>
  local link="$1"
  local expected="$2"
  [[ -L "$link" ]] || return 1
  local actual
  actual="$(readlink "$link" 2>/dev/null || echo '')"
  [[ "$actual" == "$expected" ]]
}

abs_path() {
  # Resolve an absolute path without relying on GNU readlink -f.
  # Works for directories and existing files.
  local p="$1"
  if [[ -d "$p" ]]; then
    (cd -P -- "$p" && pwd)
    return 0
  fi
  local d
  d="$(dirname "$p")"
  local b
  b="$(basename "$p")"
  (cd -P -- "$d" && printf '%s/%s\n' "$(pwd)" "$b")
}

# --------
# args
# --------

dry_run=0
backup=1
force=0
bootstrap="none"
full=0

repo_root=""
install_dir=""
target="${HOME}/.bash_profile"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || { echo "--repo requires a value" >&2; usage; exit 2; }
      repo_root="$2"
      shift
      ;;
    --target)
      [[ $# -ge 2 ]] || { echo "--target requires a value" >&2; usage; exit 2; }
      target="$2"
      shift
      ;;
    --install-dir)
      [[ $# -ge 2 ]] || { echo "--install-dir requires a value" >&2; usage; exit 2; }
      install_dir="$2"
      shift
      ;;
    --dry-run|-n)
      dry_run=1
      ;;
    --no-backup)
      backup=0
      ;;
    --force)
      force=1
      ;;
    --bootstrap)
      [[ $# -ge 2 ]] || { echo "--bootstrap requires a value" >&2; usage; exit 2; }
      bootstrap="$2"
      shift
      ;;
    --full)
      full=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

if [[ -z "$repo_root" ]]; then
  # script_dir/.. is repo root
  script_dir="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd -P -- "$script_dir/.." && pwd)"
fi

repo_root="$(abs_path "$repo_root")"
repo_profile="$repo_root/.bash_profile"

if [[ ! -r "$repo_profile" ]]; then
  echo "Could not find readable $repo_profile" >&2
  exit 1
fi

target_dir="$(dirname "$target")"
if [[ ! -d "$target_dir" ]]; then
  run mkdir -p "$target_dir"
fi

target_abs="$(abs_path "$target")"

# Optional deployment mode: copy runtime files into install_dir and link to that.
if [[ -n "$install_dir" ]]; then
  install_dir_abs="$(abs_path "$install_dir")"
  deploy_install_dir "$repo_root" "$install_dir_abs"
  repo_profile_abs="$(abs_path "$install_dir_abs/.bash_profile")"
else
  repo_profile_abs="$(abs_path "$repo_profile")"
fi

if is_same_symlink "$target_abs" "$repo_profile_abs"; then
  log "Already installed: $target_abs -> $repo_profile_abs"
else
  if [[ -e "$target_abs" || -L "$target_abs" ]]; then
    if [[ "$backup" -eq 1 ]]; then
      bkp="$(unique_backup_path "$target_abs.bak.$(now_stamp)")"
      log "Backing up existing $target_abs -> $bkp"
      run mv "$target_abs" "$bkp"
    else
      if [[ "$force" -ne 1 ]]; then
        echo "Target exists ($target_abs). Re-run with --force or omit --no-backup." >&2
        exit 1
      fi
      run rm -rf "$target_abs"
    fi
  fi

  log "Installing symlink: $target_abs -> $repo_profile_abs"
  run ln -s "$repo_profile_abs" "$target_abs"
fi

case "$bootstrap" in
  none)
    ;;
  auto)
    os="$(uname -s 2>/dev/null || echo 'Unknown')"
    if [[ "$os" == "Darwin" ]]; then
      bootstrap="macos"
    else
      bootstrap="linux"
    fi
    ;;
esac

case "$bootstrap" in
  none)
    ;;
  linux)
    if [[ -x "$repo_root/scripts/bootstrap-linux.sh" ]]; then
      args=()
      [[ "$full" -eq 1 ]] && args+=("--full")
      [[ "$dry_run" -eq 1 ]] && args+=("--dry-run")
      log "Running bootstrap (linux): scripts/bootstrap-linux.sh ${args[*]}"
      run "$repo_root/scripts/bootstrap-linux.sh" "${args[@]}"
    else
      echo "bootstrap-linux.sh not found or not executable" >&2
      exit 1
    fi
    ;;
  macos)
    if [[ -x "$repo_root/scripts/bootstrap-macos.sh" ]]; then
      args=()
      [[ "$dry_run" -eq 1 ]] && args+=("--dry-run")
      log "Running bootstrap (macos): scripts/bootstrap-macos.sh ${args[*]}"
      run "$repo_root/scripts/bootstrap-macos.sh" "${args[@]}"
    else
      echo "bootstrap-macos.sh not found or not executable" >&2
      exit 1
    fi
    ;;
  *)
    echo "Unknown --bootstrap value: $bootstrap" >&2
    usage
    exit 2
    ;;
esac
