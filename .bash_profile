#!/usr/bin/env bash

#------------------------------------------------------------------------------
# Bash login profile (portable: macOS + Linux)
#
# This file is typically symlinked to ~/.bash_profile.
# It sources optional modules from ./profile.d/.
#------------------------------------------------------------------------------

# Resolve this file's directory even when ~/.bash_profile is a symlink.
__bp_source="${BASH_SOURCE[0]}"
while [[ -L "$__bp_source" ]]; do
	__bp_dir="$(cd -P -- "$(dirname -- "$__bp_source")" && pwd)"
	__bp_link="$(readlink -- "$__bp_source")" || break
	[[ "$__bp_link" != /* ]] && __bp_link="$__bp_dir/$__bp_link"
	__bp_source="$__bp_link"
done
__bp_root="$(cd -P -- "$(dirname -- "$__bp_source")" && pwd)"

__bp_profile_d="$__bp_root/profile.d"

# Source common helpers first (defines has_cmd + IS_MAC/IS_LINUX + PATH helpers).
if [[ -r "$__bp_profile_d/10-common.sh" ]]; then
	# shellcheck source=/dev/null
	source "$__bp_profile_d/10-common.sh"
fi

#---------------
## Export PATHS
#---------------

export PS1="\[\e[36;40m\]\u\[\e[m\]\[\e[35m\]@\[\e[m\][\[\e[33m\]\h\[\e[m\]]\[\e[36m\]\w\[\e[m\]: "

# macOS color env is harmless elsewhere, but only set when on macOS.
if ${IS_MAC:-false}; then
	export CLICOLOR=1
	export LSCOLORS=ExFxBxDxCxegedabagacad
	export BASH_SILENCE_DEPRECATION_WARNING=1
fi

# PATH hygiene: only prepend directories that exist.
if declare -F path_prepend_if_exists >/dev/null 2>&1; then
	path_prepend_if_exists "/usr/local/opt/cython/bin"
	path_prepend_if_exists "/usr/local/sbin"
	path_prepend_if_exists "/opt/local/bin"
	path_prepend_if_exists "/opt/local/sbin"
else
	export PATH="/usr/local/opt/cython/bin:$PATH"
	export PATH="/usr/local/sbin:$PATH"
	export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
fi



#--------
## Alias
#---------

if ${IS_MAC:-false}; then
	alias ls='ls -GFhla'
	alias flushDNS='dscacheutil -flushcache'
else
	# GNU ls: keep similar UX.
	alias ls='ls --color=auto -Fhla'
	alias flushDNS='echo "flushDNS is only supported on macOS (dscacheutil)." >&2; false'
fi

alias jdir='wget -r -c --no-parent '
alias jd='wget -c '
alias checkip='curl ipinfo.io'

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
			# shellcheck source=/dev/null
			source "$__bp_f"
		done
	else
		for __bp_f in "$__bp_profile_d"/[0-9][0-9]-*.sh; do
			[[ -r "$__bp_f" ]] || continue
			[[ "$__bp_f" == "$__bp_profile_d/10-common.sh" ]] && continue
			# shellcheck source=/dev/null
			source "$__bp_f"
		done
	fi
	unset __bp_has_unnumbered

	if [[ "$__bp_nullglob_was_set" -eq 1 ]]; then
		shopt -s nullglob
	else
		shopt -u nullglob
	fi
	unset __bp_nullglob_was_set
fi

unset __bp_source __bp_dir __bp_link __bp_root __bp_profile_d __bp_f

#-----------------------------------
## END
#-----------------------------------

