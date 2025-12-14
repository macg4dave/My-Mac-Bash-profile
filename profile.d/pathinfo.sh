#------------------------------------------------------------------------------
# PATH inspection helper (opt-in extra)
#------------------------------------------------------------------------------

# shellcheck shell=bash

pathinfo() {
    pathinfo_usage() {
        cat <<'USAGE'
Usage: pathinfo [--help] [--duplicates] [--missing]

Print PATH entries one per line and flag duplicates and missing directories.

Options:
  -h, --help      Show this help and exit.
  --duplicates    Show only duplicate PATH entries.
  --missing       Show only entries that do not exist on disk.

Exit codes:
  0 success
  1 runtime error
  2 usage/unknown option
USAGE
    }

    local only_dups=0 only_missing=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                pathinfo_usage
                return 0
                ;;
            --duplicates)
                only_dups=1
                ;;
            --missing)
                only_missing=1
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "pathinfo: unknown option: $1" >&2
                pathinfo_usage >&2
                return 2
                ;;
        esac
        shift
    done

    # Split PATH safely.
    local IFS=':'
    local parts=()
    # Bash 3.2 compatible.
    read -r -a parts <<< "${PATH:-}"

    local seen=":"
    local i=0
    local p status dup suffix

    for p in "${parts[@]}"; do
        i=$((i + 1))
        [[ -n "$p" ]] || p="."

        status="ok"
        [[ -d "$p" ]] || status="missing"

        dup=0
        case "$seen" in
            *":$p:"*) dup=1 ;;
        esac
        seen+="$p:"

        if [[ "$only_dups" -eq 1 && "$dup" -ne 1 ]]; then
            continue
        fi
        if [[ "$only_missing" -eq 1 && "$status" != "missing" ]]; then
            continue
        fi

        suffix=""
        if [[ "$dup" -eq 1 ]]; then
            suffix=",dup"
        fi
        printf '%3d  %s  [%s%s]\n' "$i" "$p" "$status" "$suffix"
    done
}
