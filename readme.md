
# My-Mac-Bash-profile

A portable Bash login profile that keeps macOS niceties while remaining friendly on Linux workstations and headless servers.

This repo’s main entry point is `.bash_profile`, which optionally sources modules from `profile.d/`.

## Install

The intended setup is to **symlink** this repo’s `.bash_profile` into your home directory.

- Back up any existing profile first.
- Create a symlink so updates via `git pull` are picked up automatically.

## Reload (without logging out)

In an interactive shell, you can reload changes with:

- `source ~/.bash_profile`

If you want a fresh login shell (closer to “real” startup behavior), start a new terminal or run:

- `bash -l`

## How it’s structured

- `.bash_profile` — resolves its own location (works even when symlinked) and sources modules.
- `profile.d/10-common.sh` — cross-platform helpers (OS detection, `has_cmd`, PATH helpers).
- `profile.d/20-macos.sh` — macOS-only helpers (guarded by `IS_MAC`).
- `profile.d/30-extract.sh` — `extract` function for common archive formats.
- `profile.d/40-sysinfo.sh` — provides a `sysinfo` helper (safe to source; also runnable directly).
- `profile.d/50-netinfo.sh` — provides a `netinfo` helper (safe to source; also runnable directly).
- `profile.d/60-homevpn.sh` — provides `gohome`/`stophome` (sshuttle wrapper) and `make_ssh`.

Legacy, unnumbered module filenames (e.g., `profile.d/sysinfo.sh`) are kept as thin wrappers for compatibility.

Modules are loaded in lexical order; `10-common.sh` is sourced first.

## Included helpers

- `extract <archive> [dest]` — extract many archive types into a folder (supports `--list`, `--force`, `--verbose`).
- `sysinfo` — show a compact one-line system summary (OS, disk, uptime, load, CPU, RAM, network counters).
- `netinfo` — show a small network summary (default route/interface, local IP, Wi‑Fi SSID when available, VPN interfaces, cached external IP).
- `make_ssh <alias> <hostname> [user] [port] [identity_file]` — append a safe SSH config stanza to `~/.ssh/config` (or use `--dry-run`).
- `gohome` / `stophome` — start/stop an `sshuttle` VPN using env var configuration.
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
| `GOHOME_REMOTE` | unset | Remote for `sshuttle`, e.g. `user@bastion.example.com`. |
| `GOHOME_SUBNETS` | unset | Space-separated CIDRs to route, e.g. `10.0.0.0/8 192.168.0.0/16`. |
| `GOHOME_SSH_PORT` | unset | Optional SSH port for `GOHOME_REMOTE`. |
| `GOHOME_SSH_KEY` | unset | Optional SSH identity file path for `gohome`. |
| `GOHOME_DNS` | `0` | If set to `1`, passes `--dns` to `sshuttle`. |
| `GOHOME_SUDO` | `1` | If set to `0`, runs `sshuttle`/`kill` without `sudo`. |

## Notes

- macOS-only bits are guarded so they won’t break Linux shell startup.
- If you want different alias defaults (e.g., `ls` flags), adjust them in `.bash_profile`.

