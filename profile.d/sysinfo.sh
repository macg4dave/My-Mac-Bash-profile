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

_sysinfo_render_segments() {
    local use_colour="${1:-1}"
    local cols sep sep_len
    cols="$(_sysinfo_term_cols)"
    sep="  "
    sep_len=2

    local c_label="" c_value="" c_reset=""
    if [[ "$use_colour" == "1" ]]; then
        c_label=$'\033[33m'
        c_value=$'\033[36m'
        c_reset=$'\033[0m'
    fi

    local os disk uptime load cpu ram net
    os="${os_name} ${os_ver}"
    disk="${startup_name} ${startup_used}/${startup_size} (${startup_free} free)"
    uptime="$(_sysinfo_fmt_uptime_short "$uptime_time")"
    load="$uptime_load"
    cpu="u${cpu_used_user}% s${cpu_used_sys}% i${cpu_used_idle}%"
    ram="${ram_used}/${ram_total} (${ram_free} free)"
    net="RX ${network_down} TX ${network_up}"

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
    local c_label="" c_value="" c_reset=""
    if [[ "$use_colour" == "1" ]]; then
        c_label=$'\033[33m'
        c_value=$'\033[36m'
        c_reset=$'\033[0m'
    fi

    local os disk uptime load cpu ram net
    os="${os_name} ${os_ver}"
    disk="${startup_name} ${startup_used}/${startup_size} (${startup_free} free)"
    uptime="$(_sysinfo_fmt_uptime_short "$uptime_time")"
    load="$uptime_load"
    cpu="u${cpu_used_user}% s${cpu_used_sys}% i${cpu_used_idle}%"
    ram="${ram_used}/${ram_total} (${ram_free} free)"
    net="RX ${network_down} TX ${network_up}"

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
        table)
            _sysinfo_render_table "$use_colour"
            ;;
        stacked|segments)
            _sysinfo_render_segments "$use_colour"
            ;;
        auto|*)
            # Table looks best when it won't wrap.
            if [[ "$cols" -ge 150 ]]; then
                _sysinfo_render_table "$use_colour"
            else
                _sysinfo_render_segments "$use_colour"
            fi
            ;;
    esac
}

# Main function to collect system information and print it
_sysinfo_print_kv() {
    # Machine-friendly output: one key=value per line.
    # Values may contain spaces; callers should parse accordingly.
    printf '%s=%s\n' os "$os_name"
    printf '%s=%s\n' os_version "$os_ver"
    printf '%s=%s\n' boot_volume "$startup_name"
    printf '%s=%s\n' volume_size "$startup_size"
    printf '%s=%s\n' volume_used "$startup_used"
    printf '%s=%s\n' volume_free "$startup_free"
    printf '%s=%s\n' uptime "$uptime_time"
    printf '%s=%s\n' load_avg "$uptime_load"
    printf '%s=%s\n' cpu_user "$cpu_used_user"
    printf '%s=%s\n' cpu_sys "$cpu_used_sys"
    printf '%s=%s\n' cpu_idle "$cpu_used_idle"
    printf '%s=%s\n' ram_used "$ram_used"
    printf '%s=%s\n' ram_free "$ram_free"
    printf '%s=%s\n' ram_total "$ram_total"
    printf '%s=%s\n' net_rx "$network_down"
    printf '%s=%s\n' net_tx "$network_up"
}

sysinfo_usage() {
    cat <<'USAGE'
Usage: sysinfo [--help] [--plain|--no-color] [--kv] [--table|--stacked]

Human output is the default.

Options:
    -h, --help        Show this help and exit.
    --table, --wide   Force a single-row table (best on wide terminals).
    --stacked, --compact
                     Force a wrapped multi-line layout (best on narrow terminals).
    --plain, --no-color
                                     Disable ANSI color.
    --kv              Machine-readable key=value output (one per line).

Environment:
    SYSINFO_LAYOUT    One of: auto, table, stacked. (Default: auto)

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
