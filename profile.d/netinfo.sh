#!/usr/bin/env bash

#------------------------------------------------------------------------------
# netinfo: network telemetry helper (portable macOS + Linux)
#------------------------------------------------------------------------------

# shellcheck shell=bash

if ! declare -F has_cmd >/dev/null 2>&1; then
    has_cmd() { command -v "$1" >/dev/null 2>&1; }
fi

_netinfo_cache_dir() {
    echo "${XDG_CACHE_HOME:-$HOME/.cache}/my-mac-bash-profile"
}

_netinfo_external_ip() {
    if [[ "${NETINFO_EXTERNAL_IP:-1}" == "0" ]]; then
        echo "N/A"
        return 0
    fi
    local ttl="${NETINFO_EXTERNAL_IP_TTL:-300}"
    local cache_dir cache_file now ts ip
    cache_dir="$(_netinfo_cache_dir)"
    cache_file="$cache_dir/external_ip"
    now="$(date +%s 2>/dev/null || echo 0)"

    if [[ -r "$cache_file" ]]; then
        ts="$(awk 'NR==1 {print $1; exit}' "$cache_file" 2>/dev/null || echo 0)"
        ip="$(awk 'NR==1 {print $2; exit}' "$cache_file" 2>/dev/null || echo '')"
        if [[ -n "$ip" && "$now" -gt 0 && "$ts" -gt 0 && $((now - ts)) -lt "$ttl" ]]; then
            echo "$ip"
            return 0
        fi
    fi

    if has_cmd curl; then
        ip="$(curl -fsS --max-time 4 https://ipinfo.io/ip 2>/dev/null | tr -d '[:space:]')"
    elif has_cmd wget; then
        ip="$(wget -qO- --timeout=4 https://ipinfo.io/ip 2>/dev/null | tr -d '[:space:]')"
    else
        echo "N/A"
        return 0
    fi

    [[ -n "$ip" ]] || ip="N/A"
    mkdir -p "$cache_dir" 2>/dev/null || true
    printf "%s %s\n" "${now:-0}" "$ip" > "$cache_file" 2>/dev/null || true
    echo "$ip"
}

_netinfo_default_iface_linux() {
    if has_cmd ip; then
        ip route 2>/dev/null | awk '/^default/ {print $5; exit}' 2>/dev/null || true
    fi
}

_netinfo_default_gw_linux() {
    if has_cmd ip; then
        ip route 2>/dev/null | awk '/^default/ {print $3; exit}' 2>/dev/null || true
    fi
}

_netinfo_default_iface_macos() {
    if has_cmd route; then
        route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}' 2>/dev/null || true
    fi
}

_netinfo_default_gw_macos() {
    if has_cmd route; then
        route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}' 2>/dev/null || true
    fi
}

_netinfo_local_ip_linux() {
    if has_cmd ip; then
        ip -o -4 addr show scope global 2>/dev/null | awk '{print $4}' 2>/dev/null | head -n 1 || true
    fi
}

_netinfo_local_ip_macos() {
    if has_cmd ipconfig; then
        local iface
        iface="$(_netinfo_default_iface_macos)"
        [[ -n "$iface" ]] && ipconfig getifaddr "$iface" 2>/dev/null
    fi
}

_netinfo_wifi_ssid_linux() {
    if has_cmd iwgetid; then
        iwgetid -r 2>/dev/null
    fi
}

_netinfo_wifi_ssid_macos() {
    if has_cmd networksetup; then
        networksetup -getairportnetwork "${NETINFO_WIFI_DEVICE:-en0}" 2>/dev/null | awk -F': ' '{print $2}' 2>/dev/null || true
    fi
}

_netinfo_vpn_ifaces_linux() {
    if has_cmd ip; then
        ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^(tun|tap|wg|ppp|tailscale)[0-9]*$' || true
    fi
}

_netinfo_vpn_ifaces_macos() {
    if has_cmd ifconfig; then
        ifconfig 2>/dev/null | awk -F: '/^[a-z0-9]+:/{print $1}' | grep -E '^utun[0-9]+$' || true
    fi
}

_netinfo_join_lines() {
    # Join stdin lines with commas (no trailing comma).
    awk 'NR==1{printf "%s",$0; next} {printf ",%s",$0} END{print ""}'
}

_NETINFO_KV_KEYS=(os default_interface gateway local_ip wifi_ssid vpn_interfaces external_ip)

netinfo() {
    local output_mode="human"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<'USAGE'
Usage: netinfo [--help] [--plain|--no-color] [--kv]

Human output is the default.

Options:
  -h, --help        Show this help and exit.
  --plain, --no-color
                   Disable ANSI color (netinfo output is plain by default).
  --kv              Machine-readable key=value output (one per line).

Exit codes:
  0 success
  1 runtime error
  2 usage/unknown option
USAGE
                return 0
                ;;
            --kv|--key-value)
                output_mode="kv"
                ;;
            --plain|--no-color|--color)
                # Accepted for consistency with other helpers. netinfo is plain by default.
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "netinfo: unknown option: $1" >&2
                return 2
                ;;
        esac
        shift
    done

    local os iface gw lip ssid ext vpn
    os="$(uname -s 2>/dev/null || echo 'Unknown')"

    if [[ "$os" == "Linux" ]]; then
        iface="$(_netinfo_default_iface_linux)"
        gw="$(_netinfo_default_gw_linux)"
        lip="$(_netinfo_local_ip_linux)"
        ssid="$(_netinfo_wifi_ssid_linux)"
        vpn="$(_netinfo_vpn_ifaces_linux | _netinfo_join_lines 2>/dev/null)"
    elif [[ "$os" == "Darwin" ]]; then
        iface="$(_netinfo_default_iface_macos)"
        gw="$(_netinfo_default_gw_macos)"
        lip="$(_netinfo_local_ip_macos)"
        ssid="$(_netinfo_wifi_ssid_macos)"
        vpn="$(_netinfo_vpn_ifaces_macos | _netinfo_join_lines 2>/dev/null)"
    fi

    iface="${iface:-N/A}"
    gw="${gw:-N/A}"
    lip="${lip:-N/A}"
    ssid="${ssid:-N/A}"
    vpn="${vpn:-none}"
    ext="$(_netinfo_external_ip)"

    if [[ "$output_mode" == "kv" ]]; then
        local key value
        for key in "${_NETINFO_KV_KEYS[@]}"; do
            case "$key" in
                os) value="$os" ;;
                default_interface) value="$iface" ;;
                gateway) value="$gw" ;;
                local_ip) value="$lip" ;;
                wifi_ssid) value="$ssid" ;;
                vpn_interfaces) value="$vpn" ;;
                external_ip) value="$ext" ;;
                *) value="N/A" ;;
            esac
            printf '%s=%s\n' "$key" "${value:-N/A}"
        done
        return 0
    fi

    echo "OS: $os"
    echo "Default interface: $iface"
    echo "Gateway: $gw"
    echo "Local IP: $lip"
    echo "Wi-Fi SSID: $ssid"
    echo "VPN interfaces: $vpn"
    echo "External IP (cached): $ext"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    netinfo "$@"
fi
