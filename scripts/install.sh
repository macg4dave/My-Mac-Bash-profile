#!/usr/bin/env bash
set -euo pipefail

# Conservative installer for this repo.
# Default behavior (safe + repeatable):
# - Copies runtime files into an install directory (default: $HOME/.my-mac-bash-profile)
# - Symlinks the installed .bash_profile to the target (default: $HOME/.bash_profile)
# - Makes a timestamped backup before changing an existing target (unless --no-backup)
# - Idempotent: if already installed, does nothing
# - Runs bootstrap for the current OS by default (disable with --bootstrap none)

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [options]

Options:
  --repo <path>        Path to the repo root (default: auto-detect from this script)
  --install-dir <path> Copy runtime files into this directory, then link the target to it
                      (default: $HOME/.my-mac-bash-profile)
  --link-repo          Do not copy files; link the target directly to the git checkout
  --target <path>      Where to install the symlink (default: $HOME/.bash_profile)
  --dry-run, -n        Print what would change, but do not modify anything
  --no-backup          Do not create backups when replacing an existing target
  --yes, -y            Assume yes for overwrite prompts (non-interactive safe)

Bootstrap:
  --bootstrap <auto|linux|macos|none>   Run bootstrap script after install (default: auto)
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

confirm() {
  # Usage: confirm "message"
  # Returns 0 for yes, 1 for no.
  local msg="$1"
  [[ "${assume_yes}" -eq 1 ]] && return 0
  [[ "${dry_run}" -eq 1 ]] && return 0

  # If we can't prompt (non-interactive), default to "no".
  if [[ ! -t 0 ]]; then
    echo "$msg" >&2
    echo "Refusing to overwrite in non-interactive mode. Re-run with --yes to proceed." >&2
    return 1
  fi

  local reply
  while true; do
    read -r -p "$msg [y/N] " reply
    case "${reply}" in
      [yY]|[yY][eE][sS]) return 0 ;;
      ""|[nN]|[nN][oO]) return 1 ;;
      *) echo "Please answer y or n." >&2 ;;
    esac
  done
}

is_linux() {
  [[ "$(uname -s 2>/dev/null || echo 'Unknown')" != "Darwin" ]]
}

ensure_bashrc_sources_bash_profile() {
  # Fedora and many Linux terminals start interactive shells as non-login shells.
  # Bash reads ~/.bashrc in that case, not ~/.bash_profile.
  #
  # This makes the install more "it just works" by ensuring ~/.bashrc sources
  # ~/.bash_profile (guarded to avoid recursion if users later source ~/.bashrc
  # from ~/.bash_profile).
  local bashrc="${HOME}/.bashrc"
  local begin_marker="# >>> my-mac-bash-profile (source .bash_profile for non-login shells) >>>"
  local end_marker="# <<< my-mac-bash-profile <<<"

  [[ -n "${HOME:-}" ]] || return 0

  if [[ -f "$bashrc" ]] && grep -qF "$begin_marker" "$bashrc" 2>/dev/null; then
    return 0
  fi

  log "Ensuring $bashrc sources $HOME/.bash_profile for interactive non-login shells"

  # Create the file if it doesn't exist.
  run touch "$bashrc"

  if [[ "$dry_run" -eq 1 ]]; then
    log "--- would append to $bashrc ---"
    log "$begin_marker"
    log "# If this terminal starts Bash as a non-login shell (common on Fedora),"
    log "# load the login profile too."
    log "if [[ \$- == *i* ]] && [[ -z \"\${__MMBP_BASHRC_SOURCED_PROFILE:-}\" ]] && [[ -f \"\$HOME/.bash_profile\" ]]; then"
    log "  __MMBP_BASHRC_SOURCED_PROFILE=1"
    log "  # shellcheck source=/dev/null"
    log "  source \"\$HOME/.bash_profile\""
    log "fi"
    log "$end_marker"
    log "--- end ---"
    return 0
  fi

  {
    printf '\n%s\n' "$begin_marker"
    cat <<'EOF'
# If this terminal starts Bash as a non-login shell (common on Fedora),
# load the login profile too.
if [[ $- == *i* ]] && [[ -z "${__MMBP_BASHRC_SOURCED_PROFILE:-}" ]] && [[ -f "$HOME/.bash_profile" ]]; then
  __MMBP_BASHRC_SOURCED_PROFILE=1
  # shellcheck source=/dev/null
  source "$HOME/.bash_profile"
fi
EOF
    printf '%s\n' "$end_marker"
  } >>"$bashrc"
}

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
    if ! confirm "Install dir already exists: $install_dir. Redeploy (overwrite) the installed copy?"; then
      log "Leaving existing install dir in place: $install_dir"
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
  # For non-existing paths, it resolves the parent directory and appends basename.
  local p="$1"
  # Absolute paths: if we can't resolve (e.g., parent doesn't exist during --dry-run),
  # return the absolute path as-is.
  if [[ "$p" == /* ]]; then
    if [[ -d "$p" ]]; then
      (cd -P -- "$p" 2>/dev/null && pwd) && return 0
    fi
    local d b
    d="$(dirname "$p")"
    b="$(basename "$p")"
    if [[ -d "$d" ]]; then
      (cd -P -- "$d" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$b") && return 0
    fi
    printf '%s\n' "$p"
    return 0
  fi

  # Relative paths.
  if [[ -d "$p" ]]; then
    (cd -P -- "$p" 2>/dev/null && pwd) && return 0
  fi
  local d b
  d="$(dirname "$p")"
  b="$(basename "$p")"
  if [[ -d "$d" ]]; then
    (cd -P -- "$d" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$b") && return 0
  fi
  # Last resort: anchor to current working directory.
  (cd -P -- "$(pwd -P)" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$p")
}

# --------
# args
# --------

dry_run=0
backup=1
bootstrap="auto"
full=0
assume_yes=0

repo_root=""
install_dir=""
link_repo=0
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
    --link-repo)
      link_repo=1
      ;;
    --dry-run|-n)
      dry_run=1
      ;;
    --no-backup)
      backup=0
      ;;
    --yes|-y)
      assume_yes=1
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

if [[ "$link_repo" -eq 1 && -n "$install_dir" ]]; then
  echo "--link-repo cannot be combined with --install-dir" >&2
  usage
  exit 2
fi

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

# Default deployment mode: copy runtime files into install_dir and link to that.
# Use --link-repo to preserve the old behavior of linking directly to the checkout.
if [[ "$link_repo" -eq 0 ]]; then
  if [[ -z "$install_dir" ]]; then
    install_dir="$HOME/.my-mac-bash-profile"
  fi
fi

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
    if ! confirm "Target already exists: $target_abs. Replace it?"; then
      echo "Aborted." >&2
      exit 1
    fi
    if [[ "$backup" -eq 1 ]]; then
      bkp="$(unique_backup_path "$target_abs.bak.$(now_stamp)")"
      log "Backing up existing $target_abs -> $bkp"
      run mv "$target_abs" "$bkp"
    else
      run rm -rf "$target_abs"
    fi
  fi

  log "Installing symlink: $target_abs -> $repo_profile_abs"
  run ln -s "$repo_profile_abs" "$target_abs"
fi

# On Linux, ensure non-login shells still load ~/.bash_profile via ~/.bashrc.
if is_linux; then
  ensure_bashrc_sources_bash_profile
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

args=()
case "$bootstrap" in
  none)
    ;;
  linux)
    if [[ -r "$repo_root/scripts/bootstrap-linux.sh" ]]; then
      args=()
      [[ "$full" -eq 1 ]] && args+=("--full")
      [[ "$dry_run" -eq 1 ]] && args+=("--dry-run")
      args_display="${args[*]:-}"
      [[ -n "$args_display" ]] && args_display=" $args_display"
      log "Running bootstrap (linux): scripts/bootstrap-linux.sh${args_display}"
      if ((${#args[@]})); then
        run bash "$repo_root/scripts/bootstrap-linux.sh" "${args[@]}"
      else
        run bash "$repo_root/scripts/bootstrap-linux.sh"
      fi
    else
      echo "bootstrap-linux.sh not found or not readable" >&2
      exit 1
    fi
    ;;
  macos)
    if [[ -r "$repo_root/scripts/bootstrap-macos.sh" ]]; then
      args=()
      [[ "$dry_run" -eq 1 ]] && args+=("--dry-run")
      args_display="${args[*]:-}"
      [[ -n "$args_display" ]] && args_display=" $args_display"
      log "Running bootstrap (macos): scripts/bootstrap-macos.sh${args_display}"
      if ((${#args[@]})); then
        run bash "$repo_root/scripts/bootstrap-macos.sh" "${args[@]}"
      else
        run bash "$repo_root/scripts/bootstrap-macos.sh"
      fi
    else
      echo "bootstrap-macos.sh not found or not readable" >&2
      exit 1
    fi
    ;;
  *)
    echo "Unknown --bootstrap value: $bootstrap" >&2
    usage
    exit 2
    ;;
esac
