---
title: Release process (v2)
repo: My-Mac-Bash-profile
doc_version: v2.0
---

<!-- markdownlint-disable MD025 -->

# Release process (v2)

This repo is intentionally lightweight: the “release artifact” is the git tag + the repository contents. There is no compiled build.

## Release artifact decision (P4.1)

For v2, the official release artifacts are:

- A **git tag** (e.g., `v2.0.0`)
- A matching **GitHub Release** generated from that tag (recommended, but content can be minimal)

No Homebrew formula/cask is published as part of v2.

## Preconditions

From a clean checkout of the default branch:

- `make lint` passes
- `make test` passes
- `docs/v1.0/CHANGELOG.md` has an up-to-date `Unreleased` section describing what’s in the release

## Checklist (P0.5 / P4.2)

### 1) Prepare release notes

- Update `docs/v1.0/CHANGELOG.md`:
  - Move items from `Unreleased` into a new dated section (example: `## 2.0.0 — 2025-12-14`)
  - Leave a fresh `## Unreleased` section at the top
- If there are any behavioral changes, ensure `docs/v2.0/migration_from_v1.md` covers them.

### 2) Verify safety + compatibility

Run the full checks:

- `make lint`
- `make test`

Manual spot-checks (quick):

- `bash -lc 'source ./.bash_profile'` (should be silent and fast)
- `sysinfo --kv` and `netinfo --kv` (keys present; `N/A` when optional tools missing)
- `scripts/install.sh --dry-run` (no writes)

### 3) Tag the release

- Create an annotated tag:
  - `v2.0.0`, `v2.0.1`, etc.
- Push tags

### 4) Publish GitHub release

- Create a GitHub Release from the tag
- Paste the relevant changelog section as release notes

## Rollback guidance

Because install is a symlink or a copied install dir, rollback is straightforward:

- If you installed by linking to a checkout: `git checkout <previous tag>`
- If you installed via `--install-dir`: re-run `scripts/install.sh` with an older checkout/tag and the same install dir/target

## Versioning policy

- Tags use `vMAJOR.MINOR.PATCH`.
- v2 aims to keep **backward compatibility** by default; breaking changes require explicit migration notes and a deprecation window when feasible.
