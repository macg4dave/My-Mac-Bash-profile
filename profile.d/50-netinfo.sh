#!/usr/bin/env bash

#------------------------------------------------------------------------------
# Legacy filename wrapper (kept for compatibility).
# Canonical netinfo module: netinfo.sh
#------------------------------------------------------------------------------

# shellcheck shell=bash

__mbp_profile_d_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$__mbp_profile_d_dir/netinfo.sh"
unset __mbp_profile_d_dir

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    netinfo
fi
