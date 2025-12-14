# Copilot instructions for this repo

## What this repo is
- This is a version-controlled Bash login profile centered on `/.bash_profile`.
- The roadmap and direction live in `roadmap.md` (cross-platform macOS + Linux, safe defaults, minimal surprises).

## Key files / entry points
- `.bash_profile` is the main executable artifact (sourced by Bash on login). Keep changes backward-compatible.
- `roadmap.md` documents in-progress and planned work (e.g., “profile.d/ modules”, ShellCheck CI, `sysinfo`/`netinfo`).
- `readme.md` must be kept up to date and user friendly; roadmap expects it to document configuration variables and quickstart.


## OS- and dependency-sensitive commands
- `macinfo`, `gosu`, and `cdf` rely on macOS-only tooling (`osascript`, `Finder`, `sw_vers`, `top -l`).

When adding or modifying functions that use non-portable commands:
- Guard by OS and/or command existence (example checks):
  - `command -v osascript >/dev/null 2>&1` before calling it
  - `[[ "$(uname -s)" == "Darwin" ]]` before macOS-specific logic
- Fail softly with a clear message instead of breaking shell startup.

## Style & editing conventions seen in this repo
- Functions are defined in the `name () { ... }` style and grouped with banner comments.
- Prefer changes that keep interactive UX stable (prompt `PS1`, aliases, and PATH edits can affect every session).
- Use `shellcheck` best practices (e.g., quoting variables, avoiding `eval`).
- When adding new features, consider cross-platform compatibility (macOS + popular Linux distros).
- When updating the roadmap, keep task statuses current (✅ complete, ⏳ in progress, 🟡 not started)

## What to avoid
- Do not add sensitive information (API keys, passwords) in any files.
- Avoid breaking changes to existing functionality without clear deprecation paths.
- Do not introduce heavy dependencies that complicate setup or usage.
- Avoid hardcoding OS-specific paths; use environment variables or detection logic instead.
- adding large new features that significantly increase startup time or complexity without prior discussion.
- adding new flags without asking if they fit the existing helper contract (see `docs/v2.0/helper_contract.md`).

## When in doubt
- Refer to existing patterns in the codebase for consistency.
- Ask for clarification on the intended behavior or design decisions if unsure.
---
description: This file provides instructions for using GitHub Copilot effectively within this repository.
applyTo: **
---
# Instructions for Using GitHub Copilot in This Repository
This repository contains a Bash login profile with a focus on cross-platform compatibility, safe defaults, and minimal surprises. When using GitHub Copilot to assist with code generation or modifications, please adhere to the following guidelines:
1. **Understand the Context**: Before accepting any suggestions from Copilot, ensure you understand the context of the code being modified. This includes the purpose of the `.bash_profile`, the roadmap in `roadmap.md`, and the user-facing documentation in `readme.md`.
2. **Maintain Cross-Platform Compatibility**: Any code generated or modified by Copilot should be compatible with both macOS and popular Linux distributions. Ensure that OS-specific commands are properly guarded with checks for the operating system or command existence.
3. **Follow Existing Conventions**: Copilot suggestions should align with the existing coding style and conventions used in this repository. This includes function definitions, commenting style, and best practices for shell scripting.
4. **Avoid Sensitive Information**: Do not allow Copilot to insert any sensitive information, such as API keys or passwords, into the codebase.
5. **Review and Test Thoroughly**: Always review Copilot-generated code for correctness, security, and performance. Test any changes in a safe environment before merging them into the main branch.


## Bash Scripting Best Practices- Use `shellcheck` to lint and validate scripts.
- Quote variables to prevent word splitting and globbing.
- Avoid using `eval` unless absolutely necessary.
- Use functions to encapsulate reusable logic.
- Use clear and descriptive names for functions and variables.
- Include comments to explain complex logic or decisions.
- Guard OS-specific commands with appropriate checks.
- Ensure that changes do not break existing functionality.
- Keep the user experience consistent, especially for interactive elements like prompts and aliases.
- Use environment variables and detection logic instead of hardcoding paths.
- write tests for functions that have complex logic or side effects.
- Document the purpose and usage of functions in comments.
- commit small, focused changes to make reviews easier.
- comments should be clear and concise, explaining the "why" behind decisions.

## Documentation Updates
- When Copilot suggests changes to documentation files, ensure that the information is accurate and up to-date.
- Keep the `readme.md` user-friendly and informative, reflecting any changes made to the codebase.
- Update the `roadmap.md` to reflect the current status of tasks and priorities accurately.
By following these instructions, you can effectively leverage GitHub Copilot to enhance the development process while maintaining the quality and integrity of this repository.