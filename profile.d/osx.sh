#------------------------------------------------------------------------------
# macOS helpers (plugin-friendly entry point)
#------------------------------------------------------------------------------

# shellcheck shell=bash

# Source the legacy numbered module for compatibility.
__mbp_profile_d_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$__mbp_profile_d_dir/20-macos.sh"
unset __mbp_profile_d_dir
