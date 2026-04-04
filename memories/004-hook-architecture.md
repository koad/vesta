---
title: "004 - Hook Architecture"
created: 2026-04-04
tags: [hooks, infrastructure, invocation, protocol]
status: active
priority: high
---

# Hook Architecture — Live as of 2026-04-04

This is the canonical description of how entity hooks work in production. Vesta owns the spec for this pattern.

## Hook Location

Every entity has a single entry-point hook:

```
~/.<entity>/hooks/executed-without-arguments.sh
```

This file handles both interactive and non-interactive invocation modes.

## Two Invocation Modes

### Non-interactive (task mode, `-p`)

- Fresh claude session per invocation
- Prompt passed as base64-encoded string (handles apostrophes and special characters)
- `--output-format=json`
- PID lock at `/tmp/entity-<name>.lock` — fail-fast on concurrent invocations (prevents racing builds)
- Result returned as stdout JSON `.result`

**Base64 encoding pattern:**
- Encode on thinker: `printf "..." | base64`
- Decode on remote: `echo "..." | base64 -d`

**NVM_INIT:** PATH must be explicitly set in hooks — zsh non-interactive shells do not source `.zshrc`.

### Interactive (session resume)

- `ssh -t` with `-c` flag to resume last session on the remote machine
- Connects the user's terminal directly

## Two-Way Communication

- **Juno → entities:** Juno (on thinker) calls entity hooks on fourty4 via SSH
- **Entities → back:** Entities on fourty4 reach back to koad:io commands via `~/.koad-io/bin/` entity commands

## PID Lock Detail

```
/tmp/entity-<name>.lock
```

Prevents concurrent invocations of the same entity. If the lock file exists and the process is alive, the hook exits immediately with an error. This prevents racing builds and state corruption.

## PRIMER.md Convention

Entities may have a `PRIMER.md` in their root and/or in `hooks/` for instant orientation when an agent enters that directory. Already implemented:
- `~/.juno/PRIMER.md`
- `~/.juno/hooks/PRIMER.md`

Vesta wrote these primers. This convention should be spec'd and propagated across all entities.

## Spec Gaps to Address

- Formal VESTA-SPEC for hook architecture (pattern is live but not yet canonicalized in a spec file)
- PRIMER.md convention needs a canonical spec
