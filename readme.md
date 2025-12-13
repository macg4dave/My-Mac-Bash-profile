
# My-Mac-Bash-profile

A portable Bash login profile that keeps macOS niceties while remaining friendly on Linux workstations and headless servers.

This repo’s main entry point is `.bash_profile`, which optionally sources modules from `profile.d/`.

## Install


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
