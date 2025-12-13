#------------------------------------------------------------------------------
# Personal bash profile with macOS & Linux support
#------------------------------------------------------------------------------

# Server details (populate with your own values)
HOST_NAME="${HOST_NAME:-}"
ROUTER_IP="${ROUTER_IP:-}"

NASUSER="${NASUSER:-}"
NAS="${NAS:-}"
NASPORT="${NASPORT:-}"

LAP101USER="${LAP101USER:-}"
LAP101="${LAP101:-}"
LAP101PORT="${LAP101PORT:-}"
LAP101GUI="${LAP101GUI:-}"

BERRYUSER="${BERRYUSER:-}"
BERRY="${BERRY:-}"
BERRYPORT="${BERRYPORT:-}"
BERRYGUI="${BERRYGUI:-}"

TORRENTUSER="${TORRENTUSER:-}"
TORRENT="${TORRENT:-}"
TORRENTPORT="${TORRENTPORT:-}"

SSHUTTLEUSER="${SSHUTTLEUSER:-}"
SSHUTTLEIP="${SSHUTTLEIP:-}"
SSHUTTLEPORT="${SSHUTTLEPORT:-}"

#------------------------------------------------------------------------------
# Helpers
#------------------------------------------------------------------------------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

prepend_path() {
    local dir="$1"
    [[ -d "$dir" ]] || return
    case ":$PATH:" in
        *":$dir:"*) ;;
        *) PATH="$dir:$PATH" ;;
    esac
}

OS_NAME="$(uname -s)"
IS_MAC=false
IS_LINUX=false
case "$OS_NAME" in
    Darwin*) IS_MAC=true ;;
    Linux*) IS_LINUX=true ;;
esac

#------------------------------------------------------------------------------
# PATH & environment
#------------------------------------------------------------------------------
prepend_path "$HOME/bin"
prepend_path "$HOME/.local/bin"
prepend_path "/usr/local/bin"
prepend_path "/usr/local/sbin"
prepend_path "/opt/local/bin"
prepend_path "/opt/local/sbin"

if $IS_MAC; then
    prepend_path "/opt/homebrew/bin"
    prepend_path "/opt/homebrew/sbin"
    prepend_path "/usr/local/opt/cython/bin"
    prepend_path "/usr/local/opt/gettext/bin"
    prepend_path "/usr/local/opt/python@3.11/bin"
    prepend_path "/usr/local/opt/python@3.12/bin"
    prepend_path "/usr/local/opt/icu4c/bin"
    prepend_path "/usr/local/opt/icu4c/sbin"
    export BASH_SILENCE_DEPRECATION_WARNING=1
    export CLICOLOR=1
    export LSCOLORS="ExFxBxDxCxegedabagacad"
else
    prepend_path "/usr/sbin"
    prepend_path "/sbin"
    if has_cmd dircolors; then
        eval "$(dircolors -b 2>/dev/null)" || true
    fi
fi

export PATH

export HISTCONTROL="ignoredups:erasedups"
export HISTSIZE=5000
export HISTFILESIZE=100000
shopt -s histappend
shopt -s checkwinsize
shopt -s nocaseglob
shopt -s cdspell 2>/dev/null || true

#------------------------------------------------------------------------------
# Prompt
#------------------------------------------------------------------------------
__prompt_git() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
    local branch
    branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
    [[ -n "$branch" ]] && printf ' (%s)' "$branch"
}

if [[ $- == *i* ]]; then
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a"
    export PS1="\[\e[36m\]\u\[\e[0m\]@\[\e[35m\]\h\[\e[0m\] [\[\e[33m\]\w\[\e[0m\]]\[\e[32m\]\$(__prompt_git)\[\e[0m\]\n$ "
fi

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------
clock() {
    if ! has_cmd figlet; then
        echo "clock requires figlet (brew install figlet / sudo apt install figlet)" >&2
        return 1
    fi
    while true; do
        $IS_MAC && printf '\e[8;6;38t'
        tput clear
        date +'%H : %M : %S' | figlet -f small
        sleep 1
    done
}

sysinfo() {
    local os kernel uptime load disk ipaddr
    os="$(uname -s)"
    kernel="$(uname -r)"
    uptime="$(uptime -p 2>/dev/null || uptime | sed 's/.*up \([^,]*\), .*/\1/')"
    load="$(uptime | awk -F'load averages?: ' '{print $2}')"
    disk="$(df -h / | awk 'NR==2 {printf \"%s used / %s free (%s)\", $3, $4, $5}')"
    if has_cmd ip; then
        ipaddr="$(ip route get 8.8.8.8 2>/dev/null | awk '/src/ {for (i=1;i<=NF;i++) if ($i==\"src\") {print $(i+1); exit}}')"
    elif has_cmd ifconfig; then
        ipaddr="$(ifconfig | awk '/inet / && $2 != \"127.0.0.1\" {print $2; exit}')"
    else
        ipaddr="n/a"
    fi
    printf "Host   : %s\n" "$(hostname)"
    printf "OS     : %s %s\n" "$os" "$kernel"
    printf "Uptime : %s\n" "$uptime"
    printf "Load   : %s\n" "$load"
    printf "Disk   : %s\n" "$disk"
    printf "IP     : %s\n" "${ipaddr:-n/a}"
}

$IS_MAC && alias macinfo='sysinfo'

gosu() {
    if ! $IS_MAC; then
        echo "gosu is only available on macOS." >&2
        return 1
    fi
    if ! has_cmd osascript; then
        echo "osascript is required for gosu." >&2
        return 1
    fi
    /usr/bin/osascript <<'EOT'
tell application "Terminal"
    set newTab to do script "sudo -s"
    set theWindow to first window of (every window whose tabs contains newTab)
    repeat with i from 1 to (count of theWindow's tabs)
        if (item i of theWindow's tabs) is newTab then set tabNumber to i
    end repeat
    set current settings of newTab to settings set "Red Sands"
end tell
EOT
}

extract() {
    local archive="$1"
    if [[ -z "$archive" || ! -f "$archive" ]]; then
        echo "Usage: extract <archive>" >&2
        return 1
    fi
    case "$archive" in
        *.tar.bz2)   tar xjf "$archive" ;;
        *.tar.gz)    tar xzf "$archive" ;;
        *.tbz2)      tar xjf "$archive" ;;
        *.tgz)       tar xzf "$archive" ;;
        *.tar)       tar xf "$archive"  ;;
        *.bz2)       bunzip2 "$archive" ;;
        *.gz)        gunzip "$archive"  ;;
        *.rar)       unrar e "$archive" ;;
        *.zip)       unzip "$archive"   ;;
        *.Z)         uncompress "$archive" ;;
        *.7z)        7z x "$archive"    ;;
        *)           echo "Cannot extract '$archive'" >&2; return 1 ;;
    esac
}

cd() {
    builtin cd "$@" || return
    ls -hla
}

cdf() {
    if ! $IS_MAC; then
        echo "cdf is only available on macOS." >&2
        return 1
    fi
    if ! has_cmd osascript; then
        echo "osascript is required for cdf." >&2
        return 1
    fi
    local currFolderPath
    currFolderPath=$(/usr/bin/osascript <<'EOT'
tell application "Finder"
    try
        set currFolder to (folder of the front window as alias)
    on error
        set currFolder to (path to desktop folder as alias)
    end try
    POSIX path of currFolder
end tell
EOT
)
    echo "cd to \"$currFolderPath\""
    cd "$currFolderPath"
}

gohome() {
    if ! has_cmd sshuttle; then
        echo "sshuttle is not installed." >&2
        return 1
    fi
    if [[ -z "$SSHUTTLEUSER" || -z "$SSHUTTLEIP" || -z "$SSHUTTLEPORT" ]]; then
        echo "Set SSHUTTLEUSER, SSHUTTLEIP, and SSHUTTLEPORT first." >&2
        return 1
    fi
    sshuttle --no-latency-control --dns -N --remote "$SSHUTTLEUSER@$SSHUTTLEIP:$SSHUTTLEPORT" 0/0
}

stophome() {
    local pattern="sshuttle.*$SSHUTTLEIP"
    if pkill -f "$pattern" 2>/dev/null; then
        echo "Disconnected"
    else
        echo "sshuttle is not running for $SSHUTTLEIP" >&2
        return 1
    fi
}

make_ssh() {
    local ssh_user="$1"
    local ssh_ip="$2"
    local ssh_port="$3"
    local gui_flag="$4"

    if [[ -z "$ssh_user" || -z "$ssh_ip" ]]; then
        echo "Usage: make_ssh <user> <ip> [port] [additional ssh flags]" >&2
        return 1
    fi

    local remote_host="$ssh_ip"
    local current_gateway=""
    if [[ -n "$ROUTER_IP" ]]; then
        if $IS_MAC && has_cmd networksetup; then
            current_gateway="$(networksetup -getinfo Wi-Fi 2>/dev/null | awk 'NR==4 {print $2}')"
        elif has_cmd ip; then
            current_gateway="$(ip route | awk '/default/ {print $3; exit}')"
        fi
    fi

    if [[ -n "$HOST_NAME" && -n "$current_gateway" && "$current_gateway" != "$ROUTER_IP" ]]; then
        remote_host="$HOST_NAME"
    fi

    local ssh_cmd=("ssh")
    [[ -n "$gui_flag" ]] && ssh_cmd+=("$gui_flag")
    [[ -n "$ssh_port" ]] && ssh_cmd+=("-p" "$ssh_port")
    ssh_cmd+=("$ssh_user@$remote_host")
    "${ssh_cmd[@]}"
}

#------------------------------------------------------------------------------
# Aliases
#------------------------------------------------------------------------------
if $IS_MAC; then
    alias ls='ls -GFhla'
    alias flushDNS='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
else
    alias ls='ls -AFhla --color=auto'
    if has_cmd resolvectl; then
        alias flushDNS='sudo resolvectl flush-caches'
    else
        alias flushDNS='echo "Use sudo systemd-resolve --flush-caches"'
    fi
fi

alias ll='ls -lha'
alias la='ls -A'
alias jdir='wget -r -c --no-parent '
alias jd='wget -c '
alias checkip='curl -s https://ipinfo.io'
alias reloadprofile='source ~/.bash_profile'
alias topcpu='ps aux | sort -nrk 3,3 | head -n 10'

alias mynas='make_ssh "$NASUSER" "$NAS" "$NASPORT"'
alias myberry='make_ssh "$BERRYUSER" "$BERRY" "$BERRYPORT" "$BERRYGUI"'
alias lintop101='make_ssh "$LAP101USER" "$LAP101" "$LAP101PORT" "$LAP101GUI"'
alias torrentbox='make_ssh "$TORRENTUSER" "$TORRENT" "$TORRENTPORT"'

alias startx11='exec startxfce4 --disable-wm-check'

#------------------------------------------------------------------------------
# END
#------------------------------------------------------------------------------
