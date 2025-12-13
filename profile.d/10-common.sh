#------------------------------------------------------------------------------
# Common cross-platform helpers sourced by .bash_profile
#------------------------------------------------------------------------------

# shellcheck shell=bash

# Return 0 when a command exists in PATH.
has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# OS detection (exported so other modules can gate behavior).
# These are intended to be treated as read-only flags.
if [[ -z "${IS_MAC+x}" || -z "${IS_LINUX+x}" ]]; then
    case "$(uname -s 2>/dev/null)" in
        Darwin)
            export IS_MAC=true
            export IS_LINUX=false
            ;;
        Linux)
            export IS_MAC=false
            export IS_LINUX=true
            ;;
        *)
            export IS_MAC=false
            export IS_LINUX=false
            ;;
    esac
fi

# PATH helpers (safe no-ops when directories don't exist).
path_prepend() {
    local dir="$1"
    [[ -n "$dir" ]] || return 0
    case ":$PATH:" in
        *":$dir:"*) return 0 ;;
    esac
    PATH="$dir:$PATH"
}

path_prepend_if_exists() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    path_prepend "$dir"
}


if [[ $- == *i* ]]; then
    # Optional convenience: run an `ls` after each successful `cd`.
    # Disable by exporting: BASH_PROFILE_CD_LS=0
    if [[ "${BASH_PROFILE_CD_LS:-1}" != "0" ]]; then
        cd() {
            builtin cd "$@" || return
            command ls -hla
        }
    fi
fi
