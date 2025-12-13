#------------------------------------------------------------------------------
# Archive extraction helper
#------------------------------------------------------------------------------

# shellcheck shell=bash

# If sourced standalone (without 10-common.sh), provide a tiny fallback.
if ! declare -F has_cmd >/dev/null 2>&1; then
    has_cmd() { command -v "$1" >/dev/null 2>&1; }
fi

extract() {
    extract_usage() {
        cat <<'USAGE'
Usage: extract [--help] [-v|--verbose] [-l|--list] [-f|--force] <archive> [dest]

Options:
  -h, --help     Show this help and exit.
  -v, --verbose  Print the command used and enable verbose mode for tools that support it.
  -l, --list     List archive contents (when supported).
  -f, --force    Allow potentially unsafe paths in archives and allow overwriting.

Exit codes:
  0 success
  1 runtime error
  2 usage/unknown option
USAGE
    }

    local verbose=false list=false force=false archive dest
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    extract_usage; return 0 ;;
            -v|--verbose) verbose=true ;;
            -l|--list)    list=true ;;
            -f|--force)   force=true ;;
            --) shift; break ;;
            -*) echo "Unknown option: $1" >&2; extract_usage >&2; return 2 ;;
            *)  archive="${archive:-$1}" ;;
        esac
        shift
    done
    if [[ -z "$archive" ]]; then
        extract_usage >&2
        return 2
    fi
    [[ $# -gt 0 ]] && dest="$1"

    if [[ ! -f "$archive" || ! -r "$archive" ]]; then
        echo "Archive '$archive' is not readable." >&2
        return 1
    fi

    local archive_name base lc
    archive_name="$(basename "$archive")"
    lc="$(LC_ALL=C printf '%s' "$archive_name" | tr '[:upper:]' '[:lower:]')"

    # Guess destination directory if not provided.
    case "$lc" in
        *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.tar.z|*.tar.Z)
            base="${archive_name%%.tar.*}"
            ;;
        *.tar.*)
            base="${archive_name%%.tar.*}"
            ;;
        *)
            base="${archive_name%.*}"
            ;;
    esac
    dest="${dest:-$base}"

    # Safety: refuse obvious path traversal in tar/zip/7z unless forced.
    _extract_check_paths() {
        # Usage: _extract_check_paths <archive> <list-cmd...>
        local file="$1"
        shift
        local line
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if [[ "$line" == /* || "$line" == ../* || "$line" == *"/../"* ]]; then
                echo "Potential unsafe path detected: $line (use --force to override)" >&2
                return 1
            fi
        done < <("$@" "$file")
    }

    [[ -d "$dest" ]] || mkdir -p "$dest"

    # Don't overwrite existing files unless --force was requested.
    # GNU tar supports: --keep-old-files
    # bsdtar (macOS /usr/bin/tar) supports: -k
    local tar_keep=()
    if ! $force; then
        if tar --help 2>/dev/null | grep -q -- '--keep-old-files'; then
            tar_keep=("--keep-old-files")
        else
            tar_keep=(-k)
        fi
    fi

    if $list; then
        case "$lc" in
            *.tar.bz2|*.tbz2)   tar tjf "$archive" ;;
            *.tar.gz|*.tgz)     tar tzf "$archive" ;;
            *.tar.xz|*.txz)     tar tJf "$archive" ;;
            *.tar.z|*.tar.Z)    tar tZf "$archive" ;;
            *.tar)              tar tf "$archive" ;;
            *.zip)              unzip -l "$archive" ;;
            *.rar)              unrar l "$archive" ;;
            *.7z)               7z l "$archive" ;;
            *.gz|*.bz2|*.xz|*.lzma|*.Z)
                echo "Listing not supported for single-file compression; will output filename only."
                echo "${archive_name%.*}"
                ;;
            *)
                echo "Cannot list '$archive' (unknown format)" >&2
                return 1
                ;;
        esac
        return $?
    fi

    local cmd_desc=""
    case "$lc" in
        *.tar.bz2|*.tbz2)
            if ! $force; then
                _extract_check_paths "$archive" tar tjf || return 1
            fi
            cmd_desc="tar xjf"
            tar xjf "$archive" -C "$dest" "${tar_keep[@]}" ${verbose:+-v}
            ;;
        *.tar.gz|*.tgz)
            if ! $force; then
                _extract_check_paths "$archive" tar tzf || return 1
            fi
            cmd_desc="tar xzf"
            tar xzf "$archive" -C "$dest" "${tar_keep[@]}" ${verbose:+-v}
            ;;
        *.tar.xz|*.txz)
            if ! $force; then
                _extract_check_paths "$archive" tar tJf || return 1
            fi
            cmd_desc="tar xJf"
            tar xJf "$archive" -C "$dest" "${tar_keep[@]}" ${verbose:+-v}
            ;;
        *.tar.z|*.tar.Z)
            if ! $force; then
                _extract_check_paths "$archive" tar tZf || return 1
            fi
            cmd_desc="tar xZf"
            tar xZf "$archive" -C "$dest" "${tar_keep[@]}" ${verbose:+-v}
            ;;
        *.tar)
            if ! $force; then
                _extract_check_paths "$archive" tar tf || return 1
            fi
            cmd_desc="tar xf"
            tar xf "$archive" -C "$dest" "${tar_keep[@]}" ${verbose:+-v}
            ;;
        *.zip)
            if ! has_cmd unzip; then
                echo "unzip is required to extract zip archives." >&2
                return 1
            fi
            if ! $force; then
                _extract_check_paths "$archive" unzip -Z1 || return 1
            fi
            cmd_desc="unzip"
            unzip ${force:+-o} ${verbose:+-v} -d "$dest" "$archive"
            ;;
        *.rar)
            if ! has_cmd unrar; then
                echo "unrar is required to extract rar archives." >&2
                return 1
            fi
            cmd_desc="unrar"
            unrar x ${force:+-o+} "$archive" "$dest/"
            ;;
        *.7z)
            if ! has_cmd 7z; then
                echo "7z is required to extract 7z archives." >&2
                return 1
            fi
            if ! $force; then
                _extract_check_paths "$archive" 7z l -ba || return 1
            fi
            cmd_desc="7z x"
            7z x "$archive" -o"$dest" ${verbose:+-bb1}
            ;;
        *.gz)
            if ! has_cmd gunzip; then
                echo "gunzip is required to extract gz files." >&2
                return 1
            fi
            cmd_desc="gunzip"
            local out="${archive_name%.gz}"
            gunzip -c "$archive" > "$dest/$out"
            ;;
        *.bz2)
            if ! has_cmd bunzip2; then
                echo "bunzip2 is required to extract bz2 files." >&2
                return 1
            fi
            cmd_desc="bunzip2"
            local out_bz="${archive_name%.bz2}"
            bunzip2 -c "$archive" > "$dest/$out_bz"
            ;;
        *.xz)
            if ! has_cmd xz; then
                echo "xz is required to extract xz files." >&2
                return 1
            fi
            cmd_desc="xz --decompress"
            local out_xz="${archive_name%.xz}"
            xz -dc "$archive" > "$dest/$out_xz"
            ;;
        *.lzma)
            if ! has_cmd xz; then
                echo "xz (lzma format) is required to extract lzma files." >&2
                return 1
            fi
            cmd_desc="xz --format=lzma --decompress"
            local out_lz="${archive_name%.lzma}"
            xz --format=lzma -dc "$archive" > "$dest/$out_lz"
            ;;
        *.Z)
            if ! has_cmd uncompress; then
                echo "uncompress is required to extract .Z files." >&2
                return 1
            fi
            cmd_desc="uncompress"
            uncompress -c "$archive" > "$dest/${archive_name%.Z}"
            ;;
        *)
            echo "Cannot extract '$archive' (unsupported format)" >&2
            return 1
            ;;
    esac

    $verbose && echo "Extracted with: $cmd_desc -> $dest"
}

#------------------------------------------------------------------------------
# Bash completion (opt-in by context: only registered for interactive shells)
#
# Notes:
# - Compatible with macOS /bin/bash 3.2.
# - Safe to source: defines a function and (optionally) registers completion.
# - We keep the completion lightweight and conservative.
#------------------------------------------------------------------------------

_extract_completion() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"

    # Complete options.
    if [[ "$cur" == -* ]]; then
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "-h --help -v --verbose -l --list -f --force --" -- "$cur") )
        return 0
    fi

    # Determine whether we've already seen the archive argument.
    # extract [opts] <archive> [dest]
    local i word archive_seen=0
    for (( i=1; i<COMP_CWORD; i++ )); do
        word="${COMP_WORDS[i]}"
        case "$word" in
            --) break ;;
            -h|--help|-v|--verbose|-l|--list|-f|--force) continue ;;
            -*) continue ;; # unknown option; don't try to be clever
            *) archive_seen=1; break ;;
        esac
    done

    if [[ "$archive_seen" -eq 0 ]]; then
        # First positional arg: archive file.
        # Prefer files; allow common archive suffixes but don't over-filter.
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -f -- "$cur") )
        return 0
    fi

    # Second positional arg: destination directory.
    # shellcheck disable=SC2207
    COMPREPLY=( $(compgen -d -- "$cur") )
    return 0
}

# Register completion only in interactive shells.
if [[ $- == *i* ]]; then
    # `complete` is a bash builtin, but guard anyway.
    if command -v complete >/dev/null 2>&1; then
        complete -F _extract_completion extract 2>/dev/null || true
    fi
fi
