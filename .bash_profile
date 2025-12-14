#!/usr/bin/env bash

#------------------------------------------------------------------------------
## Aliases and environment variables
# Common convenience aliases and environment variable exports.
# Easy to remember aliases for common commands.
#------------------------------------------------------------------------------

if ${IS_MAC:-false}; then
	alias ls='ls -GFhla'
else
	# GNU ls: keep similar UX.
	alias ls='ls --color=auto -Fhla'
fi


#------------------------------------------------------------------------------
## Export PATHS
# Common PATH exports and hygiene.
#------------------------------------------------------------------------------

if [[ "${BASH_PROFILE_SET_PS1:-1}" != "0" ]]; then
	export PS1="\[\e[36;40m\]\u\[\e[m\]\[\e[35m\]@\[\e[m\][\[\e[33m\]\h\[\e[m\]]\[\e[36m\]\w\[\e[m\]: "
fi

# macOS color env is harmless elsewhere, but only set when on macOS.
if ${IS_MAC:-false}; then
	export CLICOLOR=1
	export LSCOLORS=ExFxBxDxCxegedabagacad
	export BASH_SILENCE_DEPRECATION_WARNING=1
fi

# PATH hygiene: only prepend directories that exist.
if declare -F path_prepend_if_exists >/dev/null 2>&1; then
	path_prepend_if_exists "/usr/local/sbin"
	path_prepend_if_exists "/opt/local/bin"
	path_prepend_if_exists "/opt/local/sbin"
	path_prepend_if_exists "/usr/local/opt/curl/bin"
	path_prepend_if_exists "/usr/local/opt/cython/bin"
else
	export PATH="/usr/local/sbin:$PATH"
	export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
fi

#------------------------------------------------------------------------------
# Bash login profile (portable: macOS + Linux)
#
# This file is typically symlinked to ~/.bash_profile.
# It sources optional modules from ./profile.d/.
#------------------------------------------------------------------------------

# Resolve this file's directory even when ~/.bash_profile is a symlink.
__bp_source="${BASH_SOURCE[0]}"
while [[ -L "$__bp_source" ]]; do
	__bp_dir="$(cd -P -- "$(dirname "$__bp_source")" && pwd)"
	__bp_link="$(readlink "$__bp_source" 2>/dev/null)" || break
	[[ "$__bp_link" != /* ]] && __bp_link="$__bp_dir/$__bp_link"
	__bp_source="$__bp_link"
done
__bp_root="$(cd -P -- "$(dirname "$__bp_source")" && pwd)"

__bp_profile_d="$__bp_root/profile.d"

#------------------------------------------------------------------------------
# Surpess bash deprecation warning on macOS
#------------------------------------------------------------------------------

export BASH_SILENCE_DEPRECATION_WARNING=1

#------------------------------------------------------------------------------
# Module loader configuration
#
# - By default, all modules in profile.d/ are loaded.
# - You can disable modules without editing this repo by setting:
#     BASH_PROFILE_MODULES_DISABLE="netinfo sysinfo"   (names or filenames)
# - You can allowlist modules (load only these) with:
#     BASH_PROFILE_MODULES_ENABLE="extract netinfo"
# - Lists may be space- or comma-separated. Entries may be either:
#     netinfo    OR    netinfo.sh
#
# Local overrides are sourced last (if present):
#   1) <repo>/profile.d/local.sh                (recommended; gitignored)
#   2) ${XDG_CONFIG_HOME:-~/.config}/my-mac-bash-profile/local.sh
#------------------------------------------------------------------------------

__bp_modules_enable="${BASH_PROFILE_MODULES_ENABLE:-}"
__bp_modules_disable="${BASH_PROFILE_MODULES_DISABLE:-}"

# shellcheck disable=SC2329
__bp_is_interactive() {
	[[ $- == *i* ]]
}

# shellcheck disable=SC2329
__bp_warn() {
	# Warnings must be interactive-only to avoid breaking scripts.
	__bp_is_interactive || return 0
	printf '%s\n' "$*" >&2
}

# shellcheck disable=SC2329
__bp_deprecated_env() {
	# Usage: __bp_deprecated_env OLD_ENV NEW_ENV
	# If OLD_ENV is set and NEW_ENV is not, copy the value and warn.
	local old_name="$1"
	local new_name="$2"
	# Indirect expansion: safe in Bash 3.2.
	local old_val="${!old_name-}"
	local new_val="${!new_name-}"

	[[ -n "$old_val" ]] || return 0
	[[ -z "$new_val" ]] || return 0

	export "${new_name}=${old_val}"
	__bp_warn "my-mac-bash-profile: '$old_name' is deprecated; use '$new_name' instead"
}

__bp_list_contains_any() {
	# Usage: __bp_list_contains_any "list" candidate1 [candidate2 ...]
	local list="$1"
	shift
	local token candidate
	list="${list//,/ }"
	for token in $list; do
		for candidate in "$@"; do
			[[ "$token" == "$candidate" ]] && return 0
		done
	done
	return 1
}

__bp_should_source_module() {
	local path="$1"
	local base stem
	base="$(basename "$path")"
	stem="${base%.sh}"

	# Local overrides are handled explicitly at the end.
	[[ "$base" == "local.sh" ]] && return 1

	if [[ -n "$__bp_modules_enable" ]]; then
		__bp_list_contains_any "$__bp_modules_enable" "$stem" "$base" || return 1
	fi
	if [[ -n "$__bp_modules_disable" ]]; then
		__bp_list_contains_any "$__bp_modules_disable" "$stem" "$base" && return 1
	fi
	return 0
}

# Source common helpers first (defines has_cmd + IS_MAC/IS_LINUX + PATH helpers).
if [[ -r "$__bp_profile_d/10-common.sh" ]]; then
	# shellcheck source=/dev/null
	source "$__bp_profile_d/10-common.sh"
fi


#------------------------------------------------------------------------------
# Load remaining modules (if present).
#------------------------------------------------------------------------------
if [[ -d "$__bp_profile_d" ]]; then
	__bp_nullglob_was_set=0
	shopt -q nullglob && __bp_nullglob_was_set=1
	shopt -s nullglob

	# Plugin-friendly mode: if unnumbered modules exist, prefer those.
	# Backward-compatible mode: otherwise load legacy numbered modules.
	__bp_has_unnumbered=0
	for __bp_f in "$__bp_profile_d"/*.sh; do
		[[ -r "$__bp_f" ]] || continue
		case "$__bp_f" in
			"$__bp_profile_d"/[0-9][0-9]-*.sh) continue ;;
		esac
		__bp_has_unnumbered=1
		break
	done

	if [[ "$__bp_has_unnumbered" -eq 1 ]]; then
		for __bp_f in "$__bp_profile_d"/*.sh; do
			[[ -r "$__bp_f" ]] || continue
			case "$__bp_f" in
				"$__bp_profile_d"/[0-9][0-9]-*.sh) continue ;;
			esac
			__bp_should_source_module "$__bp_f" || continue
			# shellcheck source=/dev/null
			source "$__bp_f"
		done
	else
		for __bp_f in "$__bp_profile_d"/[0-9][0-9]-*.sh; do
			[[ -r "$__bp_f" ]] || continue
			[[ "$__bp_f" == "$__bp_profile_d/10-common.sh" ]] && continue
			__bp_should_source_module "$__bp_f" || continue
			# shellcheck source=/dev/null
			source "$__bp_f"
		done
	fi
	unset __bp_has_unnumbered

	# Local override modules (sourced last).
	if [[ -r "$__bp_profile_d/local.sh" ]]; then
		# shellcheck source=/dev/null
		source "$__bp_profile_d/local.sh"
	fi
	__bp_xdg_local="${XDG_CONFIG_HOME:-$HOME/.config}/my-mac-bash-profile/local.sh"
	if [[ -r "$__bp_xdg_local" ]]; then
		# shellcheck source=/dev/null
		source "$__bp_xdg_local"
	fi
	unset __bp_xdg_local

	if [[ "$__bp_nullglob_was_set" -eq 1 ]]; then
		shopt -s nullglob
	else
		shopt -u nullglob
	fi
	unset __bp_nullglob_was_set
fi

unset __bp_source __bp_dir __bp_link __bp_root __bp_profile_d __bp_f __bp_modules_enable __bp_modules_disable
unset -f __bp_list_contains_any __bp_should_source_module __bp_is_interactive __bp_warn __bp_deprecated_env 2>/dev/null || true

#-----------------------------------
## END
#-----------------------------------

