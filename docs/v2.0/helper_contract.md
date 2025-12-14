---
title: Helper contract (v2)
repo: My-Mac-Bash-profile
doc_version: v2.0
---

# Helper contract (v2)

This document describes the **shared CLI and machine-output guarantees** that every helper in this project must honor. Keeping these guarantees makes the helpers safe to script across macOS and Linux, prevents flag drift, and keeps human output consistent so the repo can maintain the v2 portability goals.

## What counts as a “core helper”

| Helper | Primary surface | Notes |
| --- | --- | --- |
| `sysinfo` | CLI function + standalone script | Human dashboard, `--kv`, colorized box/table/stacked views |
| `netinfo` | CLI function + standalone script | Machine/driven output, `--kv`, plain output by default |
| `extract` | CLI function + completion | Extract archives safely (path-traversal guard) |
| `flushdns` | CLI function | Best-effort DNS flush helper; macOS + Linux |
| `jd` / `jdir` | CLI functions | `wget` wrappers (single URL / recursive download) |

Any new helper that joins this list must follow the same contract unless explicitly documented otherwise. Refer to this doc to verify compliance.

## Shared flag + exit-code contract

All helpers listed above agree to the following rules (unless noted):

1. `-h` / `--help` always prints a usage blurb and exits `0`.
2. Unknown flags exit `2` after printing an error that starts with `<helper>: unknown option` to `stderr`.
3. Runtime failures exit `1` and print a helpful message to `stderr` (unless the helper deliberately aliases a different status).
4. Helpers are quiet on success and only print extra lines when the user requested more detail (e.g., `--verbose`), erring on the side of not touching the terminal state.
5. When a helper can’t compute a value because an optional tool is missing, the output becomes `N/A` (or an explicit note for required dependencies) rather than failing the shell.
6. Tests guard these invariants via `tests/helper_contract.sh`, which runs through the entire list and asserts the above behavior every time `make test` runs.

### Optional flags or behaviors

| Helper | `--kv` | `--plain`/`--no-color` | additional notes |
| --- | --- | --- | --- |
| `sysinfo` | ✅ (see “`--kv` key order” below) | `--plain`/`--no-color` disable ANSI styling; `--color` forces it | `--box` / `--table` / `--stacked` choose layout |
| `netinfo` | ✅ (see below) | `--plain`/`--no-color` accepted even though plain is the default | `--color` accepted for contract consistency |
| `extract` | ❌ | ❌ | accepts `-v/--verbose`, `-l`, `-f` as documented |
| `flushdns` | ❌ | ❌ | offers `--dry-run`, `--restart`, `--status` |
| `jd` / `jdir` | ❌ | ❌ | support `--dry-run` and `--help` only |

## `--kv` key order (stable machine output)

The `--kv` mode is intentionally conservative: it prints one `key=value` pair per line with no extra frills. The keys listed below are part of the compatibility contract, so changing or reordering them requires a deprecation path.

### `sysinfo --kv`

```text
os
os_version
boot_volume
volume_size
volume_used
volume_free
uptime
load_avg
cpu_user
cpu_sys
cpu_idle
ram_used
ram_free
ram_total
net_rx
net_tx
```

Each key directly maps to the variables in `profile.d/sysinfo.sh`, and every `make test` run checks that this exact order is preserved. Values that cannot be determined become `N/A` instead of breaking the script.

### `netinfo --kv`

```text
os
default_interface
gateway
local_ip
wifi_ssid
vpn_interfaces
external_ip
```

These keys align with the `netinfo` variables and match the output of `tests/helper_contract.sh` so that scripts can rely on predictable parsing. Optional values such as `wifi_ssid` and `vpn_interfaces` gracefully fall back to `N/A` (or `none` for VPN when no interface is detected).

## Helper inventory + current contract gaps

This table summarizes each helper’s CLI surface, current differences, and how the contract handles them.

| Helper | Flags covered | Exit codes | `N/A` semantics | Notes / delta from contract |
| --- | --- | --- | --- | --- |
| `sysinfo` | `-h`, `--help`, `--kv`, `--plain`, `--no-color`, `--color`, `--box`, `--table`, `--stacked` | `0`, `1`, `2` | Everywhere a measurement fails | Already compliant; the test suite checks the `--kv` order. |
| `netinfo` | `-h`, `--help`, `--kv`, `--plain`, `--no-color`, `--color` | `0`, `1`, `2` | Every network field may become `N/A`; `vpn_interfaces` uses `none` when no VPN detected | Already compliant; `tests/helper_contract.sh` enforces `--kv` keys. |
| `extract` | `-h`, `--help`, `-v`, `--verbose`, `-l`, `--list`, `-f`, `--force` | `0`, `1`, `2` | Refuses path traversal unless `--force`, prints `N/A`-style warnings when tools are missing | `extract` is human-only, so the CLI contract focuses on return codes and safety. |
| `flushdns` | `-h`, `--help`, `--dry-run`, `--restart`, `--status` | `0`, `1`, `2` | If no DNS service is found the helper prints a friendly message and exits `1` | Fast distributions guard ensures no prompts; tests rely on `--help` stability. |
| `jd` / `jdir` | `-h`, `--help`, `--dry-run`, `--recursive` (jdir via default) | `0`, `1`, `2`, `127` when `wget` missing | When `wget` missing they exit `127` (in line with shell conventions) | They simply wrap `wget`, so contract enforcement is limited to help text + exit codes. |

## Testing expectations

- `tests/helper_contract.sh` lives in the `tests/` directory and runs every helper’s `--help` path plus the `--kv` verification. It is invoked from `make test` so CI enforces the helper contract on Linux and macOS.
- A future helper that joins the contract should add itself to `tests/helper_contract.sh` and update this doc so reviewers can see the CLI surface and the expected `--kv` keys.

By keeping this doc and the companion test in sync, we ensure B-004 (“flag/exit-code drift between helpers”) stays resolved and P2 remains stable.
