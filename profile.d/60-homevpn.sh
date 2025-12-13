#------------------------------------------------------------------------------
# Home/VPN helpers: gohome/stophome (sshuttle) + make_ssh (SSH config helper)
#------------------------------------------------------------------------------

# shellcheck shell=bash

if ! declare -F has_cmd >/dev/null 2>&1; then
    has_cmd() { command -v "$1" >/dev/null 2>&1; }
fi

_mbp_cache_dir() {
    echo "${XDG_CACHE_HOME:-$HOME/.cache}/my-mac-bash-profile"
}

_gohome_pidfile() {
    local cache_dir
    cache_dir="$(_mbp_cache_dir)"
    echo "${GOHOME_PID_FILE:-$cache_dir/gohome-sshuttle.pid}"
}

gohome() {
    if ! has_cmd sshuttle; then
        echo "sshuttle is required for gohome (install it, then try again)." >&2
        return 1
    fi

    local remote subnets port key extra pidfile
    remote="${GOHOME_REMOTE:-}"
    subnets="${GOHOME_SUBNETS:-}"
    port="${GOHOME_SSH_PORT:-}"
    key="${GOHOME_SSH_KEY:-}"
    extra="${GOHOME_SSHUTTLE_ARGS:-}"
    pidfile="$(_gohome_pidfile)"

    if [[ -z "$remote" || -z "$subnets" ]]; then
        echo "Usage: gohome (configure GOHOME_REMOTE and GOHOME_SUBNETS env vars)" >&2
        echo "  GOHOME_REMOTE   example: user@bastion.example.com" >&2
        echo "  GOHOME_SUBNETS  example: '10.0.0.0/8 192.168.0.0/16'" >&2
        return 2
    fi

    mkdir -p "$(dirname -- "$pidfile")" 2>/dev/null || true

    local args=(--daemon --pidfile "$pidfile")
    [[ "${GOHOME_DNS:-0}" == "1" ]] && args+=(--dns)
    [[ -n "$port" ]] && args+=(-r "$remote:$port") || args+=(-r "$remote")
    [[ -n "$key" ]] && args+=(--ssh-cmd "ssh -i $key")

    # shellcheck disable=SC2206
    [[ -n "$extra" ]] && args+=($extra)

    # shellcheck disable=SC2206
    args+=($subnets)

    echo "Starting sshuttle to '$remote' for: $subnets" >&2
    echo "PID file: $pidfile" >&2

    if [[ "${GOHOME_SUDO:-1}" == "1" ]]; then
        sudo sshuttle "${args[@]}"
    else
        sshuttle "${args[@]}"
    fi
}

stophome() {
    local pidfile pid
    pidfile="$(_gohome_pidfile)"
    if [[ ! -r "$pidfile" ]]; then
        echo "No pidfile found at: $pidfile" >&2
        return 1
    fi
    pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -z "$pid" ]]; then
        echo "Pidfile is empty: $pidfile" >&2
        return 1
    fi

    echo "Stopping sshuttle pid $pid" >&2
    if [[ "${GOHOME_SUDO:-1}" == "1" ]]; then
        sudo kill "$pid" 2>/dev/null || true
    else
        kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pidfile" 2>/dev/null || true
}

make_ssh() {
    local dry_run=false force=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run) dry_run=true ;;
            -f|--force) force=true ;;
            -h|--help)
                echo "Usage: make_ssh [--dry-run] [--force] <alias> <hostname> [user] [port] [identity_file]" >&2
                return 0
                ;;
            *) break ;;
        esac
        shift
    done

    local alias host user port key
    alias="${1:-}"
    host="${2:-}"
    user="${3:-}"
    port="${4:-}"
    key="${5:-}"

    if [[ -z "$alias" || -z "$host" ]]; then
        echo "Usage: make_ssh [--dry-run] [--force] <alias> <hostname> [user] [port] [identity_file]" >&2
        return 2
    fi

    local ssh_dir cfg
    ssh_dir="$HOME/.ssh"
    cfg="$ssh_dir/config"

    mkdir -p "$ssh_dir" || return 1
    chmod 700 "$ssh_dir" 2>/dev/null || true
    [[ -e "$cfg" ]] || : > "$cfg"
    chmod 600 "$cfg" 2>/dev/null || true

    if ! $force && awk -v a="$alias" '$1=="Host" && $2==a {found=1} END{exit found?0:1}' "$cfg" 2>/dev/null; then
        echo "Host '$alias' already exists in $cfg (use --force to append anyway)." >&2
        return 1
    fi

    local stanza
    stanza="Host $alias\n  HostName $host\n"
    [[ -n "$user" ]] && stanza+="  User $user\n"
    [[ -n "$port" ]] && stanza+="  Port $port\n"
    [[ -n "$key" ]] && stanza+="  IdentityFile $key\n"
    stanza+="  IdentitiesOnly yes\n"

    if $dry_run; then
        printf "%b" "$stanza"
        return 0
    fi

    # Append safely with restrictive umask.
    ( umask 077; printf "\n# Added by make_ssh (%s)\n%b" "$(date -Is 2>/dev/null || date)" "$stanza" >> "$cfg" )
    echo "Wrote SSH host '$alias' to $cfg" >&2
}
