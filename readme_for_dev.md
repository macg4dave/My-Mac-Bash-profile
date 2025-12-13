
# My-Mac-Bash-profile

A portable Bash login profile that keeps macOS niceties while remaining friendly on Linux workstations and headless servers.

This repo’s main entry point is `.bash_profile`, which optionally sources modules from `profile.d/`.

## Install

### Support matrix

This profile is intended to be safe to source on:

- **macOS**: the system `/bin/bash` (**Bash 3.2**) and common Homebrew Bash installs
- **Linux**: Bash (commonly 4.x+)

### Recommended install (symlink)

1. Clone this repo anywhere (e.g. `~/src/My-Mac-Bash-profile`).
2. Back up your current `~/.bash_profile` if you have one.
3. Symlink the repo’s `.bash_profile` into place.

Example (paths are just examples):

- Backup: move `~/.bash_profile` → `~/.bash_profile.bak`
- Symlink: link `<repo>/.bash_profile` → `~/.bash_profile`

After that, start a new **login** shell (or see “Reload” below).

### Optional installer script

If you prefer a repeatable install/upgrade flow, use `scripts/install.sh`.

What it does:

- Creates a symlink from `<repo>/.bash_profile` to `~/.bash_profile`.
- If a target already exists, it creates a timestamped backup (unless you pass `--no-backup`).
- It is idempotent (if the correct symlink is already in place, it does nothing).
- Supports `--dry-run` to show what it would do.

Optional (deploy a copy into your home directory):

- `--install-dir <path>` copies the runtime files (`.bash_profile`, `profile.d/`, `scripts/`) into a directory you choose, then symlinks `~/.bash_profile` to that installed copy.
  - This is useful if you don’t want to keep the git checkout around permanently.
  - Conservative by default: if the install dir already exists, the installer leaves it in place. Use `--force` to redeploy (and it will create a backup unless you pass `--no-backup`).

Example:

- Install into `~/.my-mac-bash-profile` and link `~/.bash_profile`:
  - `scripts/install.sh --install-dir "$HOME/.my-mac-bash-profile"`

Optional:

- `--bootstrap auto` runs `scripts/bootstrap-linux.sh` or `scripts/bootstrap-macos.sh` after installing.
- `--full` can be combined with Linux bootstrapping to request optional packages.

### Notes for terminal setup

- `.bash_profile` is read by **login** Bash shells.
- Many terminal apps can be configured to “Run command as login shell”. If your terminal launches non-login shells, you may want to source `~/.bash_profile` from `~/.bashrc` (or switch the terminal to login shells).

### Troubleshooting

- **Nothing seems to load**: confirm you’re running **Bash** (not zsh/fish) and that your terminal starts a **login** shell.
- **macOS says Bash is “old”**: that’s expected on stock macOS (`/bin/bash` is 3.2). This repo aims to remain compatible.
- **`netinfo` feels slow**: set `NETINFO_EXTERNAL_IP=0` to skip external IP lookup (it’s also cached by default).
- **A module broke shell startup**: start a clean Bash without reading profiles, then re-enable modules one by one.
  - Disable modules with `BASH_PROFILE_MODULES_DISABLE` (e.g. `netinfo`, `sysinfo`).
  - If you added local overrides, temporarily move/rename `profile.d/local.sh` (or the XDG config override file).


## Reload (without logging out)

In an interactive shell, you can reload changes with:

- `source ~/.bash_profile`

If you want a fresh login shell (closer to “real” startup behavior), start a new terminal or run:

- `bash -l`

## How it’s structured

- `.bash_profile` — resolves its own location (works even when symlinked) and sources modules.
- `profile.d/10-common.sh` — cross-platform helpers (OS detection, `has_cmd`, PATH helpers).
- `profile.d/osx.sh` — macOS-only helpers (guarded by `IS_MAC`).
- `profile.d/linux.sh` — Linux-only helpers (guarded by `IS_LINUX`).
- `profile.d/extract.sh` — `extract` function for common archive formats.
- `profile.d/sysinfo.sh` — provides a `sysinfo` helper (safe to source; also runnable directly).
- `profile.d/netinfo.sh` — provides a `netinfo` helper (safe to source; also runnable directly).
- `profile.d/flushdns.sh` — provides a `flushdns` helper (safe to source; also runnable directly).
- `profile.d/jdir.sh` — provides `jdir` / `jd` helpers (safe to source; also runnable directly).

## Modules, ordering, and local overrides

### Loader behavior

`.bash_profile` loads modules from `profile.d/`.

- If any **unnumbered** modules exist (e.g. `netinfo.sh`), the loader prefers those and loads them in glob order.
- Otherwise it loads legacy **numbered** modules (e.g. `10-common.sh`, `20-foo.sh`) in numeric order.

### Enable/disable modules (no forking)

You can control which modules are sourced via environment variables:

- `BASH_PROFILE_MODULES_DISABLE` — space- or comma-separated list of modules to skip.
- `BASH_PROFILE_MODULES_ENABLE` — if set, only modules in this list will be loaded.

Entries may be either the stem (`netinfo`) or filename (`netinfo.sh`).

### Local overrides

To customize without committing changes, add one of these files (they are sourced **last** if present):

1. `<repo>/profile.d/local.sh` (recommended; this repo ignores it via `.gitignore`)
2. `${XDG_CONFIG_HOME:-~/.config}/my-mac-bash-profile/local.sh`

## Included helpers

- `extract <archive> [dest]` — extract many archive types into a folder (supports `--list`, `--force`, `--verbose`). Includes basic tab completion for flags and paths in interactive Bash.
- `sysinfo` — show a compact one-line system summary (OS, disk, uptime, load, CPU, RAM, network counters).
- `netinfo` — show a small network summary (default route/interface, local IP, Wi-Fi SSID when available, VPN interfaces, cached external IP).
- `flushdns` — best-effort DNS cache flush helper (macOS + common Linux setups).
- `jdir` / `jd` — friendly wrappers around `wget` (recursive directory download vs. single URL resume).
- `cdf` (macOS) — `cd` to the front Finder window.
- `gosu` (macOS) — open a Terminal tab that switches to a root shell.

## Machine-readable output (`--kv`)

Some helpers support a simple scripting mode:

- `--kv` prints **one `key=value` per line**.
- Missing data or missing optional dependencies should result in `N/A` (or `none` where noted), not noisy errors.

### `sysinfo --kv`

Keys (stable order):

- `os` (e.g. `Linux`, `Darwin`)
- `os_version` (Linux kernel version, or macOS product version)
- `boot_volume`
- `volume_size`
- `volume_used`
- `volume_free`
- `uptime`
- `load_avg`
- `cpu_user` (percent, numeric)
- `cpu_sys` (percent, numeric)
- `cpu_idle` (percent, numeric)
- `ram_used`
- `ram_free`
- `ram_total`
- `net_rx` (best-effort network RX counter, human-readable bytes)
- `net_tx` (best-effort network TX counter, human-readable bytes)

### `netinfo --kv`

Keys (stable order):

- `os`
- `default_interface`
- `gateway`
- `local_ip`
- `wifi_ssid`
- `vpn_interfaces` (`none` if none detected)
- `external_ip` (cached; set `NETINFO_EXTERNAL_IP=0` to disable lookup)

## Environment variable cheat-sheet

| Variable | Default | Meaning |
| --- | --- | --- |
| `BASH_PROFILE_CD_LS` | `1` | If set to `0`, disables the convenience behavior in `profile.d/10-common.sh` that runs `ls -hla` after each successful `cd` (interactive shells only). |
| `BASH_PROFILE_MODULES_DISABLE` | empty | Space- or comma-separated list of modules to skip (by stem or filename). |
| `BASH_PROFILE_MODULES_ENABLE` | empty | If set, only modules in this list will be loaded (by stem or filename). |
| `IS_MAC` | auto | Set by the profile to `true`/`false` based on `uname -s` (intended as a read-only flag for gating macOS-only behavior). |
| `IS_LINUX` | auto | Set by the profile to `true`/`false` based on `uname -s` (intended as a read-only flag). |
| `NETINFO_EXTERNAL_IP` | `1` | If set to `0`, `netinfo` will skip external IP lookup (useful for offline environments). |
| `NETINFO_EXTERNAL_IP_TTL` | `300` | External IP cache TTL in seconds for `netinfo`. |
| `NETINFO_WIFI_DEVICE` | `en0` | macOS Wi‑Fi device used by `netinfo` (only relevant on macOS). |

## Notes

- macOS-only bits are guarded so they won’t break Linux shell startup.
- If you want different alias defaults (e.g., `ls` flags), adjust them in `.bash_profile`.

## Dev tooling

### Lint

Run ShellCheck across the profile and scripts:

- `make lint`

### Smoke test

- `make test`
- Runs in a temporary `HOME` and uses `--dry-run` where applicable, so it should not touch your real dotfiles or install anything.

### Releases

- `CHANGELOG.md` tracks changes; when you cut releases, tag them as `vX.Y.Z`.

## Bootstrap scripts

Best-effort dependency installers live in `scripts/`:

- `scripts/bootstrap-linux.sh` (supports `--full` and `--dry-run`)
- `scripts/bootstrap-macos.sh` (supports `--dry-run`)
