#------------------------------------------------------------------------------
# gohome/stophome/make_ssh helpers (plugin-friendly entry point)
#------------------------------------------------------------------------------

# shellcheck shell=bash

__mbp_profile_d_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$__mbp_profile_d_dir/60-homevpn.sh"
unset __mbp_profile_d_dir
