---
title: Deprecation policy (v2)
repo: My-Mac-Bash-profile
doc_version: v2.0
---

<!-- markdownlint-disable MD025 -->

# Deprecation policy (v2)

v2 prefers **soft deprecations** over abrupt breaks.

The goal: existing users should be able to upgrade without their login shell breaking, and scripts should keep working unless a clear migration path exists.

## Definitions

### Breaking change

A change is considered **breaking** if it does any of the following:

- Makes `.bash_profile` fail to source on supported platforms/shells.
- Introduces network access, prompts, or noticeable latency during sourcing.
- Renames/removes a helper or changes user-visible behavior without a documented migration.
- Changes `--kv` keys or semantics (or their order) without a deprecation window.

See also: `docs/v2.0/compatibility_contract.md`.

### Soft deprecation

A soft deprecation is a staged change with:

- a warning (interactive shells only),
- continued support for old behavior for at least **one release**, and
- documentation telling users what to do next.

## Rules

1. **No warnings during non-interactive sourcing.**
   - Deprecation warnings must never break scripts.
   - Warnings should only appear for interactive shells (`[[ $- == *i* ]]`).

2. **Support old env vars for at least one release when feasible.**
   - If an env var is renamed, v2 should accept the old one and map it to the new one (with a warning) for ≥1 release.

3. **Never break the “safe-to-source” contract.**
   - A deprecation warning must be simple output; no external processes, no network, no file writes.

4. **Document every deprecation.**
   - Add a short entry to the changelog (`docs/v1.0/CHANGELOG.md`) and to the migration doc (`docs/v2.0/migration_from_v1.md`).

## Suggested implementation pattern

If we ever rename an env var, the recommended pattern is:

- if `OLD_VAR` is set and `NEW_VAR` is not set:
  - set `NEW_VAR="$OLD_VAR"`
  - warn to stderr (interactive only)

This keeps behavior stable while giving users a clear transition path.
