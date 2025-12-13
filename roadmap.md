---
title: Roadmap
repo: My-Mac-Bash-profile
---

## Roadmap

This repo is a portable Bash login profile with a small set of helper functions and bootstrap scripts.

This roadmap is a living tracker. It focuses on:

1. **Correctness across macOS + Linux**
2. **Safe-by-default behavior when sourced**
3. **A clean path to add modules over time**

Last updated: 2025-12-13

## Tracker (what’s happening, in one screen)

### Status legend

- 🟡 not started
- ⏳ in progress
- ✅ done
- ⛔ blocked (has an active blocker in the register below)

| Milestone | Status | Definition of done (DoD) | Next concrete action | Blocked by |
|---|---:|---|---|---|
| P1 — Stability & compatibility | ✅ | Safe to source on macOS `/bin/bash` (3.2) and Linux Bash; CI runs lint+tests; README support matrix + install steps are accurate | Keep an eye on hidden portability hazards as modules grow | — |
| P2 — UX & observability | ✅ | `sysinfo`/`netinfo`/`extract` have `--help`, stable exit codes, and at least one scriptable output mode | Consider adding a `--tsv` mode if/when needed | — |
| P3 — Extensibility & configuration | ✅ | Local overrides work without forking; module ordering & enable/disable are documented and predictable | Decide on a long-term module naming/ordering convention | — |
| P4 — Distribution & updates | ⏳ | Optional installer is idempotent; changelog + tags exist; upgrades are repeatable | Document installer usage + add smoke coverage | — |
| P5 — Polish & nice-to-haves | ✅ | Optional features remain opt-in and do not slow shell startup noticeably | (done) `extract` completion + safer installer backups + optional `--install-dir` deployment | — |

## Priorities (P1 → P5)

- **P1 — Stability & compatibility (ship-ready core)**: lock down supported shells/OSes, remove/guard incompatible Bash features, and make CI + docs reflect reality.
- **P2 — UX & observability**: make helpers easier to use (flags, consistent output), more reliable in constrained environments, and faster.
- **P3 — Extensibility & configuration**: make adding/removing modules predictable; provide an official mechanism for local overrides.
- **P4 — Distribution & updates**: make installation/upgrades repeatable (installer, release artifacts, changelog).
- **P5 — Polish & nice-to-haves**: optional enhancements that shouldn’t block core portability.

## Decision log (unblocks everything)

These decisions should be made early; the rest of the roadmap assumes they are answered.

| Decision | Default recommendation | Why it matters | Status |
|---|---|---|---:|
| Minimum Bash version | **Support macOS Bash 3.2** | Prevent “can’t even login” failures on stock macOS | 🟡 |
| Target platforms | “Supported” vs “best-effort” matrix | Sets what CI must cover and what breakages are acceptable | 🟡 |
| Output contracts | Human vs machine output for helpers | Enables stable scripting and non-breaking UX changes | 🟡 |
| Install approach | Documented symlink install + optional installer later | Reduces surprises for dotfiles users; keeps adoption easy | 🟡 |

## Recommended implementation order (dependency-first)

1. **Define the support contract** (shell/OS/tooling matrix) → drives every other decision.
2. **Fix compatibility hazards** (especially Bash 3.2 limitations) → prevents shell startup failures.
3. **Docs + install story** (README install + troubleshooting + bootstrap expectations) → reduces user error.
4. **Helper UX improvements** (flags, stable formats, predictable exit codes) → improves day-to-day value.
5. **Module system improvements** (config/overrides, enable/disable) → makes the repo grow safely.
6. **Packaging/distribution** (installer + releases) → makes adoption and upgrades repeatable.
7. **Optional expansions** (new helpers, prompt themes, completions) → last, to avoid scope creep.

## Blocker register (ranked P1 → P*)

This is the ordered list of blockers/risks. Any milestone marked ⛔ should reference at least one item here.

| ID | Priority | Blocker / risk | Impact | Mitigation / next step | Blocks |
|---|---:|---|---|---|---|
| B-001 | P1 | Bash 4+ features break macOS default `/bin/bash` (3.2) | Login shell can fail to start | Replace/guard Bash 4+ features (fixed: removed `${var,,}` usage in `profile.d/extract.sh`) | P1 |
| B-002 | P1 | “Safe to source” violations (implicit execution on source) | Side effects on login; hangs in restricted envs | Ensure `profile.d/*.sh` only defines functions/vars; no network calls or prompts on source | P1–P5 |
| B-003 | P2 | Module ordering / loader behavior is unclear | Debugging startup issues becomes hard | Document loader order; formalize numbering rules | P3 |
| B-004 | P2 | Machine output (JSON/TSV) in pure Bash is fragile | Users cannot reliably script outputs | Start with `--tsv`/`--key=value` before JSON; keep JSON scoped and tested | P2 |
| B-005 | P3 | Installer expectations differ for dotfiles users | Accidental overwrites; adoption friction | Make installer optional and conservative; implement `--dry-run` + backups | P4 |
| B-006 | P3 | Optional dependency variance across OS/distros | Noisy errors; inconsistent output | Guard command existence and degrade gracefully to `N/A` | P1–P2 |
| B-007 | P1 | GNU coreutils-only flags break macOS userland (e.g., `dirname --`, `readlink --`) | Shell startup or tests can fail on stock macOS | Avoid GNU-only flags; prefer portable invocations and guard command availability | P1 |

---

## Milestones

## P1 — Stability & compatibility (ship-ready core)

**Goal**: “Drop-in profile” that won’t break login shells on common macOS and Linux setups.

### Deliverables (P1)

- A clear **support matrix** in `readme.md` (tested OSes; minimum Bash version).
- Compatibility audit and fixes for any Bash 4+ features (or explicitly require Brew Bash and document it).
- “Install” section in `readme.md` filled in (install instructions, reload instructions).

### Work items (P1)

- [x] **P1.1** Decide and document minimum Bash version (recommended: macOS Bash 3.2 compatible).
- [x] **P1.2** Remove/guard Bash 4+ syntax across `profile.d/*.sh`.
  - [x] Replace `${var,,}` usage in `profile.d/extract.sh` with a portable lowercasing approach.
  - [ ] Spot-check for other Bash 4+ features (associative arrays, `mapfile`, `globstar`, etc.).
- [x] **P1.3** Enforce “safe to source” rule for all modules.
- [x] **P1.4** Add GitHub Actions workflow to run `make lint` + `make test` on Linux + macOS.
- [x] **P1.5** Update `readme.md` install section + troubleshooting for supported shells/OSes.

### Acceptance criteria (P1)

- `source .bash_profile` succeeds on macOS default `/bin/bash` and on Linux Bash.
- `make lint` and `make test` pass in CI.
- README tells users what’s supported and how to install.

### Blockers (P1)

- B-001, B-002, B-007

---

## P2 — UX & observability (make helpers pleasant)

**Goal**: helpers (`sysinfo`, `netinfo`, `extract`) are consistent, predictable, and easy to script.

### Deliverables (P2)

- `sysinfo --help` / `netinfo --help` / `extract --help` usage output.
- Stable output modes:
  - Human mode (current behavior)
  - Machine mode (recommend starting with `--tsv` or `--key=value`)
- More reliable `sysinfo` data collection on both OSes (best-effort without noisy errors).

### Work items (P2)

- [x] **P2.1** Define a consistent contract: exit codes, output format, and what “N/A” means.
- [x] **P2.2** Add `--help` and basic flags across helpers (`--plain` / `--no-color`).
- [x] **P2.3** Add a machine-readable mode (start with `--tsv` or `--key=value`; keep JSON optional and tested).
- [x] **P2.4** Normalize field naming and ordering across macOS vs Linux.
- [x] **P2.5** Improve “missing dependency” behavior: quiet by default, best-effort, `N/A` where needed.

### Blockers (P2)

- B-004, B-006

---

## P3 — Extensibility & configuration (scale modules safely)

**Goal**: users can customize without forking; adding new modules doesn’t create ordering surprises.

### Deliverables (P3)

- Standard local override mechanism (`profile.d/local.sh`)
- Module enable/disable support without editing `.bash_profile`.
- Clear module ordering rules (document and formalize existing behavior).

### Work items (P3)

- [x] **P3.1** Document loader behavior in `.bash_profile` (ordering rules, failure behavior, expected environment).
- [x] **P3.3** Add module toggling mechanism (simple allowlist/denylist via env vars).
- [x] **P3.4** Add a troubleshooting section for “module X broke my shell startup”.

### Blockers (P3)

- B-003

---

## P4 — Distribution & updates (repeatable install/upgrade)

**Goal**: make setup and updates consistent across machines.

### Deliverables (P4)

- Optional installer script (idempotent) that:
  - installs a symlink to `~/.bash_profile` (with backup)
  - supports `--dry-run`
  - can optionally run bootstrap scripts

### Work items (P4)

- [x] **P4.1** Define install/upgrade contract (what changes, what gets backed up, what is opt-in).
- [x] **P4.2** Write `scripts/install.sh`
- [x] **P4.3** Document installer usage in `readme.md` and add a smoke test for `--dry-run`.

### Blockers (P4)

- (none)

---

## P5 — Polish & nice-to-haves

**Goal**: improvements that are valuable but not required for core portability.

### Guardrails

- Must remain opt-in.
- Must not slow shell startup in a noticeable way.
- Must keep macOS + Linux compatibility (or be explicitly OS-guarded).

### Ideas (pick after P1–P4)

- Shell completion (where feasible) for `extract`
- installer to copy old bash_profile to backup location with better naming
- installer to to install all scripts and bash_profile to users home directory
