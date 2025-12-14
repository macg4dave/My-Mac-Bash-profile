#!/usr/bin/env bash

# This file is intended to be *sourceable* by `.bash_profile` (to provide a
# `sysinfo` helper) and also runnable directly (`./sysinfo.sh`).
#
# IMPORTANT: do not auto-run on source.

# shellcheck shell=bash

_sysinfo_has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# User and system information variables
which_os="1"  # 1 for macOS, 2 for Linux
os_name=""
os_ver=""
net_int_mac="en0"  # Default network interface for macOS
net_int_linux="eth0"  # Default network interface for Linux

startup_name="N/A"
startup_size="N/A"
startup_used="N/A"
startup_free="N/A"

uptime_time="N/A"
uptime_load="N/A"

cpu_used_user="N/A"
cpu_used_sys="N/A"
cpu_used_idle="N/A"

network_down="N/A"
network_up="N/A"

ram_total="N/A"
ram_used="N/A"
ram_free="N/A"

# Function to detect the operating system (macOS or Linux)
find_os() {
    os_name="$(uname 2>/dev/null || echo 'Unknown')"
    case "$os_name" in
        Darwin)
            which_os="1"
            if _sysinfo_has_cmd sw_vers; then
                os_ver="$(sw_vers -productVersion 2>/dev/null || echo 'N/A')"  # Get macOS version
            else
                os_ver="N/A"
            fi
            ;;
        Linux)
            which_os="2"
            os_ver="$(uname -r 2>/dev/null || echo 'N/A')"  # Get Linux kernel version
            ;;
        *)
            echo "Unsupported OS" >&2
            return 1
            ;;
    esac
}

# Convert bytes to a human-readable string when possible.
human_bytes() {
    local bytes="$1"
    if [[ -z "$bytes" || "$bytes" == "0" ]]; then
        echo "0B"
        return 0
    fi
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec --suffix=B --format="%.2f" "$bytes"
    else
        echo "${bytes}B"
    fi
}

# Function to convert bytes to MB/s using numfmt for a human-readable format
convert_to_mbps() {
    local v="$1"
    if [[ -z "$v" || "$v" == "0" ]]; then
        echo "N/A"
    else
        if command -v numfmt >/dev/null 2>&1; then
            numfmt --to=iec --suffix=B --format="%.2f" "$v"
        else
            # macOS may not have `numfmt` unless coreutils is installed.
            echo "${v}B"
        fi
    fi
}

# macOS-specific function to get RAM information
mac_get_ram() {
    local total_bytes page_size
    if ! _sysinfo_has_cmd sysctl || ! _sysinfo_has_cmd vm_stat; then
        ram_total="N/A"
        ram_used="N/A"
        ram_free="N/A"
        return 0
    fi

    total_bytes="$(sysctl -n hw.memsize 2>/dev/null || echo '')"
    page_size="$(vm_stat 2>/dev/null | awk '/page size of/ {gsub("[^0-9]","",$0); print $0; exit}')"

    if [[ -z "$total_bytes" || -z "$page_size" ]]; then
        ram_total="N/A"
        ram_used="N/A"
        ram_free="N/A"
        return 0
    fi

    # vm_stat reports page counts with trailing periods.
    local free speculative active inactive wired compressed
    free="$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub("\\.","",$3); print $3; exit}')"
    speculative="$(vm_stat 2>/dev/null | awk '/Pages speculative/ {gsub("\\.","",$3); print $3; exit}')"
    active="$(vm_stat 2>/dev/null | awk '/Pages active/ {gsub("\\.","",$3); print $3; exit}')"
    inactive="$(vm_stat 2>/dev/null | awk '/Pages inactive/ {gsub("\\.","",$3); print $3; exit}')"
    wired="$(vm_stat 2>/dev/null | awk '/Pages wired down/ {gsub("\\.","",$4); print $4; exit}')"
    compressed="$(vm_stat 2>/dev/null | awk '/Pages occupied by compressor/ {gsub("\\.","",$5); print $5; exit}')"

    free="${free:-0}"
    speculative="${speculative:-0}"
    active="${active:-0}"
    inactive="${inactive:-0}"
    wired="${wired:-0}"
    compressed="${compressed:-0}"

    local free_pages used_pages free_bytes used_bytes
    free_pages=$((free + speculative))
    used_pages=$((active + inactive + wired + compressed))
    free_bytes=$((free_pages * page_size))
    used_bytes=$((used_pages * page_size))

    ram_total="$(human_bytes "$total_bytes")"
    ram_used="$(human_bytes "$used_bytes")"
    ram_free="$(human_bytes "$free_bytes")"
}

# Linux-specific function to get RAM information
linux_get_ram() {
    local total_kb avail_kb
    if [[ -r /proc/meminfo ]]; then
        total_kb="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null)"
        avail_kb="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null)"
    fi

    if [[ -z "$total_kb" || -z "$avail_kb" ]]; then
        if command -v free >/dev/null 2>&1; then
            # Fallback: best-effort using `free -b`
            local total_b avail_b
            total_b="$(free -b 2>/dev/null | awk '/^Mem:/ {print $2; exit}')"
            avail_b="$(free -b 2>/dev/null | awk '/^Mem:/ {print $7; exit}')"
            if [[ -n "$total_b" && -n "$avail_b" ]]; then
                ram_total="$(human_bytes "$total_b")"
                ram_free="$(human_bytes "$avail_b")"
                ram_used="$(human_bytes $((total_b - avail_b)))"
                return 0
            fi
        fi
        ram_total="N/A"
        ram_used="N/A"
        ram_free="N/A"
        return 0
    fi

    local total_b avail_b
    total_b=$((total_kb * 1024))
    avail_b=$((avail_kb * 1024))
    ram_total="$(human_bytes "$total_b")"
    ram_free="$(human_bytes "$avail_b")"
    ram_used="$(human_bytes $((total_b - avail_b)))"
}

# macOS-specific function to get disk information
mac_disk_info() {
    # Store the entire diskutil info output into a variable
    if ! command -v diskutil >/dev/null 2>&1; then
        startup_name="N/A"
        startup_size="N/A"
        startup_free="N/A"
        startup_used="N/A"
        return 0
    fi

    local disk_info
    disk_info="$(diskutil info / 2>/dev/null || echo '')"

    # Get startup disk name and size information
    if _sysinfo_has_cmd osascript; then
        startup_name="$(osascript -e 'tell app "Finder" to get name of startup disk' 2>/dev/null || echo 'N/A')"
    else
        startup_name="N/A"
    fi
    startup_size="$(printf "%s\n" "$disk_info" | grep "Container Total Space:" | awk '{print $4, $5}' 2>/dev/null || echo 'N/A')"
    startup_free="$(printf "%s\n" "$disk_info" | grep "Container Free Space:" | awk '{print $4, $5}' 2>/dev/null || echo 'N/A')"

    # Extract numeric values and remove 'B' suffix for processing
    local size_value size_unit free_value free_unit
    size_value="$(echo "$startup_size" | awk '{gsub("B", "", $2); print $1}' 2>/dev/null)"
    size_unit="$(echo "$startup_size" | awk '{gsub("B", "", $2); print $2}' 2>/dev/null)"

    free_value="$(echo "$startup_free" | awk '{gsub("B", "", $2); print $1}' 2>/dev/null)"
    free_unit="$(echo "$startup_free" | awk '{gsub("B", "", $2); print $2}' 2>/dev/null)"

    if command -v numfmt >/dev/null 2>&1 && [[ -n "$size_value" && -n "$size_unit" && -n "$free_value" && -n "$free_unit" ]]; then
        # Convert sizes to bytes for calculation
        local size_in_bytes free_in_bytes used_in_bytes
        size_in_bytes="$(numfmt --from=iec "$size_value$size_unit" 2>/dev/null || echo '')"
        free_in_bytes="$(numfmt --from=iec "$free_value$free_unit" 2>/dev/null || echo '')"

        if [[ -n "$size_in_bytes" && -n "$free_in_bytes" ]]; then
            # Calculate used space in bytes and convert it to a human-readable format
            used_in_bytes=$((size_in_bytes - free_in_bytes))
            startup_used="$(numfmt --to=iec --suffix=B "$used_in_bytes" 2>/dev/null || echo 'N/A')"
        else
            startup_used="N/A"
        fi
    else
        startup_used="N/A"
    fi
}

# macOS-specific function to get network information
mac_get_network() {
    if ! _sysinfo_has_cmd ifconfig || ! _sysinfo_has_cmd netstat; then
        network_down="N/A"
        network_up="N/A"
        return 0
    fi

    local ifconfig_output
    ifconfig_output="$(ifconfig "$net_int_mac" 2>/dev/null || echo 'N/A')"
    
    if [[ "$ifconfig_output" == "N/A" ]]; then
        network_down="N/A"
        network_up="N/A"
    else
        # Get network data (bytes sent/received) for the given network interface
        network_down="$(netstat -ib 2>/dev/null | grep "$net_int_mac" | awk '{print $7}' | head -n 1 2>/dev/null || echo 'N/A')"
        network_up="$(netstat -ib 2>/dev/null | grep "$net_int_mac" | awk '{print $10}' | head -n 1 2>/dev/null || echo 'N/A')"
        
        # Convert the byte counts to MB/s
        network_down=$(convert_to_mbps "$network_down")
        network_up=$(convert_to_mbps "$network_up")
    fi
}

# macOS-specific function to get CPU usage
mac_get_cpu() {
    if ! _sysinfo_has_cmd top; then
        cpu_used_user="N/A"
        cpu_used_sys="N/A"
        cpu_used_idle="N/A"
        return 0
    fi

    local top_out
    top_out="$(top -l 1 2>/dev/null | grep "CPU usage" | head -n 1 2>/dev/null || echo '')"
    if [[ -z "$top_out" ]]; then
        cpu_used_user="N/A"
        cpu_used_sys="N/A"
        cpu_used_idle="N/A"
        return 0
    fi

    # Normalize to numeric values without the % sign.
    cpu_used_user="$(printf '%s\n' "$top_out" | awk '{print $3}' | tr -d '%' 2>/dev/null || echo 'N/A')"
    cpu_used_sys="$(printf '%s\n' "$top_out" | awk '{print $5}' | tr -d '%' 2>/dev/null || echo 'N/A')"
    cpu_used_idle="$(printf '%s\n' "$top_out" | awk '{print $7}' | tr -d '%' 2>/dev/null || echo 'N/A')"
}

# macOS-specific function to get uptime information
mac_get_uptime() {
    if ! _sysinfo_has_cmd uptime; then
        uptime_time="N/A"
        uptime_load="N/A"
        return 0
    fi
    uptime_time="$(uptime 2>/dev/null | awk -F', ' '{print $1}' | sed 's/.*up //' 2>/dev/null || echo 'N/A')"
    uptime_load="$(uptime 2>/dev/null | awk '{print $10, $11, $12}' 2>/dev/null || echo 'N/A')"
}

# Linux-specific function to get disk information
linux_disk_info() {
    startup_name="/"
    if ! _sysinfo_has_cmd df; then
        startup_size="N/A"
        startup_used="N/A"
        startup_free="N/A"
        return 0
    fi
    startup_size="$(df -h / 2>/dev/null | awk 'NR==2 {print $2}' 2>/dev/null || echo 'N/A')"
    startup_used="$(df -h / 2>/dev/null | awk 'NR==2 {print $3}' 2>/dev/null || echo 'N/A')"
    startup_free="$(df -h / 2>/dev/null | awk 'NR==2 {print $4}' 2>/dev/null || echo 'N/A')"
}

# Linux-specific function to get network information
linux_get_network() {
    if [[ ! -r /proc/net/dev ]]; then
        network_down="N/A"
        network_up="N/A"
        return 0
    fi

    # Ensure we have a valid interface present in /proc/net/dev.
    if [[ -z "${net_int_linux:-}" ]] || ! awk -v iface="$net_int_linux" 'BEGIN{ok=0} NR>2 && $1==iface":"{ok=1} END{exit ok?0:1}' /proc/net/dev 2>/dev/null; then
        net_int_linux="$(awk 'NR>2 {gsub(":","",$1); if ($1 != "lo") {print $1; exit}}' /proc/net/dev 2>/dev/null || echo '')"
    fi

    if [[ -z "${net_int_linux:-}" ]]; then
        network_down="N/A"
        network_up="N/A"
        return 0
    fi

    network_down="$(awk -v iface="$net_int_linux" 'NR>2 && $1==iface":" {print $2; exit}' /proc/net/dev 2>/dev/null || echo 'N/A')"
    network_up="$(awk -v iface="$net_int_linux" 'NR>2 && $1==iface":" {print $10; exit}' /proc/net/dev 2>/dev/null || echo 'N/A')"

    # Convert the byte counts to MB/s
    network_down=$(convert_to_mbps "$network_down")
    network_up=$(convert_to_mbps "$network_up")
}

# Linux-specific function to get CPU usage
linux_get_cpu() {
    if [[ ! -r /proc/stat ]]; then
        cpu_used_user="N/A"
        cpu_used_sys="N/A"
        cpu_used_idle="N/A"
        return 0
    fi

    local cpu_stat cpu_user cpu_sys cpu_idle total
    cpu_stat="$(grep 'cpu ' /proc/stat 2>/dev/null || echo '')"
    [[ -n "$cpu_stat" ]] || cpu_stat=""

    # Parse CPU usage from /proc/stat
    cpu_user="$(echo "$cpu_stat" | awk '{print $2}' 2>/dev/null)"
    cpu_sys="$(echo "$cpu_stat" | awk '{print $4}' 2>/dev/null)"
    cpu_idle="$(echo "$cpu_stat" | awk '{print $5}' 2>/dev/null)"

    if [[ -z "$cpu_user" || -z "$cpu_sys" || -z "$cpu_idle" ]]; then
        cpu_used_user="N/A"
        cpu_used_sys="N/A"
        cpu_used_idle="N/A"
        return 0
    fi

    total=$((cpu_user + cpu_sys + cpu_idle))
    
    if [[ $total -ne 0 ]]; then
        cpu_used_user=$((100 * cpu_user / total))
        cpu_used_sys=$((100 * cpu_sys / total))
        cpu_used_idle=$((100 * cpu_idle / total))
    else
        cpu_used_user="N/A"
        cpu_used_sys="N/A"
        cpu_used_idle="N/A"
    fi
}

# Linux-specific function to get uptime information
linux_get_uptime() {
    if ! _sysinfo_has_cmd uptime; then
        uptime_time="N/A"
        uptime_load="N/A"
        return 0
    fi
    uptime_time="$(uptime -p 2>/dev/null || echo 'N/A')"
    uptime_load="$(uptime 2>/dev/null | awk -F'load average: ' '{print $2}' 2>/dev/null || echo 'N/A')"
}

# Function to detect the primary network interface for Linux
detect_primary_interface() {
    local iface=""
    if _sysinfo_has_cmd ip; then
        iface="$(ip route 2>/dev/null | awk '/^default/ {print $5; exit}' 2>/dev/null || echo '')"
    fi
    # Fallback for restricted environments where `ip` can't query netlink.
    if [[ -z "$iface" && -r /proc/net/route ]]; then
        iface="$(awk '$2 == "00000000" {print $1; exit}' /proc/net/route 2>/dev/null || echo '')"
    fi
    net_int_linux="${iface:-eth0}"
}

# Terminal UI helpers (tput/terminfo-backed).
_sysinfo_is_tty() {
    [[ -t 1 ]]
}

_sysinfo_tput() {
    # Best-effort: emit nothing if terminfo/capability isn't available.
    _sysinfo_has_cmd tput || return 1
    [[ "${TERM:-}" != "dumb" ]] || return 1
    tput "$@" 2>/dev/null || return 1
}

_sysinfo_supports_utf8() {
    local loc="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
    [[ "$loc" =~ [Uu][Tt][Ff]-?8 ]]
}

# Style variables set by _sysinfo_style_init().
_SYSINFO_SGR_RESET=""
_SYSINFO_SGR_TITLE=""
_SYSINFO_SGR_LABEL=""
_SYSINFO_SGR_VALUE=""
_SYSINFO_SGR_BORDER=""
_SYSINFO_SGR_SUBLABEL=""
_SYSINFO_SGR_USED=""
_SYSINFO_SGR_FREE=""
_SYSINFO_SGR_MUTED=""
_SYSINFO_SGR_ROW_BG1=""
_SYSINFO_SGR_ROW_BG2=""

_sysinfo_tput_colors() {
    local c
    c="$(_sysinfo_tput colors || echo 0)"
    [[ "$c" =~ ^[0-9]+$ ]] || c=0
    echo "$c"
}

_sysinfo_style_init() {
    local use_colour="${1:-1}"

    _SYSINFO_SGR_RESET=""
    _SYSINFO_SGR_TITLE=""
    _SYSINFO_SGR_LABEL=""
    _SYSINFO_SGR_VALUE=""
    _SYSINFO_SGR_BORDER=""
    _SYSINFO_SGR_SUBLABEL=""
    _SYSINFO_SGR_USED=""
    _SYSINFO_SGR_FREE=""
    _SYSINFO_SGR_MUTED=""
    _SYSINFO_SGR_ROW_BG1=""
    _SYSINFO_SGR_ROW_BG2=""

    [[ "$use_colour" == "1" ]] || return 0
    _sysinfo_is_tty || return 0

    local reset bold dim colors
    reset="$(_sysinfo_tput sgr0 || true)"
    bold="$(_sysinfo_tput bold || true)"
    dim="$(_sysinfo_tput dim || true)"
    colors="$(_sysinfo_tput_colors)"

    _SYSINFO_SGR_RESET="$reset"
    if [[ "$colors" -ge 256 ]]; then
        _SYSINFO_SGR_TITLE="${bold}$(_sysinfo_tput setaf 231 || true)$(_sysinfo_tput setab 24 || true)"
        _SYSINFO_SGR_LABEL="${bold}$(_sysinfo_tput setaf 220 || true)"
        _SYSINFO_SGR_VALUE="$(_sysinfo_tput setaf 81 || true)"
        _SYSINFO_SGR_SUBLABEL="${dim}$(_sysinfo_tput setaf 250 || true)"
        _SYSINFO_SGR_USED="$(_sysinfo_tput setaf 209 || true)"
        _SYSINFO_SGR_FREE="$(_sysinfo_tput setaf 114 || true)"
        _SYSINFO_SGR_MUTED="${dim}$(_sysinfo_tput setaf 245 || true)"
        _SYSINFO_SGR_BORDER="${dim}$(_sysinfo_tput setaf 33 || true)"
        _SYSINFO_SGR_ROW_BG1="$(_sysinfo_tput setab 236 || true)"
        _SYSINFO_SGR_ROW_BG2="$(_sysinfo_tput setab 235 || true)"
    else
        local smso
        smso="$(_sysinfo_tput smso || true)"
        _SYSINFO_SGR_TITLE="${bold}${smso}$(_sysinfo_tput setaf 6 || true)"
        _SYSINFO_SGR_LABEL="${bold}$(_sysinfo_tput setaf 3 || true)"
        _SYSINFO_SGR_VALUE="$(_sysinfo_tput setaf 6 || true)"
        _SYSINFO_SGR_SUBLABEL="${dim}$(_sysinfo_tput setaf 7 || true)"
        _SYSINFO_SGR_USED="$(_sysinfo_tput setaf 3 || true)"
        _SYSINFO_SGR_FREE="$(_sysinfo_tput setaf 2 || true)"
        _SYSINFO_SGR_MUTED="${dim}$(_sysinfo_tput setaf 7 || true)"
        _SYSINFO_SGR_BORDER="${dim}$(_sysinfo_tput setaf 4 || true)"
        _SYSINFO_SGR_ROW_BG1="$smso"
        _SYSINFO_SGR_ROW_BG2=""
    fi
}

# Function to add colors and format the text output
_sysinfo_term_cols() {
    local cols=""
    if [[ -n "${COLUMNS:-}" && "${COLUMNS:-}" =~ ^[0-9]+$ && "${COLUMNS:-}" -gt 0 ]]; then
        cols="$COLUMNS"
    elif [[ -t 1 ]] && _sysinfo_has_cmd tput; then
        cols="$(tput cols 2>/dev/null || echo 80)"
    else
        cols="80"
    fi
    [[ "$cols" =~ ^[0-9]+$ ]] || cols="80"
    echo "$cols"
}

_sysinfo_visible_len() {
    # Length excluding common ANSI SGR sequences.
    printf '%s' "$1" | awk '{gsub(/\033\[[0-9;]*[A-Za-z]/,""); print length($0)}'
}

_sysinfo_fmt_uptime_short() {
    local s="$1"
    s="${s#up }"
    if [[ "$s" =~ ^([0-9]+)[[:space:]]+days?,[[:space:]]*([0-9]+):([0-9]{2})$ ]]; then
        printf '%sd %sh%sm' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
        return 0
    fi
    if [[ "$s" =~ ^([0-9]+):([0-9]{2})$ ]]; then
        printf '%sh%sm' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        return 0
    fi

    # Best-effort normalization for strings like:
    # - "11 hours, 35 minutes"
    # - "1 day, 2 hours, 3 minutes"
    printf '%s' "$s" | sed -E \
        -e 's/,//g' \
        -e 's/[[:space:]]+days?/d/g' \
        -e 's/[[:space:]]+hours?/h/g' \
        -e 's/[[:space:]]+minutes?/m/g' \
        -e 's/[[:space:]]+secs?/s/g' \
        -e 's/[[:space:]]+/ /g' \
        -e 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

_sysinfo_repeat() {
    local ch="$1" count="$2"
    local i
    for ((i = 0; i < count; i++)); do
        printf '%s' "$ch"
    done
}

_sysinfo_spaces() {
    local count="$1"
    [[ "$count" -gt 0 ]] || count=0
    printf '%*s' "$count" ""
}

_sysinfo_pad_right() {
    local text="$1" width="$2"
    local vis pad
    vis="$(_sysinfo_visible_len "$text")"
    pad=$((width - vis))
    [[ "$pad" -gt 0 ]] || pad=0
    printf '%s%*s' "$text" "$pad" ""
}

_sysinfo_box_row_bg() {
    local idx="$1"
    if (( idx % 2 == 0 )); then
        printf '%s' "${_SYSINFO_SGR_ROW_BG1}"
    else
        printf '%s' "${_SYSINFO_SGR_ROW_BG2}"
    fi
}

_sysinfo_box_span() {
    local row_bg="$1" sgr="$2" text="$3"
    printf '%s%s%s%s' "${_SYSINFO_SGR_RESET}" "${row_bg}" "${sgr}" "${text}"
}

_sysinfo_box_fmt_pair() {
    local row_bg="$1" k="$2" v="$3"
    [[ -n "$v" ]] || v="N/A"
    printf '%s%s%s' \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "${k} ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "$v")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "")"
}

_sysinfo_box_fmt_used_total_free() {
    local row_bg="$1" used="$2" total="$3" free="$4"
    [[ -n "$used" ]] || used="N/A"
    [[ -n "$total" ]] || total="N/A"
    [[ -n "$free" ]] || free="N/A"
    printf '%s%s%s%s%s%s%s%s%s' \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "Used ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_USED" "$used")" \
        "$(_sysinfo_box_span "$row_bg" "" "  ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "Total ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "$total")" \
        "$(_sysinfo_box_span "$row_bg" "" "  ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "Free ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_FREE" "$free")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "")"
}

_sysinfo_box_fmt_cpu() {
    local row_bg="$1" u="$2" s="$3" i="$4"
    [[ -n "$u" ]] || u="N/A"
    [[ -n "$s" ]] || s="N/A"
    [[ -n "$i" ]] || i="N/A"
    printf '%s%s%s%s%s%s%s%s%s' \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "User ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_USED" "${u}%")" \
        "$(_sysinfo_box_span "$row_bg" "" "  ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "Sys ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_USED" "${s}%")" \
        "$(_sysinfo_box_span "$row_bg" "" "  ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "Idle ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_FREE" "${i}%")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "")"
}

_sysinfo_box_fmt_net() {
    local row_bg="$1" rx="$2" tx="$3"
    [[ -n "$rx" ]] || rx="N/A"
    [[ -n "$tx" ]] || tx="N/A"
    printf '%s%s%s%s%s%s' \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "RX ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_FREE" "$rx")" \
        "$(_sysinfo_box_span "$row_bg" "" "  ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "TX ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_USED" "$tx")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "")"
}

_sysinfo_box_fmt_load() {
    local row_bg="$1" raw="$2"
    local a b c
    a="$(printf '%s' "$raw" | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')"
    b="$(printf '%s' "$raw" | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')"
    c="$(printf '%s' "$raw" | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')"
    [[ -n "$a" ]] || a="N/A"
    [[ -n "$b" ]] || b="N/A"
    [[ -n "$c" ]] || c="N/A"
    printf '%s%s%s%s%s%s%s%s%s' \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "1m ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "$a")" \
        "$(_sysinfo_box_span "$row_bg" "" "  ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "5m ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "$b")" \
        "$(_sysinfo_box_span "$row_bg" "" "  ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_SUBLABEL" "15m ")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "$c")" \
        "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "")"
}

_sysinfo_box_print_row() {
    local row_bg="$1" label="$2" value="$3" label_w="$4" value_w="$5" v_border="$6"
    local label_pad

    label_pad=$((label_w - ${#label}))
    [[ "$label_pad" -ge 0 ]] || label_pad=0

    local vis pad
    vis="$(_sysinfo_visible_len "$value")"
    pad=$((value_w - vis))
    [[ "$pad" -ge 0 ]] || pad=0

    # Left border (no row background).
    printf '%s' "${_SYSINFO_SGR_BORDER}${v_border}${_SYSINFO_SGR_RESET}"

    # Interior (with row background).
    printf '%s' "$(_sysinfo_box_span "$row_bg" "" " ")"
    printf '%s' "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_LABEL" "$label")"
    printf '%s' "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "$(_sysinfo_spaces "$label_pad")")"
    printf '%s' "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_MUTED" " : ")"

    # Value + explicit padding (do not rely on inherited background state).
    printf '%s' "$value"
    printf '%s%*s' "$(_sysinfo_box_span "$row_bg" "$_SYSINFO_SGR_VALUE" "")" "$pad" ""

    printf '%s' "$(_sysinfo_box_span "$row_bg" "" " ")"

    # Right border, then reset so shell prompt isn't affected.
    printf '%s\n' "${_SYSINFO_SGR_RESET}${_SYSINFO_SGR_BORDER}${v_border}${_SYSINFO_SGR_RESET}"
}

_sysinfo_pretty_used_total_free() {
    local used="$1" total="$2" free="$3"
    [[ -n "$used" ]] || used="N/A"
    [[ -n "$total" ]] || total="N/A"
    [[ -n "$free" ]] || free="N/A"
    printf '%sUsed%s %s%s%s  %sTotal%s %s%s%s  %sFree%s %s%s%s' \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_USED}" "$used" "${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_VALUE}" "$total" "${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_FREE}" "$free" "${_SYSINFO_SGR_RESET}"
}

_sysinfo_pretty_cpu() {
    local u="$1" s="$2" i="$3"
    [[ -n "$u" ]] || u="N/A"
    [[ -n "$s" ]] || s="N/A"
    [[ -n "$i" ]] || i="N/A"
    printf '%sUser%s %s%s%%%s  %sSys%s %s%s%%%s  %sIdle%s %s%s%%%s' \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_USED}" "$u" "${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_USED}" "$s" "${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_FREE}" "$i" "${_SYSINFO_SGR_RESET}"
}

_sysinfo_pretty_load() {
    local raw="$1"
    local a b c
    a="$(printf '%s' "$raw" | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')"
    b="$(printf '%s' "$raw" | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')"
    c="$(printf '%s' "$raw" | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')"
    [[ -n "$a" ]] || a="N/A"
    [[ -n "$b" ]] || b="N/A"
    [[ -n "$c" ]] || c="N/A"
    printf '%s1m%s %s%s%s  %s5m%s %s%s%s  %s15m%s %s%s%s' \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_VALUE}" "$a" "${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_VALUE}" "$b" "${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_VALUE}" "$c" "${_SYSINFO_SGR_RESET}"
}

_sysinfo_pretty_net() {
    local rx="$1" tx="$2"
    [[ -n "$rx" ]] || rx="N/A"
    [[ -n "$tx" ]] || tx="N/A"
    printf '%sRX%s %s%s%s  %sTX%s %s%s%s' \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_FREE}" "$rx" "${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_SUBLABEL}" "${_SYSINFO_SGR_RESET}" "${_SYSINFO_SGR_USED}" "$tx" "${_SYSINFO_SGR_RESET}"
}

_sysinfo_wrap() {
    local text="$1" width="$2"
    if _sysinfo_has_cmd fold; then
        # fold handles long words by hard-splitting; good enough for terminal UI.
        # Always include a trailing newline so downstream `read` loops run.
        printf '%s\n' "$text" | fold -s -w "$width"
    else
        # Fallback: no wrapping.
        printf '%s\n' "$text"
    fi
}

_sysinfo_render_box() {
    local use_colour="${1:-1}"
    local cols width inner content_w label_w value_w
    cols="$(_sysinfo_term_cols)"

    _sysinfo_style_init "$use_colour"

    _sysinfo_is_tty || { _sysinfo_render_segments "$use_colour"; return 0; }

    if [[ "$cols" -lt 60 ]]; then
        _sysinfo_render_segments "$use_colour"
        return 0
    fi

    width="$cols"
    [[ "$width" -gt 100 ]] && width=100
    [[ "$width" -ge 40 ]] || { _sysinfo_render_segments "$use_colour"; return 0; }

    inner=$((width - 2))
    content_w=$((width - 4))

    local tl tr bl br h v
    if _sysinfo_supports_utf8; then
        tl="┌" tr="┐" bl="└" br="┘" h="─" v="│"
    else
        tl="+" tr="+" bl="+" br="+" h="-" v="|"
    fi

    # Fixed label width; keep the layout stable.
    label_w=6

    value_w=$((content_w - label_w - 3))
    [[ "$value_w" -ge 10 ]] || { _sysinfo_render_segments "$use_colour"; return 0; }

    local title_text=" System Info "
    local title_len="${#title_text}"
    local rem=$((inner - title_len))
    local left=$((rem / 2))
    local right=$((rem - left))

    printf '%s%s%s%s%s\n' \
        "${_SYSINFO_SGR_BORDER}${tl}${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_BORDER}$(_sysinfo_repeat "$h" "$left")${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_TITLE}${title_text}${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_BORDER}$(_sysinfo_repeat "$h" "$right")${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_BORDER}${tr}${_SYSINFO_SGR_RESET}"

    local row=0 content

    local row_bg

    row_bg="$(_sysinfo_box_row_bg "$row")"
    content="$(_sysinfo_box_fmt_pair "$row_bg" "Name" "${os_name:-N/A}")$(_sysinfo_box_span "$row_bg" "" "  ")$(_sysinfo_box_fmt_pair "$row_bg" "Ver" "${os_ver:-N/A}")"
    _sysinfo_box_print_row "$row_bg" "OS" "$content" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_sysinfo_box_row_bg "$row")"
    content="$(_sysinfo_box_fmt_used_total_free "$row_bg" "${startup_used:-N/A}" "${startup_size:-N/A}" "${startup_free:-N/A}")"
    _sysinfo_box_print_row "$row_bg" "Disk" "$content" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_sysinfo_box_row_bg "$row")"
    content="$(_sysinfo_box_fmt_pair "$row_bg" "Up" "$(_sysinfo_fmt_uptime_short "${uptime_time:-N/A}")")"
    _sysinfo_box_print_row "$row_bg" "Uptime" "$content" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_sysinfo_box_row_bg "$row")"
    content="$(_sysinfo_box_fmt_load "$row_bg" "${uptime_load:-N/A}")"
    _sysinfo_box_print_row "$row_bg" "Load" "$content" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_sysinfo_box_row_bg "$row")"
    content="$(_sysinfo_box_fmt_cpu "$row_bg" "${cpu_used_user:-N/A}" "${cpu_used_sys:-N/A}" "${cpu_used_idle:-N/A}")"
    _sysinfo_box_print_row "$row_bg" "CPU" "$content" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_sysinfo_box_row_bg "$row")"
    content="$(_sysinfo_box_fmt_used_total_free "$row_bg" "${ram_used:-N/A}" "${ram_total:-N/A}" "${ram_free:-N/A}")"
    _sysinfo_box_print_row "$row_bg" "RAM" "$content" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_sysinfo_box_row_bg "$row")"
    content="$(_sysinfo_box_fmt_net "$row_bg" "${network_down:-N/A}" "${network_up:-N/A}")"
    _sysinfo_box_print_row "$row_bg" "Net" "$content" "$label_w" "$value_w" "$v"

    printf '%s%s%s\n' \
        "${_SYSINFO_SGR_BORDER}${bl}${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_BORDER}$(_sysinfo_repeat "$h" "$inner")${_SYSINFO_SGR_RESET}" \
        "${_SYSINFO_SGR_BORDER}${br}${_SYSINFO_SGR_RESET}"
}

_sysinfo_render_segments() {
    local use_colour="${1:-1}"
    local cols sep sep_len
    cols="$(_sysinfo_term_cols)"
    sep="  "
    sep_len=2

    _sysinfo_style_init "$use_colour"
    local c_label="$_SYSINFO_SGR_LABEL" c_value="$_SYSINFO_SGR_VALUE" c_reset="$_SYSINFO_SGR_RESET"

    local os disk uptime load cpu ram net
    os="${os_name} ${os_ver}"
    disk="${startup_name} $(_sysinfo_pretty_used_total_free "$startup_used" "$startup_size" "$startup_free")"
    uptime="$(_sysinfo_fmt_uptime_short "$uptime_time")"
    load="$(_sysinfo_pretty_load "$uptime_load")"
    cpu="$(_sysinfo_pretty_cpu "$cpu_used_user" "$cpu_used_sys" "$cpu_used_idle")"
    ram="$(_sysinfo_pretty_used_total_free "$ram_used" "$ram_total" "$ram_free")"
    net="$(_sysinfo_pretty_net "$network_down" "$network_up")"

    local segments=(
        "${c_label}OS${c_reset}: ${c_value}${os}${c_reset}"
        "${c_label}Disk${c_reset}: ${c_value}${disk}${c_reset}"
        "${c_label}Uptime${c_reset}: ${c_value}${uptime}${c_reset}"
        "${c_label}Load${c_reset}: ${c_value}${load}${c_reset}"
        "${c_label}CPU${c_reset}: ${c_value}${cpu}${c_reset}"
        "${c_label}RAM${c_reset}: ${c_value}${ram}${c_reset}"
        "${c_label}Net${c_reset}: ${c_value}${net}${c_reset}"
    )

    if [[ "$cols" -lt 60 ]]; then
        local seg
        for seg in "${segments[@]}"; do
            printf '%s\n' "$seg"
        done
        return 0
    fi

    local line="" line_len=0 seg seg_len
    for seg in "${segments[@]}"; do
        seg_len="$(_sysinfo_visible_len "$seg")"
        if [[ "$line_len" -eq 0 ]]; then
            line="$seg"
            line_len="$seg_len"
        elif [[ $((line_len + sep_len + seg_len)) -le "$cols" ]]; then
            line+="$sep$seg"
            line_len=$((line_len + sep_len + seg_len))
        else
            printf '%s\n' "$line"
            line="$seg"
            line_len="$seg_len"
        fi
    done
    [[ -n "$line" ]] && printf '%s\n' "$line"
}

_sysinfo_render_table() {
    local use_colour="${1:-1}"
    _sysinfo_style_init "$use_colour"
    local c_label="$_SYSINFO_SGR_LABEL" c_value="$_SYSINFO_SGR_VALUE" c_reset="$_SYSINFO_SGR_RESET"

    local os disk uptime load cpu ram net
    os="${os_name} ${os_ver}"
    disk="${startup_name} $(_sysinfo_pretty_used_total_free "$startup_used" "$startup_size" "$startup_free")"
    uptime="$(_sysinfo_fmt_uptime_short "$uptime_time")"
    load="$(_sysinfo_pretty_load "$uptime_load")"
    cpu="$(_sysinfo_pretty_cpu "$cpu_used_user" "$cpu_used_sys" "$cpu_used_idle")"
    ram="$(_sysinfo_pretty_used_total_free "$ram_used" "$ram_total" "$ram_free")"
    net="$(_sysinfo_pretty_net "$network_down" "$network_up")"

    printf '%s\n' \
        "${c_label}OS${c_reset} | ${c_label}Disk${c_reset} | ${c_label}Uptime${c_reset} | ${c_label}Load${c_reset} | ${c_label}CPU${c_reset} | ${c_label}RAM${c_reset} | ${c_label}Net${c_reset}"
    printf '%s\n' \
        "${c_value}${os}${c_reset} | ${c_value}${disk}${c_reset} | ${c_value}${uptime}${c_reset} | ${c_value}${load}${c_reset} | ${c_value}${cpu}${c_reset} | ${c_value}${ram}${c_reset} | ${c_value}${net}${c_reset}"
}

print_terminal() {
    local use_colour="${1:-1}"
    local layout="${2:-auto}"
    local cols
    cols="$(_sysinfo_term_cols)"

    case "$layout" in
        box)
            _sysinfo_render_box "$use_colour"
            ;;
        table)
            _sysinfo_render_table "$use_colour"
            ;;
        stacked|segments)
            _sysinfo_render_segments "$use_colour"
            ;;
        auto|*)
            # Pretty box for interactive sessions; simple wrapped output elsewhere.
            if _sysinfo_is_tty && _sysinfo_has_cmd tput && [[ "${TERM:-}" != "dumb" ]] && [[ "$cols" -ge 60 ]]; then
                _sysinfo_render_box "$use_colour"
            else
                _sysinfo_render_segments "$use_colour"
            fi
            ;;
    esac
}

_SYSINFO_KV_KEYS=(os os_version boot_volume volume_size volume_used volume_free uptime load_avg cpu_user cpu_sys cpu_idle ram_used ram_free ram_total net_rx net_tx)

_sysinfo_print_kv() {
    # Machine-friendly output: one key=value per line.
    local key value
    for key in "${_SYSINFO_KV_KEYS[@]}"; do
        case "$key" in
            os) value="$os_name" ;; 
            os_version) value="$os_ver" ;; 
            boot_volume) value="$startup_name" ;; 
            volume_size) value="$startup_size" ;; 
            volume_used) value="$startup_used" ;; 
            volume_free) value="$startup_free" ;; 
            uptime) value="$uptime_time" ;; 
            load_avg) value="$uptime_load" ;; 
            cpu_user) value="$cpu_used_user" ;; 
            cpu_sys) value="$cpu_used_sys" ;; 
            cpu_idle) value="$cpu_used_idle" ;; 
            ram_used) value="$ram_used" ;; 
            ram_free) value="$ram_free" ;; 
            ram_total) value="$ram_total" ;; 
            net_rx) value="$network_down" ;; 
            net_tx) value="$network_up" ;; 
            *) value="N/A" ;; 
        esac
        printf '%s=%s\n' "$key" "${value:-N/A}"
    done
}

sysinfo_usage() {
    cat <<'USAGE'
Usage: sysinfo [--help] [--plain|--no-color] [--kv] [--box|--table|--stacked]

Human output is the default.

Options:
    -h, --help        Show this help and exit.
    --box             Pretty boxed output (uses terminfo via `tput` when available).
    --table, --wide   Force a single-row table (best on wide terminals).
    --stacked, --compact
                     Force a wrapped multi-line layout (best on narrow terminals).
    --plain, --no-color
                                     Disable ANSI color.
    --kv              Machine-readable key=value output (one per line).

Environment:
    SYSINFO_LAYOUT    One of: auto, box, table, stacked. (Default: auto)

Exit codes:
    0 success
    1 runtime error
    2 usage/unknown option
USAGE
}

main() {
    local output_mode="${1:-human}"
    local use_colour="${2:-1}"
    local layout="${3:-auto}"
    find_os || return 1

    if [[ $which_os -eq 1 ]]; then
        mac_disk_info
        mac_get_network
        mac_get_cpu
        mac_get_uptime
        mac_get_ram
    else
        detect_primary_interface  # Detect primary network interface for Linux
        linux_disk_info
        linux_get_network
        linux_get_cpu
        linux_get_uptime
        linux_get_ram
    fi

    if [[ "$output_mode" == "kv" ]]; then
        _sysinfo_print_kv
    else
        print_terminal "$use_colour" "$layout"
    fi
}

sysinfo() {
    local output_mode="human"
    local colour_mode="auto"
    local layout="${SYSINFO_LAYOUT:-auto}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                sysinfo_usage
                return 0
                ;;
            --kv|--key-value)
                output_mode="kv"
                ;;
            --table|--wide)
                layout="table"
                ;;
            --stacked|--compact)
                layout="stacked"
                ;;
            --box)
                layout="box"
                ;;
            --plain|--no-color)
                colour_mode="off"
                ;;
            --color)
                colour_mode="on"
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "sysinfo: unknown option: $1" >&2
                sysinfo_usage >&2
                return 2
                ;;
        esac
        shift
    done

    local use_colour=1
    case "$colour_mode" in
        off) use_colour=0 ;;
        on)  use_colour=1 ;;
        auto)
            if [[ -t 1 ]]; then
                use_colour=1
            else
                use_colour=0
            fi
            ;;
    esac

    main "$output_mode" "$use_colour" "$layout"
}

# Run only when executed directly.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    sysinfo "$@"
fi
