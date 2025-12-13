#!/usr/bin/env bash

#------------------------------------------------------------------------------
# Legacy filename wrapper (kept for compatibility).
# Canonical sysinfo module: sysinfo.sh
#------------------------------------------------------------------------------

# shellcheck shell=bash

__mbp_profile_d_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$__mbp_profile_d_dir/sysinfo.sh"
unset __mbp_profile_d_dir

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    sysinfo
fi
