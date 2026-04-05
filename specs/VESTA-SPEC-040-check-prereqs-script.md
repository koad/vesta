# VESTA-SPEC-040 — `check-prereqs.sh` Script Contract

**ID:** VESTA-SPEC-040  
**Title:** check-prereqs.sh — Operator Prerequisite Verification Script  
**Status:** canonical  
**Area:** 2: Gestation Protocol  
**Applies to:** koad (maintainer), Vulcan (implementation), all new operators  
**Created:** 2026-04-05  
**Updated:** 2026-04-05  
**Resolves:** Muse brief `2026-04-05-get-started-flow.md` — Open Question 1  

---

## Why This Exists

The `/get-started` flow (see `2026-04-05-get-started-flow.md`) offers a "paste one command to check all prerequisites" pattern for Unix-fluent operators. This document specifies what that script must do, how it must behave, where it lives, and what it must not do.

This script is the first thing a new operator runs. It is first contact. It must:
- Exit cleanly on success
- Give clear, actionable output on failure
- Never require elevated permissions
- Never modify the system
- Be short enough to read in 60 seconds

---

## Prerequisites Checked

The script checks four prerequisites in order:

| # | Tool | Required Version | Check Command |
|---|------|-----------------|---------------|
| 1 | git | 2.x or later | `git --version` |
| 2 | Node.js | v22 or later (LTS) | `node --version` |
| 3 | Claude Code | any recent | `claude --version` |
| 4 | GitHub CLI | any (optional but recommended) | `gh --version` |

**Note on Claude Code:** Claude Code is required to run entity sessions. It is the most commonly missing prerequisite and is treated as required (not optional) for `check-prereqs.sh`.

**Note on GitHub CLI:** `gh` is recommended but not required for running a first session. The script reports it as optional — a WARN status rather than FAIL.

---

## Output Contract

### Success output (all required prerequisites met)

```
koad:io prerequisite check
──────────────────────────────────────────────────────

  ✓  git         2.39.2
  ✓  node        v22.4.0
  ✓  claude      1.x.x
  ⚠  gh          not found   (optional — needed for issue-based workflow)

──────────────────────────────────────────────────────
All clear. You're ready to clone an entity.

  git clone https://github.com/koad/juno ~/.juno
  cd ~/.juno && claude .
```

Exit code: `0`

### Failure output (one or more required prerequisites missing)

```
koad:io prerequisite check
──────────────────────────────────────────────────────

  ✓  git         2.39.2
  ✗  node        not found
  ✗  claude      not found
  ⚠  gh          not found   (optional)

──────────────────────────────────────────────────────
Missing prerequisites:

  node
    Install: https://nodejs.org (LTS)
    Or:      nvm install --lts

  claude
    Install: npm install -g @anthropic-ai/claude-code
    Auth:    claude   (interactive — follow prompts)

──────────────────────────────────────────────────────
Run this script again after installing.
```

Exit code: `1`

---

## Output Rules

1. **One tool per line.** Three columns: status indicator, tool name, version or "not found".
2. **Status indicators:**
   - `✓` — tool found, version requirement met. Green if terminal supports color (`tput colors` ≥ 8).
   - `✗` — tool not found, or version below minimum. Red.
   - `⚠` — optional tool not found. Yellow.
3. **Color is optional.** The script checks `TERM` and `NO_COLOR` before applying color. If `NO_COLOR=1` is set, output is plain ASCII. Indicators work without color (✓/✗/⚠ are unambiguous).
4. **Install hints are only shown for failing items.** Do not print install hints for passing prerequisites — it adds noise.
5. **The two clone commands at the end are only shown on overall success.** On failure, the close is "Run this script again after installing."
6. **No spinner. No progress animation.** Each check resolves in under 100ms. A spinner would imply something is loading when nothing is.
7. **No interactive prompts.** The script must run non-interactively. It must not ask the user anything.

---

## Version Requirements

Version checking rules:

**git:** Any version of git from the past 5 years is acceptable. Minimum: 2.0. Check: `git --version` outputs `git version 2.X.Y` — parse major version.

**Node.js:** Minimum v22. LTS. Check: `node --version` outputs `vX.Y.Z` — parse major version, require ≥ 22.

**Claude Code:** No minimum version check. If `claude --version` exits 0 and returns output, the check passes. The version number is displayed but not gated on. Claude Code auto-updates; an older version is unlikely to be a blocker.

**GitHub CLI:** No version check. Presence only.

---

## Script Location

```
~/.koad-io/bin/check-prereqs.sh
```

Distributed as part of the koad:io framework package. Also linked from the `/get-started` page.

For the `/get-started` page, the canonical paste-in command is:

```bash
curl -fsSL https://raw.githubusercontent.com/koad/koad-io/main/bin/check-prereqs.sh | bash
```

Or, if the operator already has the framework cloned:

```bash
~/.koad-io/bin/check-prereqs.sh
```

---

## What the Script Must NOT Do

- **No `sudo`** — the script has no reason to need elevated permissions.
- **No writes** — the script must not create or modify any files.
- **No network calls** except as a byproduct of the tool checks themselves (there are none — `--version` flags are local).
- **No `eval`** of downloaded content inside this script — the `curl | bash` pattern for the entry point is acceptable (industry standard), but the script itself must not chain further curl+eval calls.
- **No assumptions about shell** — the script uses `#!/usr/bin/env bash`, not `#!/bin/bash`. It must not use bashisms that are absent from bash 4.x.

---

## Piped Execution Safety

The recommended paste-in form is `curl -fsSL ... | bash`. This is an accepted pattern for developer tooling (Homebrew, nvm, Volta, etc.) and is appropriate for this audience.

The script is read-only and makes no system modifications. The risk of piped execution is informational (not destructive). The script should be kept under 100 lines so an operator who chooses to inspect it first can read it in under 60 seconds.

The GitHub URL is canonical. The script is committed to the koad:io framework repo and versioned in git. Operators who prefer not to use curl+bash can clone the repo and run the script directly.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All required prerequisites met. Optional prerequisites may be missing. |
| `1` | One or more required prerequisites missing. |
| `2` | Script error (unexpected condition, unsupported shell, etc.). |

---

## Implementation Notes for Vulcan

```bash
#!/usr/bin/env bash
# check-prereqs.sh — koad:io operator prerequisite check
# Part of the koad:io framework: https://github.com/koad/koad-io
# Run: curl -fsSL https://raw.githubusercontent.com/koad/koad-io/main/bin/check-prereqs.sh | bash

set -euo pipefail

# Color support
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; RESET='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; RESET=''
fi

PASS="${GREEN}✓${RESET}"
FAIL="${RED}✗${RESET}"
WARN="${YELLOW}⚠${RESET}"

check_tool() {
  local tool="$1"
  local cmd="$2"
  local version_arg="${3:---version}"
  local optional="${4:-false}"
  local min_major="${5:-0}"

  if ! command -v "$tool" &>/dev/null; then
    [ "$optional" = "true" ] && echo -e "  $WARN  $(printf '%-10s' $tool) not found   (optional)" || echo -e "  $FAIL  $(printf '%-10s' $tool) not found"
    return 1
  fi

  local ver
  ver=$($cmd $version_arg 2>&1 | head -1)
  echo -e "  $PASS  $(printf '%-10s' $tool) $ver"
  return 0
}

# ... (checks follow contract above)
```

The implementation sketch above shows the pattern. Full implementation owned by Vulcan per koad/vulcan#49.

---

## Related Specs and Files

- VESTA-SPEC-002 — Gestation Protocol (full new-entity sequence; this script covers the pre-gestation environment check)
- VESTA-SPEC-005 — Cascade Environment (`.env` loading; operators run this before any entity exists)
- Muse brief: `2026-04-05-get-started-flow.md` (the `/get-started` page that embeds this script)
