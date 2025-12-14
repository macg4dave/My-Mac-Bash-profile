---
title: Roadmap (v2)
repo: My-Mac-Bash-profile
doc_version: v2.0
---

# Roadmap (v2)

This is the forward-looking roadmap for the next iteration of **My-Mac-Bash-profile**.

Scope for v2 (to prevent bloat):

- `docs/v2.0/scope_v2.md`
- `docs/v2.0/compatibility_contract.md`

If you’re looking for “what’s already done”, see:

- `docs/v1.0/roadmap.md`
- `docs/v1.0/CHANGELOG.md`

Last updated: 2025-12-14

## How to use this roadmap

- **P0–P5**: priority buckets (P0 is “must decide/define first”).
- **Milestones**: each has a DoD and acceptance criteria.
- **Blockers**: anything that can stall a milestone gets an ID (`B-###`) and is tracked centrally.
- **Trackers**: keep “next action” concrete (one action, not a vague goal).

## Tracker (one screen)

### Status legend

- 🟡 not started
- ⏳ in progress
- ✅ done
- ⛔ blocked (see blocker register)

| Milestone | Status | Definition of done (DoD) | Next concrete action | Target | Blocked by |
|---|---:|---|---|---|---|
| P0 — Define v2 scope + decisions | ⏳ | v2 scope + deprecations are written; upgrade path documented; “won’t do” list exists | Finalize `docs/v2.0/scope_v2.md`, compatibility contract, and config/release outlines | v2.0.0 | — |
| P1 — Reliability + performance | 🟡 | Startup stays fast; safe-to-source contract enforced; expanded test matrix + regression tests | Decide/measure startup budget + add perf smoke check | v2.0.0 | B-001, B-002 |
| P2 — Consistent CLI/UX across helpers | ✅ | Unified flags (`--help`, `--kv`, `--no-color`); stable exit codes; consistent errors | Keep `docs/v2.0/helper_contract.md` and `tests/helper_contract.sh` synchronized with the helpers | v2.0.0 | — |
| P3 — Config + module lifecycle | 🟡 | One config source of truth; clear enable/disable; module metadata + ordering rules documented | Pick config format + precedence rules | v2.0.0 | B-003 |
| P4 — Distribution + releases | 🟡 | Release process is documented + automated; changelog is release-ready; upgrade notes exist | Decide release automation approach (tags + notes) | v2.0.0 | B-005 |
| P5 — Optional expansions | 🟡 | Add-ons are opt-in, tested, and don’t affect startup | Curate a short list of “safe” extras | v2.x | — |

## Priorities (P0 → P5)

- **P0 — Define v2**: what’s in/out, compatibility contract, upgrade/deprecation plan.
- **P1 — Reliability + performance**: reduce “login shell risk”, keep startup fast, strengthen tests.
- **P2 — CLI/UX**: consistent contracts across helpers; scripting modes that don’t break.
- **P3 — Config + module lifecycle**: predictable behavior as modules scale.
- **P4 — Distribution + releases**: make updates boring; document and automate.
- **P5 — Optional expansions**: only after the core stays solid.

## Decision log (P0: unblock everything)

| Decision | Default recommendation | Why it matters | Status |
|---|---|---|---:|
| v2 “breaking changes” policy | Prefer **soft-deprecations** (warn + support old env vars for ≥1 release) | Prevents “can’t login” surprises | 🟡 |
| Minimum Bash version | Keep supporting **macOS `/bin/bash` 3.2** | It’s the hardest constraint and defines portability | 🟡 |
| Config format | Start with **env vars + single optional config file** | Keeps bootstrap dependency-free | 🟡 |
| Machine output format | Keep **`--kv`** as the stable baseline | Easiest to produce in pure Bash and scriptable | 🟡 |
| Release cadence | “When ready”, but tag + changelog every release | Makes upgrades auditable | 🟡 |

## Blocker register (ranked P0 → P*)

| ID | Priority | Blocker / risk | Impact | Mitigation / next step | Blocks |
|---|---:|---|---|---|---|
| B-001 | P1 | Startup time regression as modules grow | Slower shells; users disable the profile | Define a startup budget + add perf smoke check | P1–P5 |
| B-002 | P1 | “Safe to source” violations creep in | Login shell breaks; side effects on source | Add a test that sources modules under restrictive env vars and forbids external calls | P1–P5 |
| B-003 | P3 | Config precedence becomes confusing | Users can’t predict behavior or debug | Define precedence + document it with examples | P3 |
| B-004 | P2 | Flag/exit-code drift between helpers | Scripts break; UX feels inconsistent | `docs/v2.0/helper_contract.md` + `tests/helper_contract.sh` lock down the contract for flags, `--kv`, and exit codes | — |
| B-005 | P4 | Release flow is manual and error-prone | Inconsistent tags/notes; stale changelog | Automate release notes + add a checklist | P4 |
| B-006 | P1 | OS tool variance (macOS vs Linux distros) | Noisy errors or missing data | Expand guardrails + standardize `N/A` behavior | P1–P2 |
| B-007 | P1 | GNU-vs-BSD CLI incompatibilities | Breakages on stock macOS | Keep portability rules explicit + tested | P1 |

---

## Milestones

## P0 — Define v2 scope + decisions

**Goal**: make v2 changes explicit, predictable, and upgradeable.

### Deliverables (P0)

- A written **v2 scope**: what changes, what stays stable, what is deprecated.
- An **upgrade path** from v1 behavior (env vars, module names, install layout).
- A **“won’t do” list** to prevent scope creep.

The existing scope (`docs/v2.0/scope_v2.md`) and compatibility contract (`docs/v2.0/compatibility_contract.md`) already codify much of what we mean by “stable behavior” and “supported platforms,” so the remaining deliverables are about turning those artifacts into concrete decisions, deprecation paths, and release guardrails.

### Work items (P0)

- [x] **P0.1** Capture the compatibility contract; link to `docs/v2.0/compatibility_contract.md` for the supported platforms/tools/migration rules.
- [ ] **P0.2** Define what counts as a breaking change, how deprecations are communicated, and what “soft-deprecation” tooling is needed (warnings, old env vars, docs).
- [ ] **P0.3** Finalize the config strategy (env vars + optional config file) and document precedence/resolution order so users can predict what will load.
- [ ] **P0.4** Decide if any helpers/modules need renaming or deprecation mappings and capture those in a short migration table.
- [ ] **P0.5** Create a v2 release checklist that covers tagging, changelog updates, and any manual verification steps.

### P0 status

- Compatibility contract: ✅ defined in `docs/v2.0/compatibility_contract.md`, including supported shells, tools, and safe-to-source guarantees.
- Scope, supported guardrails, and absolute-outs are spelled out in `docs/v2.0/scope_v2.md`, giving us the “won’t do” list and upgrade context.
- Next steps: finalize the config/release plan (P0.3/P0.5) and start documenting breaking change/deprecation paths (P0.2/P0.4).

### Acceptance criteria (P0)

- A new user can read this doc and understand what v2 is.
- An existing user can upgrade without guessing (clear migration notes).

### Blockers (P0)

- (none)

---

## P1 — Reliability + performance

**Goal**: keep login shell startup safe and fast as features grow.

### Deliverables (P1)

- A **startup performance budget** and a way to measure it (at least in CI on Linux).
- Stronger “safe to source” guarantees (tests + docs).
- Expanded smoke tests for common “minimal” environments (missing optional tools).

### Work items (P1)

- [ ] **P1.1** Define startup performance budget (e.g., “under X ms on GitHub runners”).
- [ ] **P1.2** Add a perf test (e.g., time `bash -lc 'source ~/.bash_profile'`) with thresholds.
- [ ] **P1.3** Add a “no side-effects on source” test (disable network, stub PATH, verify no writes outside XDG dirs).
- [ ] **P1.4** Add a “missing deps” matrix test (PATH without `curl`, without `ip`, without `diskutil`, etc.).
- [ ] **P1.5** Document the “safe to source” rules as a contributor checklist.

### P1 status

- `tests/smoke.sh` (invoked via `make test`) already enforces much of P1: it runs the profile in a fake `HOME`, stubs `NETINFO_EXTERNAL_IP=0` to avoid network calls, verifies `sysinfo`, `netinfo`, and `extract` are defined even when helpers are disabled, and confirms helpers can be run both via the interactive loader and as standalone scripts.
- That script also exercises `scripts/install.sh` and the bootstrap helpers in dry-run mode, so the “no writes on source” requirement is covered until we add more explicit guardrails.
- `docs/v2.0/compatibility_contract.md` and `docs/v2.0/scope_v2.md` already document the “safe-to-source” and portability expectations (B-002, B-006, B-007), which gives us concrete language to test against.
- Next steps: define a measurable budget (e.g., record `real` seconds for `source ~/.bash_profile` on the CI baseline) and plug that timing into a new perf check, then layer a missing-deps matrix test that manipulates `PATH`/command availability to confirm helpers degrade to `N/A` without failing.

### Acceptance criteria (P1)

- Sourcing the profile does not perform network access, prompt, or hang.
- Startup time stays within the defined budget on the chosen CI baseline.

### Blockers (P1)

- B-001, B-002, B-006, B-007

---

## P2 — Consistent CLI/UX across helpers

**Goal**: users can rely on consistent flags, exit codes, and machine output.

### Deliverables (P2)

- A single **CLI contract** for helpers (common flags + exit codes).
- Helpers are consistent about:
  - `--help` output shape
  - `--kv` key names and ordering
  - `--no-color` support (even if default is plain)
  - error messages to `stderr`

### Work items (P2)

- [x] **P2.1** Write `docs/v2.0/helper_contract.md` (flags, exit codes, error rules, `N/A` semantics).
- [x] **P2.2** Inventory existing helpers (current flags and output) and list deltas vs the contract.
- [x] **P2.3** Standardize `--kv` ordering + keys where needed (don’t break existing keys without deprecation).
- [x] **P2.4** Add smoke tests that verify `--help` and `--kv` invariants for each helper.
- [x] **P2.5** Add “examples” section to `readme.md` that demonstrates scripting with `--kv`.

### Acceptance criteria (P2)

- All helpers pass a common contract test suite.
- Existing scripts using current stable keys continue to work (or get a deprecation warning path).

### Blockers (P2)

- (none — B-004 resolved via the helper contract doc + tests)

---

## P3 — Config + module lifecycle

**Goal**: predictable customization without editing tracked files.

### Deliverables (P3)

- Clear module lifecycle:
  - discovery/ordering rules
  - enable/disable rules
  - local override precedence
- A single “source of truth” config story (even if it’s “env vars only”).

### Work items (P3)

- [ ] **P3.1** Decide on config approach (env-only vs optional config file).
- [ ] **P3.2** Document precedence rules (repo local override vs XDG override vs env vars).
- [ ] **P3.3** Add a `mm-bash-profile doctor` (or equivalent) to print detected config + module load results (optional).
- [ ] **P3.4** Add module metadata conventions (module name, OS guards, optional dependencies).
- [ ] **P3.5** Add troubleshooting docs for “module X broke startup” and “how to bisect”.

### Acceptance criteria (P3)

- A user can disable/enable modules and understand *why* a module loaded (or didn’t).
- Overrides are deterministic and documented with examples.

### Blockers (P3)

- B-003

---

## P4 — Distribution + releases

**Goal**: installs and upgrades are repeatable, reviewable, and low-risk.

### Deliverables (P4)

- Release automation (or at minimum a strict checklist).
- `CHANGELOG` policy: “unreleased” vs “released” sections, consistent format.
- Upgrade notes for v2 (migration doc).

### Work items (P4)

- [ ] **P4.1** Define release artifact scope (just tags? GitHub releases? packaged tarball?).
- [ ] **P4.2** Add a `docs/v2.0/release_process.md` checklist.
- [ ] **P4.3** Add CI job for “release hygiene” (changelog presence, version strings if used).
- [ ] **P4.4** Decide whether to publish via Homebrew (formula/cask) or keep git-only.
- [ ] **P4.5** Write `docs/v2.0/migration_from_v1.md`.

### Acceptance criteria (P4)

- A release can be cut from a clean checkout with a repeatable sequence of steps.
- A user can upgrade safely and roll back (documented).

### Blockers (P4)

- B-005

---

## P5 — Optional expansions

**Goal**: useful extras that remain opt-in and do not burden core startup.

### Guardrails

- Must be opt-in (off by default).
- Must not add measurable startup cost.
- Must be portable (or explicitly OS-guarded).
- Must have at least a smoke test for “doesn’t break startup”.

### Idea backlog (P5)

- [ ] Add completions for `sysinfo` / `netinfo` flags (Bash 3.2 compatible).
- [ ] Add a `doctor` command that prints what’s loaded and why (if not done in P3).
- [ ] Add a minimal prompt theming toggle (opt-in; default unchanged).
- [ ] Add a small `pathinfo` helper (print PATH entries, duplicates, and missing dirs).
