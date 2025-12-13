# Roadmap

## Vision

Deliver a portable, well-documented Bash profile that keeps macOS niceties while remaining first-class on Linux workstations and headless servers. The profile should feel safe to version, easy to extend, and resilient to missing dependencies.

## Priority Scale

- **P1** – Critical; blockers for daily workflow or security.
- **P2** – High; unlocks major usability wins or cross-platform parity.
- **P3** – Medium; quality-of-life improvements or documentation.
- **P4** – Low; polish or optional integrations.
- **P5** – Wishlist; only scheduled when higher priorities are complete.
- **P6** – Move "Programs" to separate scripts.

## Progress Tracker

| Task | Priority | Status | Blockers | Notes |
| --- | --- | --- | --- | --- |
| Harden `.bash_profile` (history, prompt, PATH hygiene) | P1 | ✅ Complete | None | loader now sources numbered `profile.d/` modules safely |
| Document configuration variables in `readme.md` | P2 | ⏳ In Progress | Needs decisions on secrets storage | initial quickstart + env-var cheat-sheet added |
| Build `sysinfo` + `netinfo` telemetry helpers | P2 | ✅ Complete | None | `sysinfo` now includes RAM; `netinfo` added (VPN/Wi‑Fi/external IP cache) |
| Split platform logic into `profile.d/` modules | P3 | ✅ Complete | None | numbered modules + legacy wrapper files for compatibility |
| Bootstrap scripts for macOS/Linux deps | P4 | 🟡 Not Started | Need package inventory | detect brew/apt/pacman |
| Secrets management via `pass`/Keychain | P5 | 🟡 Not Started | Decide secrets tool | could leverage age + sops |

Legend: ✅ complete, ⏳ in progress, 🟡 not started.

## Now (v1.0 – Sprint 0)

### Tasks (Sprint 0)

- **P1 – Ship robust history + prompt defaults**
  - [x] Enable `histappend`, `PROMPT_COMMAND` sync, git branch info.
- **P1 – Guard server helpers**
  - [x] Validate `make_ssh`, `gohome`, `stophome` inputs in tests.
- **P2 – Document entry points**
  - [x] Add environment variable cheat-sheet plus reload instructions in `readme.md`.
- **P2 – Cross-platform QA**
  - [ ] Test `.bash_profile` on macOS Ventura, Ubuntu 22.04, Fedora 40.

### Blockers/Risks (Sprint 0)

- Need access to a macOS host for validating macOS-only helpers (`cdf`, `gosu`) and macOS telemetry branches.
- Secrets not yet abstracted; reviewers must avoid committing real credentials.

## Next (v1.1 – Sprint 1)

### Tasks (Sprint 1)

- **P2 – Automated linting**
  - [ ] Add `shellcheck`
  - [ ] Provide `just lint` or `make lint` target for local runs.
- **P3 – Plugin-friendly structure**
  - [ ] Create `profile.d/osx.sh` and `profile.d/linux.sh`.
  - [ ] Update `.bash_profile` to source `profile.d/*.sh` if present.
- **P3 – Telemetry helpers**
  - [ ] Expand `sysinfo` with CPU %, RAM usage (via `vm_stat` or `free -m`).
  - [ ] Add `netinfo` showing VPN status, Wi-Fi SSID, external IP cache.
- **P4 – Dependency bootstrap**
  - [ ] Scaffold `scripts/bootstrap-macos.sh` (Homebrew installs).
  - [ ] Scaffold `scripts/bootstrap-linux.sh` (apt/pacman detection).

### Blockers/Risks (Sprint 1)

- GitHub Actions minutes availability.
- Need standard for storing helper scripts (`scripts/` vs `tools/`).

## Later (v2.x – Backlog)

### Ideas

- **P3 – Shell analytics**
  - Add optional `PROMPT_COMMAND` hook to log command durations (without logging commands themselves).
- **P4 – Installer UX**
  - Single `./install.sh` that symlinks `.bash_profile`, installs hooks, and verifies dependencies.
- **P5 – Zsh/Fish parity**
  - Mirror functionality to `~/.zprofile` and generate Fish config automatically.
- **P5 – GUI dashboard**
  - Mini TUI displaying system info via `fzf` + `gum`.

### Blockers/Risks

- Handling secrets consistently across shells.
- Maintaining parity between Bash and future zsh/fish ports.

## Maintenance

- Revisit PATH entries quarterly to remove stale language runtimes.
- Keep README, roadmap, and `.bash_profile` aligned whenever commands change behavior.
- Run `shellcheck` locally before pushing changes.
