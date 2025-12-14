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
    if mkdir -p "$cache_dir" 2>/dev/null; then
        # Silence any redirection errors (e.g., unwritable cache dir).
        (printf "%s %s\n" "${now:-0}" "$ip" > "$cache_file") 2>/dev/null || true
    fi
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

_netinfo_is_tty() {
    [[ -t 1 ]]
}

_netinfo_tput() {
    has_cmd tput || return 1
    [[ "${TERM:-}" != "dumb" ]] || return 1
    tput "$@" 2>/dev/null || return 1
}

_netinfo_tput_colors() {
    local c
    c="$(_netinfo_tput colors || echo 0)"
    [[ "$c" =~ ^[0-9]+$ ]] || c=0
    echo "$c"
}

_netinfo_supports_utf8() {
    local loc="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
    [[ "$loc" =~ [Uu][Tt][Ff]-?8 ]]
}

_netinfo_term_cols() {
    local cols=""
    if [[ -n "${COLUMNS:-}" && "${COLUMNS:-}" =~ ^[0-9]+$ && "${COLUMNS:-}" -gt 0 ]]; then
        cols="$COLUMNS"
    elif _netinfo_is_tty && has_cmd tput; then
        cols="$(tput cols 2>/dev/null || echo 80)"
    else
        cols="80"
    fi
    [[ "$cols" =~ ^[0-9]+$ ]] || cols="80"
    echo "$cols"
}

_netinfo_visible_len() {
    # Length excluding common terminal escape sequences (CSI/OSC/charset selects).
    printf '%s' "$1" | awk '
      {
        s=$0
        gsub(/\033\[[0-9;?]*[ -/]*[@-~]/,"",s)
        gsub(/\033\][^\007]*\007/,"",s)
        gsub(/\033\][^\033]*\033\\/,"",s)
        gsub(/\033[\(\)][0-9A-Za-z]/,"",s)
        print length(s)
      }'
}

_netinfo_repeat() {
    local ch="$1" count="$2"
    local i
    for ((i = 0; i < count; i++)); do
        printf '%s' "$ch"
    done
}

_netinfo_wrap() {
    local text="$1" width="$2"
    if has_cmd fold; then
        printf '%s\n' "$text" | fold -s -w "$width"
    else
        printf '%s\n' "$text"
    fi
}

# Styles set by _netinfo_style_init().
_NETINFO_SGR_RESET=""
_NETINFO_SGR_TITLE=""
_NETINFO_SGR_LABEL=""
_NETINFO_SGR_VALUE=""
_NETINFO_SGR_MUTED=""
_NETINFO_SGR_OK=""
_NETINFO_SGR_WARN=""
_NETINFO_SGR_NA=""
_NETINFO_SGR_BORDER=""
_NETINFO_SGR_ROW_BG1=""
_NETINFO_SGR_ROW_BG2=""

_netinfo_style_init() {
    local use_colour="${1:-0}"

    _NETINFO_SGR_RESET=""
    _NETINFO_SGR_TITLE=""
    _NETINFO_SGR_LABEL=""
    _NETINFO_SGR_VALUE=""
    _NETINFO_SGR_MUTED=""
    _NETINFO_SGR_OK=""
    _NETINFO_SGR_WARN=""
    _NETINFO_SGR_NA=""
    _NETINFO_SGR_BORDER=""
    _NETINFO_SGR_ROW_BG1=""
    _NETINFO_SGR_ROW_BG2=""

    [[ "$use_colour" == "1" ]] || return 0
    _netinfo_is_tty || return 0

    local reset bold dim colors smso
    reset="$(_netinfo_tput sgr0 || true)"
    bold="$(_netinfo_tput bold || true)"
    dim="$(_netinfo_tput dim || true)"
    colors="$(_netinfo_tput_colors)"
    smso="$(_netinfo_tput smso || true)"

    _NETINFO_SGR_RESET="$reset"
    if [[ "$colors" -ge 256 ]]; then
        _NETINFO_SGR_TITLE="${bold}$(_netinfo_tput setaf 231 || true)$(_netinfo_tput setab 24 || true)"
        _NETINFO_SGR_LABEL="${bold}$(_netinfo_tput setaf 220 || true)"
        _NETINFO_SGR_VALUE="$(_netinfo_tput setaf 81 || true)"
        _NETINFO_SGR_OK="$(_netinfo_tput setaf 114 || true)"
        _NETINFO_SGR_WARN="$(_netinfo_tput setaf 209 || true)"
        _NETINFO_SGR_NA="${dim}$(_netinfo_tput setaf 245 || true)"
        _NETINFO_SGR_MUTED="${dim}$(_netinfo_tput setaf 245 || true)"
        _NETINFO_SGR_BORDER="${dim}$(_netinfo_tput setaf 33 || true)"
        _NETINFO_SGR_ROW_BG1="$(_netinfo_tput setab 236 || true)"
        _NETINFO_SGR_ROW_BG2="$(_netinfo_tput setab 235 || true)"
    else
        _NETINFO_SGR_TITLE="${bold}${smso}$(_netinfo_tput setaf 6 || true)"
        _NETINFO_SGR_LABEL="${bold}$(_netinfo_tput setaf 3 || true)"
        _NETINFO_SGR_VALUE="$(_netinfo_tput setaf 6 || true)"
        _NETINFO_SGR_OK="$(_netinfo_tput setaf 2 || true)"
        _NETINFO_SGR_WARN="$(_netinfo_tput setaf 3 || true)"
        _NETINFO_SGR_NA="${dim}$(_netinfo_tput setaf 7 || true)"
        _NETINFO_SGR_MUTED="${dim}$(_netinfo_tput setaf 7 || true)"
        _NETINFO_SGR_BORDER="${dim}$(_netinfo_tput setaf 4 || true)"
        _NETINFO_SGR_ROW_BG1="$smso"
        _NETINFO_SGR_ROW_BG2=""
    fi
}

_netinfo_box_row_bg() {
    local idx="$1"
    if (( idx % 2 == 0 )); then
        printf '%s' "${_NETINFO_SGR_ROW_BG1}"
    else
        printf '%s' "${_NETINFO_SGR_ROW_BG2}"
    fi
}

_netinfo_box_span() {
    local row_bg="$1" sgr="$2" text="$3"
    printf '%s%s%s%s' "${_NETINFO_SGR_RESET}" "${row_bg}" "${sgr}" "${text}"
}

_netinfo_box_print_row() {
    local row_bg="$1" label="$2" value="$3" label_w="$4" value_w="$5" v_border="$6"

    local label_pad vis pad
    label_pad=$((label_w - ${#label}))
    [[ "$label_pad" -ge 0 ]] || label_pad=0

    vis="$(_netinfo_visible_len "$value")"
    pad=$((value_w - vis))
    [[ "$pad" -ge 0 ]] || pad=0

    printf '%s' "${_NETINFO_SGR_BORDER}${v_border}${_NETINFO_SGR_RESET}"
    printf '%s' "$(_netinfo_box_span "$row_bg" "" " ")"
    printf '%s' "$(_netinfo_box_span "$row_bg" "$_NETINFO_SGR_LABEL" "$label")"
    printf '%s' "$(_netinfo_box_span "$row_bg" "$_NETINFO_SGR_VALUE" "$(printf '%*s' "$label_pad" "")")"
    printf '%s' "$(_netinfo_box_span "$row_bg" "$_NETINFO_SGR_MUTED" " : ")"
    printf '%s' "$value"
    printf '%s%*s' "$(_netinfo_box_span "$row_bg" "$_NETINFO_SGR_VALUE" "")" "$pad" ""
    printf '%s' "$(_netinfo_box_span "$row_bg" "" " ")"
    printf '%s\n' "${_NETINFO_SGR_RESET}${_NETINFO_SGR_BORDER}${v_border}${_NETINFO_SGR_RESET}"
}

_netinfo_style_value() {
    local row_bg="$1" value="$2" kind="${3:-value}"
    [[ -n "$value" ]] || value="N/A"
    if [[ "$value" == "N/A" || "$value" == "none" ]]; then
        printf '%s' "$(_netinfo_box_span "$row_bg" "$_NETINFO_SGR_NA" "$value")"
        return 0
    fi
    case "$kind" in
        ok)   printf '%s' "$(_netinfo_box_span "$row_bg" "$_NETINFO_SGR_OK" "$value")" ;;
        warn) printf '%s' "$(_netinfo_box_span "$row_bg" "$_NETINFO_SGR_WARN" "$value")" ;;
        *)    printf '%s' "$(_netinfo_box_span "$row_bg" "$_NETINFO_SGR_VALUE" "$value")" ;;
    esac
}

_netinfo_render_box() {
    local use_colour="${1:-0}"
    _netinfo_style_init "$use_colour"

    local cols width inner content_w label_w value_w
    cols="$(_netinfo_term_cols)"

    # Fall back to stacked for non-tty or tiny terminals.
    if ! _netinfo_is_tty || [[ "$cols" -lt 60 ]]; then
        _netinfo_render_stacked "$use_colour"
        return 0
    fi

    width="$cols"
    [[ "$width" -gt 100 ]] && width=100
    inner=$((width - 2))
    content_w=$((width - 4))

    # Stable label width.
    label_w=9
    value_w=$((content_w - label_w - 3))
    [[ "$value_w" -ge 15 ]] || { _netinfo_render_stacked "$use_colour"; return 0; }

    local tl tr bl br h v
    if _netinfo_supports_utf8; then
        tl="┌" tr="┐" bl="└" br="┘" h="─" v="│"
    else
        tl="+" tr="+" bl="+" br="+" h="-" v="|"
    fi

    local title_text=" Network Info "
    local title_len="${#title_text}"
    local rem=$((inner - title_len))
    local left=$((rem / 2))
    local right=$((rem - left))

    printf '%s%s%s%s%s\n' \
        "${_NETINFO_SGR_BORDER}${tl}${_NETINFO_SGR_RESET}" \
        "${_NETINFO_SGR_BORDER}$(_netinfo_repeat "$h" "$left")${_NETINFO_SGR_RESET}" \
        "${_NETINFO_SGR_TITLE}${title_text}${_NETINFO_SGR_RESET}" \
        "${_NETINFO_SGR_BORDER}$(_netinfo_repeat "$h" "$right")${_NETINFO_SGR_RESET}" \
        "${_NETINFO_SGR_BORDER}${tr}${_NETINFO_SGR_RESET}"

    local row=0 row_bg value

    row_bg="$(_netinfo_box_row_bg "$row")"
    value="$(_netinfo_style_value "$row_bg" "$os" value)"
    _netinfo_box_print_row "$row_bg" "OS" "$value" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_netinfo_box_row_bg "$row")"
    value="$(_netinfo_style_value "$row_bg" "$iface" ok)"
    _netinfo_box_print_row "$row_bg" "Iface" "$value" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_netinfo_box_row_bg "$row")"
    value="$(_netinfo_style_value "$row_bg" "$gw" warn)"
    _netinfo_box_print_row "$row_bg" "Gateway" "$value" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_netinfo_box_row_bg "$row")"
    value="$(_netinfo_style_value "$row_bg" "$lip" ok)"
    _netinfo_box_print_row "$row_bg" "Local IP" "$value" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_netinfo_box_row_bg "$row")"
    value="$(_netinfo_style_value "$row_bg" "$ssid" value)"
    _netinfo_box_print_row "$row_bg" "Wi-Fi" "$value" "$label_w" "$value_w" "$v"
    row=$((row + 1))

    row_bg="$(_netinfo_box_row_bg "$row")"
    # VPN may be long; wrap it.
    local vpn_line first=1
    while IFS= read -r vpn_line; do
        [[ -n "$vpn_line" ]] || vpn_line=""
        if [[ "$first" -eq 1 ]]; then
            value="$(_netinfo_style_value "$row_bg" "${vpn_line:-$vpn}" value)"
            _netinfo_box_print_row "$row_bg" "VPN" "$value" "$label_w" "$value_w" "$v"
            first=0
        else
            value="$(_netinfo_style_value "$row_bg" "$vpn_line" value)"
            _netinfo_box_print_row "$row_bg" "" "$value" "$label_w" "$value_w" "$v"
        fi
    done < <(_netinfo_wrap "${vpn:-none}" "$value_w")
    row=$((row + 1))

    row_bg="$(_netinfo_box_row_bg "$row")"
    value="$(_netinfo_style_value "$row_bg" "$ext" value)"
    _netinfo_box_print_row "$row_bg" "Ext IP" "$value" "$label_w" "$value_w" "$v"

    printf '%s%s%s\n' \
        "${_NETINFO_SGR_BORDER}${bl}${_NETINFO_SGR_RESET}" \
        "${_NETINFO_SGR_BORDER}$(_netinfo_repeat "$h" "$inner")${_NETINFO_SGR_RESET}" \
        "${_NETINFO_SGR_BORDER}${br}${_NETINFO_SGR_RESET}"
}

_netinfo_render_stacked() {
    local use_colour="${1:-0}"
    _netinfo_style_init "$use_colour"

    if [[ "$use_colour" == "1" ]]; then
        printf '%sOS%s: %s\n' "${_NETINFO_SGR_LABEL}" "${_NETINFO_SGR_RESET}" "$os"
        printf '%sDefault interface%s: %s\n' "${_NETINFO_SGR_LABEL}" "${_NETINFO_SGR_RESET}" "$iface"
        printf '%sGateway%s: %s\n' "${_NETINFO_SGR_LABEL}" "${_NETINFO_SGR_RESET}" "$gw"
        printf '%sLocal IP%s: %s\n' "${_NETINFO_SGR_LABEL}" "${_NETINFO_SGR_RESET}" "$lip"
        printf '%sWi-Fi SSID%s: %s\n' "${_NETINFO_SGR_LABEL}" "${_NETINFO_SGR_RESET}" "$ssid"
        printf '%sVPN interfaces%s: %s\n' "${_NETINFO_SGR_LABEL}" "${_NETINFO_SGR_RESET}" "$vpn"
        printf '%sExternal IP (cached)%s: %s\n' "${_NETINFO_SGR_LABEL}" "${_NETINFO_SGR_RESET}" "$ext"
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

netinfo() {
    local output_mode="human"
    local colour_mode="auto"
    local layout="${NETINFO_LAYOUT:-auto}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<'USAGE'
Usage: netinfo [--help] [--plain|--no-color] [--kv] [--box|--stacked]

Human output is the default.

Options:
  -h, --help        Show this help and exit.
  --box             Pretty boxed output (uses terminfo via `tput` when available).
  --stacked         Multi-line output (legacy layout).
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
            --box)
                layout="box"
                ;;
            --stacked)
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

    local use_colour=0
    case "$colour_mode" in
        on) use_colour=1 ;;
        off) use_colour=0 ;;
        auto)
            if _netinfo_is_tty; then
                use_colour=1
            else
                use_colour=0
            fi
            ;;
    esac

    case "$layout" in
        box)
            _netinfo_render_box "$use_colour"
            ;;
        stacked)
            _netinfo_render_stacked "$use_colour"
            ;;
        auto|*)
            if _netinfo_is_tty && [[ "${TERM:-}" != "dumb" ]] && [[ "$(_netinfo_term_cols)" -ge 60 ]]; then
                _netinfo_render_box "$use_colour"
            else
                _netinfo_render_stacked "$use_colour"
            fi
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    netinfo "$@"
fi
