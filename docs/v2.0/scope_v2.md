---
title: Scope (v2)
repo: My-Mac-Bash-profile
doc_version: v2.0
---

# Scope (v2)

This project is a **simple, portable `.bash_profile`** plus a small set of helper functions and scripts.

v2 focuses on making the existing helpers nicer and more consistent, without turning the repo into a “framework” or a suite of full programs.

## North star

- Safe to source on macOS `/bin/bash` (3.2) and common Linux Bash.
- No surprises: minimal side effects, predictable behavior, easy to remove.
- Helpers feel polished, but remain “small shell helpers”.

## Non-negotiable guardrails (prevent bloat)

### Startup impact rules (hard constraints)

- Sourcing `.bash_profile` and `profile.d/*.sh` must be **fast** and **side-effect free**:
  - no network calls
  - no prompts
  - no long-running commands
  - no heavy subprocess pipelines
  - no writing to disk outside clearly documented caches/config (and not on source)
- Modules should primarily **define functions/vars/aliases**; any real work happens only when a user calls a function.
- Optional behaviors that do anything “active” must be:
  - **opt-in** via env var, or
  - gated to interactive shells only (`[[ $- == *i* ]]`), and still lightweight

### Helper scope (what helpers are)

Helpers are “small convenience commands”, not full programs:

- OK: `--help`, stable exit codes, `--kv` output, small UX touches (`tput` when available), better errors.
- OK: best-effort data collection with graceful `N/A` when a tool is missing.
- Not OK: building complex CLIs with subcommands, interactive TUI menus, persistent background processes, or long-running watchers.

## In scope (v2)

- **Consistency** across helpers (`sysinfo`, `netinfo`, `extract`, `flushdns`, `jd`, `jdir`):
  - common flags where sensible (`--help`, `--kv`, `--no-color`)
  - consistent exit codes and stderr/stdout rules
  - stable machine output that is intentionally simple (`key=value`)
- **Portability improvements** (BSD vs GNU differences; missing tools; macOS Bash 3.2 constraints).
- **Safety hardening**:
  - safe-to-source contract enforcement
  - archive extraction safety checks (path traversal protections, opt-in overrides)
- **Docs that prevent user mistakes**:
  - support matrix
  - install/uninstall
  - config/overrides/module toggles
  - troubleshooting (“my shell broke” escape hatches)
- **CLI contracts**:
  - `docs/v2.0/helper_contract.md` explains the shared flag/exit-code/`--kv` guarantees and the helper inventory.
  - `tests/helper_contract.sh` proves `--help` and the `--kv` ordering for each helper so reviewers can rely on the contract.
- **Installer polish**, as long as it remains conservative (idempotent, dry-run, backups).

## Explicitly out of scope (v2)

### Not a shell framework

- No plugin manager, theming system, or big module ecosystem.
- No required “module metadata registry” that users must learn to add a helper.

### Not a package manager

- No mandatory Homebrew/apt integration.
- Bootstrap scripts remain best-effort and optional; they are not required for normal usage.

### Not a full CLI suite

- No new “big” commands with deep subcommand trees.
- No JSON output as the primary interface (may be optional later, but `--kv` stays the baseline).

### No new startup-time “smartness”

- No auto-detection that runs expensive probes on source.
- No network lookups on source (including “external IP” or update checks).
- No telemetry, analytics, or auto-update mechanisms.

## Dependency policy

- Baseline is **pure Bash + common system tools**.
- If a helper benefits from external tools, it must:
  - check availability (`command -v …`)
  - degrade quietly to `N/A` (or a clear message when the command is required)
  - never be required for `.bash_profile` sourcing to succeed
- Prefer tools usually present on the target OS:
  - macOS: `sw_vers`, `sysctl`, `vm_stat`, `networksetup`, `route`, `ifconfig`
  - Linux: `ip`, `/proc`, `uname`, `free`
- Optional niceties like `tput` are fine, but must be guarded and should never be required.

## Performance budget policy (v2)

- v2 will define a simple budget for “source time” and keep it from regressing.
- Any new functionality that requires computation should be lazy (run only when the helper is invoked).
- We treat **0.9 seconds** on the Linux CI baseline as the “source time” budget and verify it with `tests/perf-startup.sh` every run.
- Safety guards (`tests/safe-source.sh` and `tests/missing-deps.sh`) now prove the profile can be sourced without hidden side effects and that helpers degrade gracefully when optional commands are missing.

## How we decide if a new idea belongs

An idea is in-scope if:

- It’s a small helper or a small improvement to an existing helper.
- It does not add measurable startup cost when sourcing the profile.
- It remains portable (or is clearly OS-guarded) and fails softly.
- It is testable with a smoke test and maintainable without heavy dependencies.

If it violates any guardrail above, it’s out of scope for v2.
