#------------------------------------------------------------------------------
# Legacy filename wrapper (kept for compatibility).
# Canonical extract module: extract.sh
#------------------------------------------------------------------------------

# shellcheck shell=bash

__mbp_profile_d_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$__mbp_profile_d_dir/extract.sh"
unset __mbp_profile_d_dir
