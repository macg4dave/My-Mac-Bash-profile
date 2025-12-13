# My-Mac-Bash-profile

A portable **Bash** login profile that keeps a few macOS niceties while staying friendly on Linux workstations and headless servers.

If you just want a simple way to get useful helpers like `sysinfo`, `netinfo`, and `extract` in your Bash login shell—this is it.

## Who this is for (especially on macOS)

- You use **Bash** (either macOS `/bin/bash` or Homebrew Bash)
- You want a profile you can **symlink** and keep under version control
- You want it to be **safe to source** (no prompts; no surprise installs)

> macOS note: Apple’s default interactive shell is **zsh**. This repo targets **Bash login shells** (i.e., what reads `~/.bash_profile`). You can still use it by running `bash -l`, or configuring your terminal to start Bash as a login shell.

## Install (recommended)

You have two options. The symlink approach is the simplest and most transparent.

### Option A — Symlink (fastest, easiest)

1. Clone this repo anywhere (example path below):

   - `~/src/My-Mac-Bash-profile`

2. Back up your existing profile (if you have one):

   - `mv ~/.bash_profile ~/.bash_profile.bak`

3. Symlink the repo’s `.bash_profile` into place:

   - `ln -s ~/src/My-Mac-Bash-profile/.bash_profile ~/.bash_profile`

4. Start a new **login** Bash shell:

   - open a new terminal window/tab, or
   - run: `bash -l`

### Option B — Installer script (repeatable upgrades)

If you prefer an idempotent “install/upgrade” workflow, use `scripts/install.sh`.

Common usage:

- Dry-run (shows what it would do):
  - `scripts/install.sh --repo "$(pwd)" --dry-run`

- Install (recommended default):
  - Copies the runtime files into `~/.my-mac-bash-profile`
  - Symlinks `~/.bash_profile` to that installed copy
  - Runs the appropriate bootstrap script for your OS
  - `scripts/install.sh --repo "$(pwd)"`

If you want to **skip bootstrapping** (no package installs), add:

- `scripts/install.sh --repo "$(pwd)" --bootstrap none`

Optional: install a copy into a directory (useful if you don’t want to keep the git checkout around):

- `scripts/install.sh --repo "$(pwd)" --install-dir "$HOME/.my-mac-bash-profile"`

If you prefer the old behavior (symlink directly to the git checkout, no copy), use:

- `scripts/install.sh --repo "$(pwd)" --link-repo`

## Reload (without logging out)

In an existing Bash shell:

- `source ~/.bash_profile`

## What you get

After install, you’ll have these helpers available (among a few others):

- `extract <archive> [dest]` — extract many common archive formats
- `sysinfo` — compact system summary
- `netinfo` — compact network summary (with optional cached external IP)

Try them:

- `sysinfo`
- `netinfo`
- `extract --help`

## Quick troubleshooting

### “Nothing loads” (common on macOS)

- Confirm you’re in **Bash**:
  - `echo "$SHELL"`
  - `echo "$BASH_VERSION"`

- Make sure your terminal starts a **login shell**.
  - Terminal.app/iTerm can be configured to run Bash as a login shell.

### “`netinfo` feels slow”

`netinfo` can optionally look up your external IP. To disable that lookup:

- `export NETINFO_EXTERNAL_IP=0`

### “A module broke my shell startup”

You can disable modules without editing the repo:

- `export BASH_PROFILE_MODULES_DISABLE="netinfo"`

Then start a fresh login shell (`bash -l`) to confirm your shell starts cleanly.

---

## Advanced / reference (details live down here)

### How it’s structured

- `.bash_profile` — main entry point (works even when symlinked); loads modules from `profile.d/`
- `profile.d/10-common.sh` — cross-platform helpers (OS detection, PATH helpers)
- `profile.d/osx.sh` — macOS-only helpers (guarded)
- `profile.d/linux.sh` — Linux-only helpers (guarded)
- `profile.d/extract.sh` — `extract` helper
- `profile.d/sysinfo.sh` — `sysinfo` helper (also runnable directly)
- `profile.d/netinfo.sh` — `netinfo` helper (also runnable directly)

### Module loading and overrides

The loader supports enabling/disabling modules via environment variables:

- `BASH_PROFILE_MODULES_DISABLE` — space- or comma-separated list to skip
- `BASH_PROFILE_MODULES_ENABLE` — if set, only modules in this list load

Entries may be either the stem (`netinfo`) or filename (`netinfo.sh`).

Local overrides (sourced last if present):

1. `<repo>/profile.d/local.sh` (recommended; gitignored)
2. `${XDG_CONFIG_HOME:-~/.config}/my-mac-bash-profile/local.sh`

### Machine-readable output (`--kv`)

Some helpers support `--kv`, which prints one `key=value` per line (stable order).

- `sysinfo --kv`
- `netinfo --kv`

### Bootstrap scripts (optional dependency installers)

Best-effort dependency installers live in `scripts/`:

- `scripts/bootstrap-linux.sh` (supports `--full` and `--dry-run`)
- `scripts/bootstrap-macos.sh` (supports `--dry-run`)

### Dev notes

- Developer-focused docs: `readme_for_dev.md`
- Roadmap: `roadmap.md`
- Lint/tests:
  - `make lint`
  - `make test`
