# Changelog

All notable changes to this project will be documented in this file.

This repo is a portable Bash login profile (macOS + Linux) with helper functions.

## Unreleased

- P1: macOS Bash 3.2 compatibility fixes and CI for lint + smoke tests
- P2: `--help` and machine-readable `--kv` modes for helpers
- P3: module toggles and local override support
- P4: installer script (`scripts/install.sh`) with `--dry-run` and backups
- P5: `extract` aborts on obvious path traversal by default (`--force` to override)
