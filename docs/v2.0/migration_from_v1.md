---
title: Migration from v1 (to v2)
repo: My-Mac-Bash-profile
doc_version: v2.0
---

<!-- markdownlint-disable MD025 -->

# Migration from v1 → v2

v2 is designed to be a low-drama upgrade: it keeps the same “portable `.bash_profile` + small helpers” shape, and it tightens contracts (safety, CLI flags, machine output) rather than introducing a new framework.

## What stays the same

- Entry point remains **`.bash_profile`**.
- Helpers remain small Bash-first commands.
- Supported baseline still includes **macOS `/bin/bash` 3.2**.
- Helper names remain stable: `sysinfo`, `netinfo`, `extract`, `flushdns`, `jd`, `jdir`.

## What’s new in v2

### Helper scripting support (`--kv`)

`sysinfo` and `netinfo` support a stable machine-readable mode:

- `sysinfo --kv`
- `netinfo --kv`

Key order and key names are defined in `docs/v2.0/helper_contract.md` and enforced by `tests/helper_contract.sh`.

### Module toggles (no file edits required)

You can disable modules without editing tracked files:

- `BASH_PROFILE_MODULES_DISABLE="netinfo extract"`

Or allowlist modules:

- `BASH_PROFILE_MODULES_ENABLE="sysinfo"`

Both accept either bare names or filenames (e.g., `netinfo` or `netinfo.sh`).

### Local overrides

Two optional override files are sourced **last** if present:

1. `<repo>/profile.d/local.sh` (recommended; typically git-ignored)
2. `${XDG_CONFIG_HOME:-~/.config}/my-mac-bash-profile/local.sh`

This is the preferred v2 method for per-machine tweaks.

### Installer improvements

`scripts/install.sh` supports:

- `--dry-run` (prints changes without writing)
- safe backups by default
- install into `~/.my-mac-bash-profile` (copy) or `--link-repo` (symlink to checkout)

## Upgrade steps

1. Update your checkout (or re-download the repo).

2. Re-run the installer (recommended):

- If you want the conservative “copy install” mode: run `scripts/install.sh --repo <path>`
- If you prefer linking directly to the checkout: run `scripts/install.sh --repo <path> --link-repo`

3. Open a new terminal (or `source ~/.bash_profile`).

4. If anything feels off, temporarily disable modules:

- `export BASH_PROFILE_MODULES_DISABLE="netinfo"`

## Breaking changes in v2

v2’s default intent is “no surprises”. If something is ever changed in a way that can break scripts or muscle memory, it must be treated as a breaking change and documented per:

- `docs/v2.0/compatibility_contract.md`
- `docs/v2.0/deprecation_policy.md`

## Migration table (P0.4)

At the time of writing, no helper/module renames are required.

| v1 name | v2 name | Notes |
|---|---|---|
| `sysinfo` | `sysinfo` | Stable |
| `netinfo` | `netinfo` | Stable |
| `extract` | `extract` | Stable |
| `flushdns` | `flushdns` | Stable |
| `jd` | `jd` | Stable |
| `jdir` | `jdir` | Stable |
