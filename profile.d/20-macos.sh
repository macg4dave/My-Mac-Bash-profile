#------------------------------------------------------------------------------
# Legacy filename wrapper (kept for compatibility).
# Canonical macOS module: osx.sh
#------------------------------------------------------------------------------

# shellcheck shell=bash

__mbp_profile_d_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$__mbp_profile_d_dir/osx.sh"
unset __mbp_profile_d_dir
