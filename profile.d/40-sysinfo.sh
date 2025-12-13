#!/usr/bin/env bash

# This file is intended to be *sourceable* by `.bash_profile` (to provide a
# `sysinfo` helper) and also runnable directly (`./40-sysinfo.sh`).
#
# IMPORTANT: do not auto-run on source.

# shellcheck shell=bash

# User and system information variables
which_os="1"  # 1 for macOS, 2 for Linux
os_ver=""
net_int_mac="en0"  # Default network interface for macOS
net_int_linux="eth0"  # Default network interface for Linux

ram_total="N/A"
ram_used="N/A"
ram_free="N/A"

# Function to detect the operating system (macOS or Linux)
find_os() {
    case "$(uname)" in
        Darwin)
            which_os="1"
            os_ver="$(sw_vers -productVersion 2>/dev/null || echo 'N/A')"  # Get macOS version
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

    disk_info=$(diskutil info /)

    # Get startup disk name and size information
    startup_name="$(osascript -e 'tell app "Finder" to get name of startup disk' 2>/dev/null || echo 'N/A')"
    startup_size=$(printf "%s\n" "$disk_info" | grep "Container Total Space:" | awk '{print $4, $5}' || echo 'N/A')
    startup_free=$(printf "%s\n" "$disk_info" | grep "Container Free Space:" | awk '{print $4, $5}' || echo 'N/A')

    # Extract numeric values and remove 'B' suffix for processing
    size_value=$(echo "$startup_size" | awk '{gsub("B", "", $2); print $1}')
    size_unit=$(echo "$startup_size" | awk '{gsub("B", "", $2); print $2}')
    
    free_value=$(echo "$startup_free" | awk '{gsub("B", "", $2); print $1}')
    free_unit=$(echo "$startup_free" | awk '{gsub("B", "", $2); print $2}')

    if command -v numfmt >/dev/null 2>&1; then
        # Convert sizes to bytes for calculation
        size_in_bytes=$(numfmt --from=iec "$size_value$size_unit")
        free_in_bytes=$(numfmt --from=iec "$free_value$free_unit")

        # Calculate used space in bytes and convert it to a human-readable format
        used_in_bytes=$((size_in_bytes - free_in_bytes))
        startup_used=$(numfmt --to=iec --suffix=B "$used_in_bytes")
    else
        startup_used="N/A"
    fi
}

# macOS-specific function to get network information
mac_get_network() {
    ifconfig_output="$(ifconfig "$net_int_mac" 2>/dev/null || echo 'N/A')"
    
    if [[ "$ifconfig_output" == "N/A" ]]; then
        network_down="N/A"
        network_up="N/A"
    else
        # Get network data (bytes sent/received) for the given network interface
        network_down="$(netstat -ib | grep "$net_int_mac" | awk '{print $7}' | head -n 1 2>/dev/null || echo 'N/A')"
        network_up="$(netstat -ib | grep "$net_int_mac" | awk '{print $10}' | head -n 1 2>/dev/null || echo 'N/A')"
        
        # Convert the byte counts to MB/s
        network_down=$(convert_to_mbps "$network_down")
        network_up=$(convert_to_mbps "$network_up")
    fi
}

# macOS-specific function to get CPU usage
mac_get_cpu() {
    cpu_used_user="$(top -l 1 | grep "CPU usage" | awk '{print $3}' 2>/dev/null || echo 'N/A')"
    cpu_used_sys="$(top -l 1 | grep "CPU usage" | awk '{print $5}' 2>/dev/null || echo 'N/A')"
    cpu_used_idle="$(top -l 1 | grep "CPU usage" | awk '{print $7}' 2>/dev/null || echo 'N/A')"
}

# macOS-specific function to get uptime information
mac_get_uptime() {
    uptime_time="$(uptime | awk -F', ' '{print $1}' | sed 's/.*up //' 2>/dev/null || echo 'N/A')"
    uptime_load="$(uptime | awk '{print $10, $11, $12}' 2>/dev/null || echo 'N/A')"
}

# Linux-specific function to get disk information
linux_disk_info() {
    startup_name="/"
    startup_size="$(df -h / | awk 'NR==2 {print $2}' 2>/dev/null || echo 'N/A')"
    startup_used="$(df -h / | awk 'NR==2 {print $3}' 2>/dev/null || echo 'N/A')"
    startup_free="$(df -h / | awk 'NR==2 {print $4}' 2>/dev/null || echo 'N/A')"
}

# Linux-specific function to get network information
linux_get_network() {
    network_down="$(grep "$net_int_linux" /proc/net/dev 2>/dev/null | awk '{print $2}' || echo 'N/A')"
    network_up="$(grep "$net_int_linux" /proc/net/dev 2>/dev/null | awk '{print $10}' || echo 'N/A')"
    
    # Convert the byte counts to MB/s
    network_down=$(convert_to_mbps "$network_down")
    network_up=$(convert_to_mbps "$network_up")
}

# Linux-specific function to get CPU usage
linux_get_cpu() {
    cpu_stat=$(grep 'cpu ' /proc/stat)

    # Parse CPU usage from /proc/stat
    cpu_user=$(echo "$cpu_stat" | awk '{print $2}')
    cpu_sys=$(echo "$cpu_stat" | awk '{print $4}')
    cpu_idle=$(echo "$cpu_stat" | awk '{print $5}')

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
    uptime_time="$(uptime -p 2>/dev/null || echo 'N/A')"
    uptime_load="$(uptime | awk -F'load average: ' '{print $2}' 2>/dev/null || echo 'N/A')"
}

# Function to detect the primary network interface for Linux
detect_primary_interface() {
    if command -v ip >/dev/null 2>&1; then
        net_int_linux=$(ip route | grep '^default' | awk '{print $5}' 2>/dev/null || echo "eth0")
    else
        net_int_linux="eth0"
    fi
}

# Function to add colors and format the text output
add_colours() {
    colour_blue="\033[36m"
    colour_yellow="\033[33m"
    colour_reset="\033[0m"

    # Print the system information with formatted columns
    echo -e "${colour_yellow}OS *&* Boot Volume *&* Volume Size *&* Used *&* Free *&* Uptime *&* Load Avg *&* CPU User *&* CPU Sys *&* CPU Idle *&* RAM Used *&* RAM Free *&* RAM Total *&* Net Down *&* Net Up${colour_reset}"

    echo -e "${colour_blue}${os_ver} *&* ${startup_name} *&* ${startup_size} *&* ${startup_used} *&* ${startup_free} *&* ${uptime_time} *&* ${uptime_load} *&* ${cpu_used_user}% *&* ${cpu_used_sys}% *&* ${cpu_used_idle}% *&* ${ram_used} *&* ${ram_free} *&* ${ram_total} *&* ${network_down} *&* ${network_up}${colour_reset}"
}

# Function to print information to the terminal, centered
print_terminal() {
    display_center() {
        columns="$(tput cols 2>/dev/null || echo 80)"
        while IFS= read -r line; do
            printf "%*s\n" $(( (${#line} + columns) / 2)) "$line"
        done
    }

    # Format and display information
    if command -v column >/dev/null 2>&1; then
        add_colours | column -s "*&*" -t | display_center
    else
        add_colours | display_center
    fi
}

# Main function to collect system information and print it
main() {
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

    print_terminal
}

sysinfo() {
    main
}

# Run only when executed directly.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    sysinfo
fi
