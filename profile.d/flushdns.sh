#!/usr/bin/env bash

#------------------------------------------------------------------------------
# flushdns
#
# A best-effort DNS cache flush helper for macOS and common Linux setups.
#
# Safe to source (defines functions/aliases only). Can also be executed directly.
#
# Notes:
# - Flushing DNS caches is OS and resolver specific.
# - On Linux, this attempts the most likely mechanisms first.
# - Some operations require elevated privileges; this will use sudo if needed.
#------------------------------------------------------------------------------

# shellcheck shell=bash

_flushdns_has_cmd() {
	command -v "$1" >/dev/null 2>&1
}

_flushdns_is_mac() {
	[[ "$(uname -s 2>/dev/null || echo 'Unknown')" == "Darwin" ]]
}

_flushdns_need_sudo() {
	[[ "${EUID:-$(id -u 2>/dev/null || echo 1)}" -ne 0 ]]
}

_flushdns_run() {
	# Usage: _flushdns_run <dry_run:0|1> <cmd...>
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

_flushdns_run_root() {
	# Usage: _flushdns_run_root <dry_run:0|1> <cmd...>
	local dry_run="$1"
	shift
	if _flushdns_need_sudo; then
		if _flushdns_has_cmd sudo; then
			_flushdns_run "$dry_run" sudo "$@"
		else
			echo "flushdns: need elevated privileges, but sudo not found" >&2
			return 1
		fi
	else
		_flushdns_run "$dry_run" "$@"
	fi
}

flushdns() {
	# Flush DNS caches (best effort).
	#
	# Usage:
	#   flushdns [--dry-run] [--restart] [--status] [--help]
	#
	# Flags:
	#   --dry-run   Print what would run, but do not execute
	#   --restart   Restart common DNS caching services (Linux)
	#   --status    Print a quick status of common DNS cache daemons (Linux)
	#   --help      Show help

	local dry_run=0
	local restart=0
	local status=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--dry-run|-n) dry_run=1 ;;
			--restart) restart=1 ;;
			--status) status=1 ;;
			-h|--help)
				cat <<'EOF'
Usage: flushdns [--dry-run] [--restart] [--status]

Best-effort DNS cache flush helper.

Examples:
	flushdns
	flushdns --dry-run
	flushdns --restart
	flushdns --status
EOF
				return 0
				;;
			*)
				echo "flushdns: unknown option: $1" >&2
				return 2
				;;
		esac
		shift
	done

	# --- macOS ---
	if _flushdns_is_mac; then
		# Works on modern macOS (Big Sur+), and is harmless on older versions.
		# Some macOS versions also benefit from HUP'ing mDNSResponder.
		local did=0

		if _flushdns_has_cmd dscacheutil; then
			_flushdns_run_root "$dry_run" dscacheutil -flushcache || return 1
			did=1
		fi

		if _flushdns_has_cmd killall; then
			# These may fail on some versions; treat as best-effort.
			_flushdns_run_root "$dry_run" killall -HUP mDNSResponder >/dev/null 2>&1 || true
			_flushdns_run_root "$dry_run" killall -HUP mDNSResponderHelper >/dev/null 2>&1 || true
			did=1
		fi

		if [[ "$did" -eq 0 ]]; then
			echo "flushdns: no known macOS DNS flush mechanisms available" >&2
			return 1
		fi

		return 0
	fi

	# --- Linux / other Unix ---
	if [[ "$status" -eq 1 ]]; then
		# Quick status without failing if tools aren't present.
		if _flushdns_has_cmd pgrep; then
			pgrep -af 'systemd-resolved|dnsmasq|nscd' 2>/dev/null || true
		elif _flushdns_has_cmd ps; then
			# shellcheck disable=SC2009
			ps aux 2>/dev/null | grep -E 'systemd-resolved|dnsmasq|nscd' | grep -v grep || true
		else
			echo "flushdns: ps not found" >&2
		fi
		return 0
	fi

	# Prefer flushing caches when systemd-resolved is present.
	if _flushdns_has_cmd resolvectl; then
		_flushdns_run_root "$dry_run" resolvectl flush-caches || return 1
	elif _flushdns_has_cmd systemd-resolve; then
		_flushdns_run_root "$dry_run" systemd-resolve --flush-caches || return 1
	fi

	# Optional restarts (some distros/services don't expose a flush command).
	if [[ "$restart" -eq 1 ]]; then
		if _flushdns_has_cmd systemctl; then
			# systemd-resolved
			if systemctl is-active systemd-resolved >/dev/null 2>&1; then
				_flushdns_run_root "$dry_run" systemctl restart systemd-resolved || return 1
			fi
			# dnsmasq
			if systemctl is-active dnsmasq >/dev/null 2>&1; then
				_flushdns_run_root "$dry_run" systemctl restart dnsmasq || return 1
			fi
			# nscd
			if systemctl is-active nscd >/dev/null 2>&1; then
				_flushdns_run_root "$dry_run" systemctl restart nscd || return 1
			fi
		fi

		# If nscd exists but isn't systemd-managed, invalidate hosts cache.
		if _flushdns_has_cmd nscd; then
			_flushdns_run_root "$dry_run" nscd -i hosts >/dev/null 2>&1 || true
		fi
	fi

	# If we didn't find any mechanism, be honest and helpful.
	if [[ "$restart" -eq 0 ]] && ! _flushdns_has_cmd resolvectl && ! _flushdns_has_cmd systemd-resolve; then
		echo "flushdns: no known DNS flush command found." >&2
		echo "Try: flushdns --restart  (or install/use systemd-resolved/resolvectl)" >&2
		return 1
	fi

	return 0
}

# Backward-compatible alias name.
alias flushDNS='flushdns'

# Allow running as a standalone script.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	flushdns "$@"
fi

