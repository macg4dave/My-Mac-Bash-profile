#------------------------------------------------------------------------------
# Linux helpers (plugin-friendly entry point)
#------------------------------------------------------------------------------

# shellcheck shell=bash

[[ "${IS_LINUX:-false}" == "true" ]] || return 0

# Placeholder for Linux-specific helpers.
# Keep this file safe to source on any host and avoid hard dependencies.
