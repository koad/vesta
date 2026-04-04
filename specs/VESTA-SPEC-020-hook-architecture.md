---
status: canonical
id: VESTA-SPEC-020
title: "Entity Hook Architecture — Invocation Contract, Non-Interactive Path, Interactive Path"
type: spec
created: 2026-04-04
owner: vesta
author: Vesta (vesta@kingofalldata.com)
reviewers: [koad, Juno]
related-issues: [koad/vesta#66]
superseded-by: TBD (daemon worker system — see Section 8)
---

# Entity Hook Architecture

## 1. Overview

Every koad:io entity exposes a single shell entry-point hook:

```
~/.<entity>/hooks/executed-without-arguments.sh
```

This hook is the entity's *front door* — it is what runs when another entity or a human invokes the entity by name. It must handle two distinct invocation modes without separate scripts: **non-interactive** (prompt-driven, automated) and **interactive** (terminal session, human-operated).

This spec defines the contract for that hook, the mechanics of both paths, and the protocols each path depends on (PID lock, base64 encoding, PATH initialization).

**Scope:** This spec covers the live pattern in production as of 2026-04-04. It does not cover the daemon worker system that will eventually supersede it (see Section 8).

**Relationship to VESTA-SPEC-009 (Hooks Catalog):** VESTA-SPEC-009 enumerates all hook event types and their signatures. This spec focuses exclusively on the invocation contract and implementation mechanics of `executed-without-arguments.sh`, which is the hook most likely to be executed across entities.

---

## 2. Hook Contract

### 2.1 Required Behavior

Every `executed-without-arguments.sh` **MUST**:

1. **Detect mode** — determine whether it was invoked with a prompt (`$PROMPT` set, or stdin piped) or without (interactive)
2. **Non-interactive path** — if a prompt is present, execute a fresh `-p` Claude Code session on the entity's host, return the result, and exit
3. **Interactive path** — if no prompt is present, open a live terminal session on the entity's host
4. **Clean up on exit** — release any locks or temporary state when done

Every `executed-without-arguments.sh` **MUST NOT**:
- Block indefinitely without a timeout (interactive SSH handles this via the user's terminal)
- Leave a stale lockfile if it crashes (use `trap` to clean up)
- Silently swallow errors — non-zero exits should propagate

### 2.2 Prompt Detection

The hook reads the prompt from `$PROMPT` or from stdin (piped input). The detection logic is:

```bash
PROMPT="${PROMPT:-}"
if [ -z "$PROMPT" ] && [ ! -t 0 ]; then
  PROMPT="$(cat)"
fi
```

If `$PROMPT` is empty and stdin is a terminal (i.e., no pipe), the hook takes the interactive path. Otherwise it takes the non-interactive path.

### 2.3 Minimal Hook Skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail

ENTITY_HOST="<hostname>"
ENTITY_DIR="$HOME/.<entity>"
CLAUDE_BIN="$HOME/.nvm/versions/node/v24.14.0/bin/claude"
NVM_INIT="export PATH=/opt/homebrew/bin:$HOME/.nvm/versions/node/v24.14.0/bin:$PATH"
LOCKFILE="/tmp/entity-<name>.lock"

PROMPT="${PROMPT:-}"
if [ -z "$PROMPT" ] && [ ! -t 0 ]; then
  PROMPT="$(cat)"
fi

if [ -n "$PROMPT" ]; then
  # Non-interactive path — see Section 3
  ...
else
  # Interactive path — see Section 4
  ...
fi
```

---

## 3. Non-Interactive Path

The non-interactive path is the task invocation path. A caller (another entity, a harness hook, a scheduled job) sets `$PROMPT` and expects a result on stdout.

### 3.1 Full Sequence

1. **Acquire PID lock** — fail-fast if another invocation is already running (Section 5)
2. **Base64-encode the prompt** — protect against shell quoting hazards (Section 6)
3. **SSH to entity host** — initialize PATH, enter entity directory, decode prompt, run `claude -p`
4. **Parse JSON result** — extract `.result` from `--output-format=json` response
5. **Release PID lock** — automatically, via `trap EXIT`

### 3.2 Reference Implementation

```bash
if [ -n "$PROMPT" ]; then
  # Step 1: PID lock
  if [ -f "$LOCKFILE" ]; then
    LOCKED_PID=$(cat "$LOCKFILE" 2>/dev/null || echo "")
    if [ -n "$LOCKED_PID" ] && kill -0 "$LOCKED_PID" 2>/dev/null; then
      echo "<entity> is busy (pid $LOCKED_PID). Try again shortly." >&2
      exit 1
    fi
  fi
  echo $$ > "$LOCKFILE"
  trap 'rm -f "$LOCKFILE"' EXIT

  # Step 2: Base64-encode
  ENCODED=$(printf '%s' "$PROMPT" | base64 -w0 2>/dev/null || printf '%s' "$PROMPT" | base64)

  # Step 3–4: SSH, decode, run, parse
  ssh "$ENTITY_HOST" \
    "$NVM_INIT && cd $ENTITY_DIR && DECODED=\$(echo '$ENCODED' | base64 -d) && \
     $CLAUDE_BIN --model sonnet --dangerously-skip-permissions \
       --output-format=json -p \"\$DECODED\" 2>/dev/null" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',''))"
fi
```

### 3.3 Claude Flags in Non-Interactive Mode

| Flag | Required | Rationale |
|------|----------|-----------|
| `-p "<prompt>"` | Yes | Batch/non-interactive mode — run prompt and exit |
| `--output-format=json` | Yes | Structured output; result is in `.result` field |
| `--model sonnet` | Yes | Specifies model; prevents harness from falling back to default |
| `--dangerously-skip-permissions` | Yes | Entities operate autonomously; permission prompts would hang |

### 3.4 Result Extraction

`--output-format=json` returns a JSON object. The `.result` field contains the entity's text response:

```json
{
  "type": "result",
  "result": "Done. Committed abc1234.",
  "cost_usd": 0.0042,
  ...
}
```

Extract with:
```bash
python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',''))"
```

`python3` is used rather than `jq` because Python is available on macOS without installation. `jq` is acceptable if known to be installed on the target host.

---

## 4. Interactive Path

The interactive path opens a live terminal session on the entity's host. The user's TTY is connected through.

### 4.1 Mechanics

```bash
exec ssh -t "$ENTITY_HOST" \
  "$NVM_INIT && cd $ENTITY_DIR && $CLAUDE_BIN --model sonnet --dangerously-skip-permissions -c"
```

| Component | Purpose |
|-----------|---------|
| `ssh -t` | Force TTY allocation — required for interactive terminal programs |
| `$NVM_INIT` | Initialize PATH before running claude (Section 7) |
| `cd $ENTITY_DIR` | Place session in entity's home directory so CLAUDE.md is loaded |
| `-c` | Resume last Claude Code session (continue) |
| `exec` | Replace the hook process with SSH — no dangling parent process |

### 4.2 The `-c` Flag

`-c` (continue) resumes the most recent Claude Code session rather than starting fresh. This is the correct behavior for interactive use: the human picks up where they left off.

**Do not use `-c` in non-interactive mode.** The non-interactive path always starts a fresh `-p` session — resuming would risk mixing stale context with the new prompt.

### 4.3 When `exec` Is Appropriate

Because the interactive path is a terminal handoff, `exec` is used to replace the hook process with the SSH process. This avoids leaving an orphaned shell process waiting for SSH to return.

The non-interactive path does **not** use `exec` because it needs to post-process the JSON output before exiting.

---

## 5. PID Lock Protocol

### 5.1 Purpose

The PID lock prevents concurrent non-interactive invocations of the same entity. Running two `-p` sessions simultaneously can produce race conditions in git state and agent memory. The lock is a fail-fast mechanism: if the entity is busy, callers are told immediately rather than queued.

### 5.2 Lockfile Location

```
/tmp/entity-<name>.lock
```

Examples: `/tmp/entity-vesta.lock`, `/tmp/entity-vulcan.lock`

`/tmp` is used because it is:
- Always writable without privilege
- Automatically cleared on system reboot (stale locks from crashes are recovered on next boot)
- Consistent across Linux and macOS

### 5.3 Acquire and Release

```bash
LOCKFILE="/tmp/entity-<name>.lock"

# Acquire
if [ -f "$LOCKFILE" ]; then
  LOCKED_PID=$(cat "$LOCKFILE" 2>/dev/null || echo "")
  if [ -n "$LOCKED_PID" ] && kill -0 "$LOCKED_PID" 2>/dev/null; then
    echo "<entity> is busy (pid $LOCKED_PID). Try again shortly." >&2
    exit 1
  fi
  # File exists but process is gone — stale lock, proceed
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT
```

**Order of operations:**
1. Check if lockfile exists
2. Read the PID from the lockfile
3. Test if that PID is alive with `kill -0`
4. If alive → fail with error message and exit 1
5. If dead or unreadable → stale lock; overwrite and proceed
6. Write own PID to lockfile
7. Register `trap` to delete lockfile on any exit (normal or error)

### 5.4 Stale Lock Detection

`kill -0 <PID>` sends signal 0 to the process. This does not kill the process — it only checks whether the process exists. Returns 0 if alive, non-zero if dead or not owned.

```bash
kill -0 "$LOCKED_PID" 2>/dev/null
# Exit 0 → process alive → lock is valid → fail-fast
# Exit 1 → process dead → lock is stale → overwrite and proceed
```

This handles crashes (hook killed mid-run) and machine reboots (PIDs do not persist across reboots, `/tmp` is cleared).

### 5.5 The Lock Applies Only to Non-Interactive Mode

The PID lock is acquired only when `$PROMPT` is set (non-interactive path). Interactive sessions are not locked — a human running `vesta` directly always gets a terminal. Multiple interactive sessions are the user's responsibility.

---

## 6. Base64 Encoding

### 6.1 Rationale

Prompts passed to entities frequently contain characters that break shell quoting:
- Single quotes (`'`) — terminate the outer single-quoted SSH argument
- Apostrophes (same as single quotes)
- Newlines — collapse in unquoted arguments
- Double quotes, backticks, dollar signs — interpreted by the remote shell

Base64-encoding the prompt before it crosses the SSH boundary eliminates all quoting hazards. The encoded string is ASCII-safe and contains no shell metacharacters (only `A-Z`, `a-z`, `0-9`, `+`, `/`, `=`).

### 6.2 Encode/Decode Pattern

**Encode on caller side (where hook runs):**
```bash
ENCODED=$(printf '%s' "$PROMPT" | base64 -w0 2>/dev/null || printf '%s' "$PROMPT" | base64)
```

**Decode on remote side (inside the SSH command):**
```bash
DECODED=$(echo '$ENCODED' | base64 -d)
```

Note the single quotes around `'$ENCODED'` in the SSH argument — this passes the literal base64 string to the remote shell rather than allowing local expansion. The remote shell then decodes it.

### 6.3 Linux vs macOS Portability

`base64` behaves differently across platforms:

| Platform | `base64` default | Line wrap |
|----------|-----------------|-----------|
| Linux (GNU coreutils) | Wraps at 76 chars | `-w0` disables wrapping |
| macOS (BSD base64) | No wrapping | `-w0` is not supported (errors) |

The portable pattern tries `-w0` first and falls back to plain `base64`:

```bash
ENCODED=$(printf '%s' "$PROMPT" | base64 -w0 2>/dev/null || printf '%s' "$PROMPT" | base64)
```

`2>/dev/null` suppresses the "invalid option" error on macOS. If `-w0` fails, the fallback runs without it. On macOS, no wrapping occurs by default, so the fallback is correct.

**Why wrapping matters:** If the encoded string has embedded newlines, `echo '$ENCODED'` on the remote side passes a multi-line argument. `base64 -d` handles multi-line input correctly, but some intermediate steps (logging, variable expansion) may truncate at the first newline. Disabling wrap with `-w0` produces a single-line string that is unambiguous.

### 6.4 `printf` vs `echo`

`printf '%s' "$PROMPT"` is used instead of `echo "$PROMPT"` to avoid appending a trailing newline. `echo` appends `\n` by default on most systems; `printf '%s'` does not. The distinction matters when the prompt's exact byte content is significant (though for Claude prompts it is usually benign).

---

## 7. NVM / PATH Initialization

### 7.1 The Problem

When SSH runs a command non-interactively (without `-t`, without `-c`), the remote shell is a **non-interactive, non-login shell**. On zsh and bash, this means:

- `.zshrc` is **not** sourced (zsh interactive only)
- `.bash_profile` / `.bashrc` may not be sourced (depends on system)
- `nvm` is not initialized
- `$PATH` contains only the system default (`/usr/bin:/bin:/usr/sbin:/sbin`)
- `claude` (installed via nvm's node) is **not** on `$PATH`

### 7.2 The Solution

Prepend an explicit `NVM_INIT` string to every remote SSH command:

```bash
NVM_INIT="export PATH=/opt/homebrew/bin:$HOME/.nvm/versions/node/v24.14.0/bin:$PATH"
```

This is expanded on the **caller's** side (before SSH sends it), so `$HOME` resolves to the caller's home. On the remote system, the entity is running as the same user, so the path is identical.

**Hardcode the node version.** Do not use `$(nvm which node)` or similar — that requires nvm to be initialized, which is the problem we are solving.

### 7.3 Example

```bash
CLAUDE_BIN="$HOME/.nvm/versions/node/v24.14.0/bin/claude"
NVM_INIT="export PATH=/opt/homebrew/bin:$HOME/.nvm/versions/node/v24.14.0/bin:$PATH"

# Non-interactive SSH — NVM_INIT prepended to remote command
ssh "$ENTITY_HOST" "$NVM_INIT && cd $ENTITY_DIR && $CLAUDE_BIN ..."

# Interactive SSH — NVM_INIT prepended before launching claude
exec ssh -t "$ENTITY_HOST" "$NVM_INIT && cd $ENTITY_DIR && $CLAUDE_BIN -c"
```

### 7.4 Why Not `source ~/.nvm/nvm.sh`?

`source ~/.nvm/nvm.sh` would work but is slower (nvm startup has measurable latency) and introduces a dependency on nvm's own initialization behavior. Hardcoding the binary path is simpler, faster, and immune to nvm version changes in that session.

When the node version is upgraded, update `NVM_INIT` and `CLAUDE_BIN` in the hook.

---

## 8. Known Limitations

This architecture is a working solution, not a final one. Known limitations:

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| **No queuing** | Concurrent callers get an error (`exit 1`); they must retry manually | Caller implements its own retry loop |
| **No retry** | Failed invocations are not retried by the hook | Caller decides retry policy |
| **No result persistence** | Result is printed to stdout and lost; no log of what ran or returned | Caller captures stdout if persistence is needed |
| **PID lock is local** | Lock is on the caller's machine; does not protect against concurrent SSH callers from different machines | Architecture assumes single caller origin (Juno on thinker) |
| **Version pinning** | Node version is hardcoded in `NVM_INIT`; hook must be updated when node is upgraded | Update hook on node version change |
| **Stdout-only result** | Errors during the remote claude session are suppressed (`2>/dev/null`); only `.result` is returned | Remote stderr is lost; diagnose by running interactively |
| **SSH latency** | Each non-interactive invocation pays SSH connection overhead (~200–500ms) | Acceptable for task invocation; unacceptable for tight loops |

---

## 9. Future State: Daemon Worker System

This hook architecture is a **transitional protocol**. It was designed for the pre-daemon era when entities had no persistent process and no message queue.

The intended replacement is a **daemon worker system** in which:

- Each entity runs a persistent daemon process on its host
- Callers submit tasks to the daemon's queue rather than spawning a new claude session per invocation
- The daemon serializes tasks, retries on failure, persists results, and reports status back
- PID locks become unnecessary (the daemon serializes internally)
- Base64 encoding remains useful for task payloads
- SSH invocation is replaced by the inter-entity comms protocol (VESTA-SPEC-010)

**When the daemon worker system is implemented, this spec is superseded.** Entities should migrate hooks to the daemon model as defined in VESTA-SPEC-007 (Daemon Specification).

Until that migration occurs, this hook architecture is the canonical invocation pattern.

---

## 10. Entity-Specific Values

Each entity's hook substitutes its own values for these placeholders:

| Variable | Example (Vesta) | Description |
|----------|-----------------|-------------|
| `ENTITY_HOST` | `fourty4` | SSH hostname where entity lives |
| `ENTITY_DIR` | `$HOME/.vesta` | Entity's home directory on remote |
| `CLAUDE_BIN` | `$HOME/.nvm/versions/node/v24.14.0/bin/claude` | Full path to claude binary |
| `NVM_INIT` | `export PATH=/opt/homebrew/bin:...` | PATH initialization string |
| `LOCKFILE` | `/tmp/entity-vesta.lock` | PID lockfile path |

The entity name in `LOCKFILE` must match the entity's canonical name (same as `$ENTITY`).

---

## 11. Conformance Checklist

A conforming `executed-without-arguments.sh` must satisfy all of the following:

**Detection:**
- [ ] Reads `$PROMPT` env var first
- [ ] Falls back to reading stdin if `$PROMPT` is empty and stdin is a pipe
- [ ] Branches on whether prompt is non-empty

**Non-interactive path:**
- [ ] Acquires PID lock before running claude
- [ ] Writes own PID to lockfile
- [ ] Registers `trap 'rm -f "$LOCKFILE"' EXIT`
- [ ] Detects stale lock via `kill -0`
- [ ] Base64-encodes prompt with `-w0` fallback
- [ ] Initializes PATH via `NVM_INIT` in remote SSH command
- [ ] Passes `--output-format=json` to claude
- [ ] Passes `-p` (not `-c`) to claude
- [ ] Extracts `.result` from JSON output
- [ ] Does **not** use `exec` (needs to post-process output)

**Interactive path:**
- [ ] Uses `ssh -t` for TTY allocation
- [ ] Initializes PATH via `NVM_INIT` in remote SSH command
- [ ] Passes `-c` (continue/resume) to claude
- [ ] Uses `exec` to replace hook process with SSH

---

## 12. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 (canonical) | 2026-04-04 | Initial spec: hook contract, non-interactive path, interactive path, PID lock, base64, PATH init, limitations, future state |

---

*Spec status: canonical (2026-04-04). File issues on koad/vesta to propose amendments or report implementation gaps.*
