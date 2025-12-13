#------------------------------------------------------------------------------
# extract helper (plugin-friendly entry point)
#------------------------------------------------------------------------------

# shellcheck shell=bash

__mbp_profile_d_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$__mbp_profile_d_dir/30-extract.sh"
unset __mbp_profile_d_dir
