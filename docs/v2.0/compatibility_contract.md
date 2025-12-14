---
title: Compatibility Contract (v2)
repo: My-Mac-Bash-profile
doc_version: v2.0
---

# Compatibility contract (v2)

This document defines what “compatible” means for this repo: what we support, what we test, and what we consider a breaking change.

## Supported vs best-effort

### Supported (must keep working)

- **Bash**: macOS system `/bin/bash` (**3.2**) and modern Linux Bash (4.x+).
- **OS**: macOS (current macOS runner in CI) and Linux (current Ubuntu runner in CI).
- **Sourcing safety**: `source ~/.bash_profile` must not error, prompt, or hang.
- **Install paths**:
  - symlink install: `<repo>/.bash_profile` → `~/.bash_profile`
  - installer deploy: `scripts/install.sh` installs into `~/.my-mac-bash-profile` and links `~/.bash_profile`

### Best-effort (should work, but not guaranteed)

- Linux distros other than the CI baseline, including **Debian** and **Fedora**.
- Environments missing optional tools (helpers should degrade gracefully to `N/A`).

## Hard guarantees (contracts)

### 1) Safe-to-source contract (non-negotiable)

When `.bash_profile` and `profile.d/*.sh` are sourced:

- No network calls.
- No interactive prompts.
- No long-running commands.
- No heavy subprocess pipelines.
- No writes outside normal shell behavior (no caches/config writes on source).

Anything that needs work must happen only when the user calls a helper (e.g., `netinfo`, `sysinfo`, `extract`).

### 2) Portability contract

- No Bash 4+ only syntax in code that is sourced by default (macOS Bash 3.2 compatibility).
  - Examples to avoid: associative arrays, `${var,,}`, `mapfile`, `globstar`, `declare -A`.
- Avoid GNU-only flags and behaviors where BSD tools differ (especially on macOS).
- OS-specific functionality must be guarded (by OS and/or `command -v` checks) and fail softly.

### 3) Helper behavior contract

For “core helpers” (currently: `sysinfo`, `netinfo`, `extract`, `flushdns`, `jd`, `jdir`):

- `--help` prints usage and exits 0.
- Unknown options exit 2 and print an error to stderr.
- Failures exit 1 and print an error to stderr.
- If an optional dependency is missing, output should degrade to `N/A` (or a clear message if the tool is required for the requested operation).
- Any machine-readable mode must be stable and conservative (baseline: `--kv` with `key=value` lines).
- The details and helper-by-helper inventory live in `docs/v2.0/helper_contract.md`, and `tests/helper_contract.sh` exercises every helper’s `--help` path plus the `--kv` ordering to keep this contract enforced in CI.

## Compatibility matrix (current)

### Shells

| Shell | Status | Notes |
|---|---:|---|
| Bash 3.2 (macOS `/bin/bash`) | Supported | Lowest common denominator; constrains syntax and completion patterns. |
| Bash 4.x+ (Linux) | Supported | Keep compatibility with Bash 3.2 anyway unless explicitly documented otherwise. |
| zsh | Not supported | macOS default shell; this repo targets Bash. Users can run `bash -l` if desired. |

### Operating systems

| OS | Status | Notes |
|---|---:|---|
| macOS | Supported | Must be safe on stock system tools + Bash 3.2. |
| Debian | Best-effort | Should work with standard packages; watch for missing `iwgetid`, `unrar`, `p7zip`. |
| Fedora | Best-effort | Terminals often start non-login shells; installer helps by sourcing `.bash_profile` from `.bashrc`. |

## macOS details

### Shell behavior

- `.bash_profile` is loaded for **login** shells.
- Many macOS terminals default to zsh; for Bash, run `bash -l` or set the terminal to start Bash as a login shell.

### Expected tools (best-effort)

Used only when helpers are invoked (not on source):

- `sysinfo`: `sw_vers`, `sysctl`, `vm_stat`, `top`, `diskutil` (all typically present), and optionally `numfmt` (usually not present unless coreutils installed).
- `netinfo`: `route`, `ipconfig`, `networksetup`, `ifconfig` (typically present). External IP lookup uses `curl` if present (macOS ships `curl`).
- `extract`: `/usr/bin/tar` (bsdtar), `unzip` (usually present). `7z` / `unrar` may require Homebrew.
- `flushdns`: varies by macOS version; implementation must remain best-effort and guarded.

### BSD vs GNU differences (important)

- Do not assume GNU flags (for example, avoid requiring `readlink -f`, `sed -r`, `xargs -r`, `stat -c`, GNU `date`).
- Prefer portable patterns and guard where needed.

## Debian details

### Shell / login shell notes

- Many terminals start interactive **non-login** shells, which read `~/.bashrc` not `~/.bash_profile`.
- `scripts/install.sh` can add a guarded snippet to `~/.bashrc` to source `~/.bash_profile` for interactive non-login shells.

### Packages commonly needed for optional features

Not required for sourcing; only affects helper richness.

- `iproute2` (provides `ip`) for `netinfo`.
- `curl` or `wget` for `netinfo` external IP lookup.
- `p7zip-full` (provides `7z`) for `.7z` extraction support.
- `unrar` may be in non-free repositories depending on Debian configuration.

## Fedora details

### Shell / login shell notes

- Fedora commonly launches interactive **non-login** shells (so `~/.bashrc` matters).
- The installer’s `.bashrc` snippet is considered compatible on Fedora and is guarded to avoid recursion.

### Packages commonly needed for optional features

- `iproute` (provides `ip`) for `netinfo` (typically installed).
- `curl` is usually installed; `wget` may or may not be.
- `p7zip` provides `7z` support; `unrar` availability depends on enabled repos.

## What counts as a breaking change

Any of the following is a breaking change:

- `.bash_profile` fails to source on macOS Bash 3.2 or on Linux Bash.
- New network access, prompts, or noticeable latency during sourcing.
- Renaming/removing a helper that existed without a clear deprecation/migration path.
- Changing `--kv` keys or meaning without a deprecation window.
- Making install/uninstall destructive by default (overwriting dotfiles without backups/opt-in).

## Testing expectations

This repo’s compatibility baseline is enforced by:

- `make lint` (ShellCheck)
- `make test` (smoke + perf + guard scripts that source the profile in a temp HOME)
- `tests/perf-startup.sh`, which measures `source ~/.bash_profile` and fails if the Linux baseline exceeds the 0.9 s budget.
- `tests/safe-source.sh`, which stubs dangerous commands and confirms sourcing the profile leaves only the documented XDG/cached files behind.
- `tests/missing-deps.sh`, which hides optional utilities via a `command` shim and checks that `netinfo`/`sysinfo` still exit cleanly while emitting `N/A` for the blocked fields.
- CI on Linux + macOS runners
