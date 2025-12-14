#------------------------------------------------------------------------------
# mm_bash_profile_doctor: print effective configuration + load surfaces
#
# Safe to source:
# - defines a function + alias only
# - does not run external commands unless the user invokes the function
#------------------------------------------------------------------------------

# shellcheck shell=bash

mm_bash_profile_doctor() {
    local bash_ver="${BASH_VERSION:-unknown}"
    local os
    os="$(uname -s 2>/dev/null || echo 'Unknown')"

    echo "my-mac-bash-profile doctor"
    echo "bash_version=${bash_ver}"
    echo "os=${os}"
    echo "home=${HOME:-}"
    echo "xdg_config_home=${XDG_CONFIG_HOME:-}"
    echo "xdg_cache_home=${XDG_CACHE_HOME:-}"
    echo "xdg_state_home=${XDG_STATE_HOME:-}"
    echo "modules_enable=${BASH_PROFILE_MODULES_ENABLE:-}"
    echo "modules_disable=${BASH_PROFILE_MODULES_DISABLE:-}"
    echo "netinfo_external_ip=${NETINFO_EXTERNAL_IP:-}"

    if [[ -e "$HOME/.bash_profile" || -L "$HOME/.bash_profile" ]]; then
        local target=""
        target="$(readlink "$HOME/.bash_profile" 2>/dev/null || true)"
        echo "bash_profile_path=$HOME/.bash_profile"
        echo "bash_profile_symlink_target=${target:-N/A}"
    fi

    # Surface check: are the main helpers defined?
    local fn
    for fn in sysinfo netinfo extract flushdns jd jdir; do
        if declare -F "$fn" >/dev/null 2>&1; then
            echo "helper_${fn}=present"
        else
            echo "helper_${fn}=missing"
        fi
    done

    # Local override files.
    local repo_local=""
    repo_local="$(dirname "${BASH_SOURCE[0]}")/local.sh"
    if [[ -r "$repo_local" ]]; then
        echo "local_override_repo=present"
    else
        echo "local_override_repo=missing"
    fi

    local xdg_local="${XDG_CONFIG_HOME:-$HOME/.config}/my-mac-bash-profile/local.sh"
    if [[ -r "$xdg_local" ]]; then
        echo "local_override_xdg=present"
    else
        echo "local_override_xdg=missing"
    fi
}

# Convenience alias for people who like kebab-case.
# (Functions with '-' are best avoided for portability.)
alias mm-bash-profile-doctor='mm_bash_profile_doctor'
