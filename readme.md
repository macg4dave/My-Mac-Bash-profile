
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

### Notes for terminal setup

- `.bash_profile` is read by **login** Bash shells.
- Many terminal apps can be configured to “Run command as login shell”. If your terminal launches non-login shells, you may want to source `~/.bash_profile` from `~/.bashrc` (or switch the terminal to login shells).

### Troubleshooting

- **Nothing seems to load**: confirm you’re running **Bash** (not zsh/fish) and that your terminal starts a **login** shell.
- **macOS says Bash is “old”**: that’s expected on stock macOS (`/bin/bash` is 3.2). This repo aims to remain compatible.
- **`netinfo` feels slow**: set `NETINFO_EXTERNAL_IP=0` to skip external IP lookup (it’s also cached by default).


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

## Included helpers

- `extract <archive> [dest]` — extract many archive types into a folder (supports `--list`, `--force`, `--verbose`).
- `sysinfo` — show a compact one-line system summary (OS, disk, uptime, load, CPU, RAM, network counters).
- `netinfo` — show a small network summary (default route/interface, local IP, Wi‑Fi SSID when available, VPN interfaces, cached external IP).
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

## Bootstrap scripts

Best-effort dependency installers live in `scripts/`:

- `scripts/bootstrap-linux.sh` (supports `--full` and `--dry-run`)
- `scripts/bootstrap-macos.sh` (supports `--dry-run`)
