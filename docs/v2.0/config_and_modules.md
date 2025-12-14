---
title: Config + module lifecycle (v2)
repo: My-Mac-Bash-profile
doc_version: v2.0
---

<!-- markdownlint-disable MD025 -->

# Config + module lifecycle (v2)

v2 configuration is intentionally boring: **env vars + optional local override files**. There is no plugin manager, no registry, and nothing needs to be “installed” to enable a module.

## Sources of configuration (P3.1)

v2 uses:

1. **Environment variables** (the primary “config API”)
2. **Optional local override files** (for per-machine tweaks)

This keeps bootstrap dependency-free and works on macOS Bash 3.2.

## Precedence rules (P3.2)

When `.bash_profile` is sourced:

1. The profile loads modules from `profile.d/`.
2. Local override files are sourced **last**, in this order:
   1. `<repo>/profile.d/local.sh`
   2. `${XDG_CONFIG_HOME:-~/.config}/my-mac-bash-profile/local.sh`

Later sources win (they can override aliases/functions/vars).

## Module discovery + ordering (P3.4)

- `profile.d/10-common.sh` is loaded first (it defines `has_cmd`, `IS_MAC`/`IS_LINUX`, and PATH helpers).
- Then `.bash_profile` loads the remaining `profile.d/*.sh` modules.

Ordering rule:

- If any **unnumbered** modules exist in `profile.d/` (e.g., `sysinfo.sh`), the loader prefers those and ignores legacy numbered modules (`NN-*.sh`).
- Otherwise it loads legacy numbered modules in order.

This provides backward compatibility while allowing a “plugin-friendly” unnumbered layout.

## Enabling / disabling modules (P3 deliverable)

Two environment variables control module loading:

- `BASH_PROFILE_MODULES_ENABLE` (allowlist)
- `BASH_PROFILE_MODULES_DISABLE` (denylist)

Rules:

- Values can be **space- or comma-separated**.
- Entries can be either the stem (`netinfo`) or filename (`netinfo.sh`).
- If `BASH_PROFILE_MODULES_ENABLE` is set, only those modules load.
- Then `BASH_PROFILE_MODULES_DISABLE` is applied to remove modules.

Examples:

- Disable a module:
  - `export BASH_PROFILE_MODULES_DISABLE="netinfo"`
- Load only one module:
  - `export BASH_PROFILE_MODULES_ENABLE="sysinfo"`

## Module metadata conventions (lightweight)

v2 does not require a formal metadata registry. Instead, modules follow simple conventions:

- **OS-specific logic must be guarded** (e.g., `[[ "${IS_MAC:-false}" == "true" ]] || return 0`).
- **Optional dependencies must be checked** via `command -v ...` or `has_cmd ...`.
- Modules should be **safe to source** (define functions/vars; do not perform work).

## Troubleshooting (P3.5)

### A module broke startup

1. Start a new shell with the module disabled:

- `export BASH_PROFILE_MODULES_DISABLE="<module>"`

1. If needed, temporarily allowlist only `10-common.sh` + one helper and add modules back one at a time.

### Figure out what’s loaded

Run:

- `mm_bash_profile_doctor` (or `mm-bash-profile-doctor`)

This prints effective env-var configuration, helper availability, and whether override files are present.
