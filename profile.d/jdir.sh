#!/usr/bin/env bash

#------------------------------------------------------------------------------
# jdir / jd
#
# Friendly wrappers around wget.
#
# - jdir: "download a directory" (recursive, continue, no-parent)
# - jd:   "download" (continue)
#
# Safe to source (defines functions only). Can also be executed directly.
#------------------------------------------------------------------------------

# shellcheck shell=bash

_jdir_has_cmd() {
	command -v "$1" >/dev/null 2>&1
}

_jdir_run() {
	# Usage: _jdir_run <dry_run:0|1> <cmd...>
	local dry_run="$1"
	shift
	if [[ "$dry_run" -eq 1 ]]; then
		local q=()
		local a
		for a in "$@"; do
			q+=("$(printf '%q' "$a")")
		done
		printf '%s\n' "${q[*]}"
	else
		"$@"
	fi
}

jdir() {
	# Usage: jdir [--dry-run] [--help] <url> [wget_args...]
	local dry_run=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--dry-run|-n) dry_run=1 ;;
			-h|--help)
				cat <<'EOF'
Usage: jdir [--dry-run] <url> [wget_args...]

Recursively download a "directory" from a web server.

Equivalent to:
	wget -r -c --no-parent <url>

Notes:
	- This depends on server directory listing / link structure.
	- Add your own wget flags after the URL if needed.

Examples:
	jdir https://example.com/files/
	jdir --dry-run https://example.com/files/ -np -nH --cut-dirs=1
EOF
				return 0
				;;
			--) shift; break ;;
			*) break ;;
		esac
		shift
	done

	if ! _jdir_has_cmd wget; then
		echo "jdir: wget not found in PATH" >&2
		return 127
	fi

	if [[ $# -lt 1 ]]; then
		echo "jdir: missing <url> (try --help)" >&2
		return 2
	fi

	local url="$1"
	shift
	_jdir_run "$dry_run" wget -r -c --no-parent "$url" "$@"
}

jd() {
	# Usage: jd [--dry-run] [--help] <url> [wget_args...]
	local dry_run=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--dry-run|-n) dry_run=1 ;;
			-h|--help)
				cat <<'EOF'
Usage: jd [--dry-run] <url> [wget_args...]

Download a URL and continue partial downloads.

Equivalent to:
	wget -c <url>

Examples:
	jd https://example.com/big.iso
	jd --dry-run https://example.com/big.iso --show-progress
EOF
				return 0
				;;
			--) shift; break ;;
			*) break ;;
		esac
		shift
	done

	if ! _jdir_has_cmd wget; then
		echo "jd: wget not found in PATH" >&2
		return 127
	fi

	if [[ $# -lt 1 ]]; then
		echo "jd: missing <url> (try --help)" >&2
		return 2
	fi

	local url="$1"
	shift
	_jdir_run "$dry_run" wget -c "$url" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	# If executed directly, default to the recursive mode for convenience.
	jdir "$@"
fi