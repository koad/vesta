---
status: draft
id: VESTA-SPEC-008
title: "Spawn Protocol — Entity Process Launch, Isolation, and Lifecycle"
type: spec
created: 2026-04-03
owner: vesta
description: "Canonical protocol for spawning entities as sovereign child processes with proper authority checks, environment handling, communication, and lifecycle management"
---

# Spawn Protocol

## 1. Overview

**Spawn** is the runtime mechanism for launching an entity as a sovereign child process. It is distinct from **gestation** (one-time entity creation) — spawn is about repeated execution of an entity's code, on demand, with proper isolation and lifecycle management.

### Design Principles

- **Sovereign processes:** A spawned entity is a complete independent Claude Code session, not a function call or coroutine
- **Authority-gated:** Spawn requires valid authorization from the parent entity to the child entity (trust bond check)
- **Isolation:** Each spawned process gets a clean environment, respects containment levels, and cannot access other entities' private data
- **Observable:** Parent can monitor child status, receive output, and gracefully terminate on timeout or error
- **Transparent failure:** If spawn fails, it fails clearly with specific error codes and logged diagnostics
- **Containment-aware:** Spawned entities respect containment levels and can be paused/killed if they misbehave

### Use Cases

1. **Juno spawning a team entity** (e.g., `juno spawn process vulcan "build the project"`)
2. **Vulcan spawning a sub-build** (e.g., distributed compilation across processes)
3. **Vesta spawning an audit agent** (e.g., `vesta spawn process argus "audit protocol conformance"`)
4. **Remote execution** (e.g., Juno launching a job on a remote machine via SSH)

---

## 2. Authority Model

### 2.1 Trust Bond Requirement

**Rule 1:** An entity X can only spawn entity Y if:
- Entity X holds a valid trust bond **from** entity Y, OR
- Entity X is koad (root authority), OR
- Entity X is explicitly delegated spawn authority via trust bond from Y's grantor

**Trust Bond File Format:**

Trust bonds are Markdown files with YAML frontmatter (`~/.entityname/trust/bonds/target-to-entity.md`):

```yaml
---
grantor: juno
grantee: vesta
status: ACTIVE  # ACTIVE, REVOKED, EXPIRED
permissions:
  spawn: true
  read: true
  write: false
scope: full     # full, limited, task, audit
issued_date: 2026-04-01
expires_date: null  # null = no expiration
---

# Optional: human-readable terms
This bond grants vesta the authority to spawn juno for protocol audits.
```

**Field specifications:**
- `grantor` — Entity that issued this bond (must match entity's self-trust records)
- `grantee` — Entity being granted authority (the spawner)
- `status` — ACTIVE, REVOKED, or EXPIRED; spawn only proceeds if ACTIVE
- `permissions.spawn` — Boolean; must be `true` for spawn to be allowed
- `scope` — Authority scope: `full` (no restrictions), `limited` (see conditions), `task` (specific task only), `audit` (read-only)
- `issued_date` — ISO8601 date
- `expires_date` — ISO8601 date or `null` (never expires)

**Verification:**
```bash
# Example: Can vesta spawn juno?
# Check if vesta holds a trust bond authorized to spawn juno

BOND_FILE="$HOME/.vesta/trust/bonds/juno-to-vesta.md"
if [[ ! -f "$BOND_FILE" ]]; then
  echo "Error: vesta has no trust bond from juno" >&2
  exit 73  # EX_CANTCREAT
fi

# Extract status from YAML frontmatter
BOND_STATUS=$(grep "^status:" "$BOND_FILE" | head -1 | cut -d' ' -f2)
if [[ "$BOND_STATUS" != "ACTIVE" ]]; then
  echo "Error: bond status is $BOND_STATUS (required: ACTIVE)" >&2
  exit 73
fi

# Extract spawn permission from YAML frontmatter
SPAWN_PERM=$(grep "^  spawn:" "$BOND_FILE" | head -1 | awk '{print $NF}')
if [[ "$SPAWN_PERM" != "true" ]]; then
  echo "Error: spawn permission is $SPAWN_PERM (required: true)" >&2
  exit 73
fi
```

### 2.2 Scope Restriction

A trust bond's `scope` field limits what a spawned entity can do:

| Scope | Permissions | Restrictions |
|-------|-------------|--------------|
| `full` | Unrestricted within entity's directory | None |
| `limited` | See `conditions` field in bond | Entity cannot exceed stated conditions |
| `task` | Execute a specific task | Cannot deviate from assigned task |
| `audit` | Read-only access to specified paths | No write access outside audit target |

---

## 3. Launch Mechanism

### 3.1 Spawn Command Invocation

**Syntax:**
```bash
<parent-entity> spawn process <child-entity> [prompt] [options]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `<child-entity>` | string | Yes | Name of entity to spawn (e.g., `vulcan`, `juno`) |
| `[prompt]` | string | No | Initial task/prompt to pass to the spawned entity |
| `[options]` | flags | No | Launch options (e.g., `--timeout`, `--output`, `--isolated`) |

**Example:**
```bash
juno spawn process vulcan "build the project with --release flag"
vesta spawn process argus "audit VESTA-SPEC-* for conformance"
vulcan spawn process maya --timeout=300 "generate test vectors"
```

### 3.2 Pre-Flight Checks

Before launching, the dispatcher performs these checks **in order**. If any check fails, spawn aborts with the specified error code.

**Step 1: Entity Existence**
```bash
CHILD_DIR="$HOME/.$CHILD_ENTITY"
if [[ ! -d "$CHILD_DIR" ]]; then
  echo "Error: entity '$CHILD_ENTITY' not found at $CHILD_DIR" >&2
  exit 1
fi
```
**Exit code:** 1 (entity not found)

**Step 2: Trust Bond Verification**

See section 2.1 for trust bond file format (YAML frontmatter, `.md` extension).

```bash
# Bond file: ~/.parent/trust/bonds/child-to-parent.md
PARENT_ENTITY="${ENTITY:-koad}"
CHILD_ENTITY="$1"

BOND_FILE="$HOME/.$PARENT_ENTITY/trust/bonds/${CHILD_ENTITY}-to-${PARENT_ENTITY}.md"
if [[ ! -f "$BOND_FILE" ]]; then
  echo "Error: no trust bond from $CHILD_ENTITY to $PARENT_ENTITY" >&2
  exit 73  # EX_CANTCREAT
fi

# Verify bond is ACTIVE (extract from YAML frontmatter)
BOND_STATUS=$(grep "^status:" "$BOND_FILE" | head -1 | cut -d' ' -f2)
if [[ "$BOND_STATUS" != "ACTIVE" ]]; then
  echo "Error: trust bond status is $BOND_STATUS (required: ACTIVE)" >&2
  exit 73
fi

# Verify spawn permission is granted (extract from YAML frontmatter)
SPAWN_PERM=$(grep "^  spawn:" "$BOND_FILE" | head -1 | awk '{print $NF}')
if [[ "$SPAWN_PERM" != "true" ]]; then
  echo "Error: spawn permission is not granted in trust bond" >&2
  exit 73
fi
```
**Exit code:** 73 (authority denied, cannot create process)

**Step 3: Entity Readiness**
```bash
# Verify CLAUDE.md exists (entity is properly gestated)
if [[ ! -f "$CHILD_DIR/CLAUDE.md" ]]; then
  echo "Warning: $CHILD_DIR/CLAUDE.md not found (entity may not be fully gestated)" >&2
  # Continue (non-fatal warning)
fi

# Check disk space
AVAILABLE_KB=$(df "$CHILD_DIR" | awk 'NR==2 {print $4}')
if [[ $AVAILABLE_KB -lt 102400 ]]; then  # < 100 MB
  echo "Error: insufficient disk space for spawn (available: ${AVAILABLE_KB}KB)" >&2
  exit 28  # EX_NOINPUT
fi
```
**Exit codes:** 28 (EX_NOINPUT, insufficient resources)

**Step 4: Process Limits**
```bash
# Check if entity is already running
# Maximum of 4 concurrent instances per entity (fixed, not configurable)
EXISTING_PIDS=$(pgrep -f "claude.*$CHILD_ENTITY" | wc -l)
MAX_INSTANCES=4
if [[ $EXISTING_PIDS -ge $MAX_INSTANCES ]]; then
  echo "Error: entity '$CHILD_ENTITY' already has $EXISTING_PIDS running instances (max: $MAX_INSTANCES)" >&2
  exit 73
fi
```
**Exit code:** 73 (resource limits exceeded)

**Process Limit Details:**
- **Maximum concurrent instances:** 4 per entity (fixed default, not configurable)
- **Rationale:** Prevents resource exhaustion from runaway spawn loops
- **Behavior:** If an entity already has 4 running processes, spawn is rejected
- **Future:** If a limit higher than 4 is needed, the limit must be increased via spec change, not flag or environment variable

---

## 4. Environment Setup

### 4.1 Environment Inheritance

A spawned entity **inherits** the parent's cascade environment (as defined in VESTA-SPEC-005 — Cascade Environment Protocol) **except** for sensitive variables.

**Cascade Environment Loading (referenced from VESTA-SPEC-005):**

The cascade load order is:
1. Framework defaults (`~/.koad-io/.env`)
2. Parent entity settings (`~/.parent-entity/.env`)
3. Child entity settings (`~/.child-entity/.env`)
4. Ad-hoc exports passed via `--env` flags

Each layer is sourced with `set -a` to auto-export all variables, and earlier layers are overridden by later layers.

**Inherited variables (in default inheritance mode):**
- Framework defaults (`~/.koad-io/.env`)
- Parent entity settings (`~/.parent-entity/.env`)
- Child entity settings (`~/.child-entity/.env`)
- Ad-hoc exports passed via `--env` flags

**NOT inherited (isolation — always reset to child values):**
- `ENTITY_DIR` — Recomputed as `$HOME/.<child-entity>`
- `ENTITY` — Recomputed as `<child-entity>`
- Private keys (`*_KEY`, `*_PRIVATE`, `*_SECRET` variables)
- Parent-specific credentials (GitHub tokens, API keys)

### 4.2 Clean vs Inherited Environments

**Default (Inherited):**
The spawned entity sees the parent's environment, modified with the child's identity:

```bash
# Before spawn (parent: juno)
ENTITY=juno
ENTITY_DIR=/home/koad/.juno
KOAD_IO_HOME=/home/koad/.koad-io
MY_CONFIG_VALUE=parent-value

# After spawn (child: vulcan)
ENTITY=vulcan
ENTITY_DIR=/home/koad/.vulcan
KOAD_IO_HOME=/home/koad/.koad-io     # Inherited
MY_CONFIG_VALUE=parent-value          # Inherited (if not overridden by child)
```

**Clean Environment (via --isolated):**
With `--isolated` flag, the spawned entity starts with **only** its own cascade environment:

```bash
juno spawn process vulcan "task..." --isolated
# vulcan sees only ~/.koad-io/.env and ~/.vulcan/.env
# Parent's MY_CONFIG_VALUE is NOT available
```

---

## 5. Process Execution and Communication

### 5.1 Launch Mechanism

The spawn command creates a new process with:

**Harness:** Claude Code interactive (`claude .` or batch mode)

**Session:** Independent, full-featured (own memory, own CLAUDE.md, own context)

**Working Directory:** Child entity's directory (`$ENTITY_DIR`)

**Example launch:**
```bash
# Parent command
juno spawn process vulcan "build the project"

# Creates and executes
gnome-terminal --title="⬡ vulcan" -- \
  bash -c "cd /home/koad/.vulcan && claude . --prompt 'build the project'"
```

### 5.2 Communication Channels

**Parent → Child:**
- **Initial prompt** — Passed as `--prompt` flag to Claude Code
- **stdin** — Connected to parent terminal (for interactive input)
- **Environment variables** — Passed via cascade

**Child → Parent:**
- **stdout/stderr** — Echoed to parent terminal in real-time
- **Git commits** — Child's commits appear in its repo (parent can pull/monitor)
- **Exit code** — Returned to parent on process termination

### 5.3 Output Handling

**Real-time output:**
By default, child's stdout and stderr are displayed in parent's terminal:

```bash
juno spawn process vulcan "run tests"
# Output from vulcan appears live in juno's terminal
```

**Captured output (via --output flag):**
```bash
juno spawn process vulcan "build" --output=/tmp/build.log
# vulcan's output is captured to /tmp/build.log
# Parent shows only status messages
```

**Silent mode (via --quiet):**
```bash
juno spawn process vulcan "background task" --quiet
# Only exit code is reported; no output displayed
```

---

## 6. Lifecycle and Termination

### 6.1 Process States

A spawned entity progresses through these states:

```
PENDING    (checks running, not yet launched)
  ↓
RUNNING    (process started, Claude Code active)
  ↓
WORKING    (entity is executing the task/prompt)
  ↓
COMPLETE   (task finished, process exiting normally)
  ↓
EXITED     (process terminated, exit code set)
```

**Abnormal paths:**
```
RUNNING → TIMEOUT   (exceeded max runtime)
RUNNING → ABORTED   (parent sent SIGTERM/SIGKILL)
RUNNING → ERROR     (unrecoverable error, exit code ≥ 1)
```

### 6.2 Normal Termination

The child process terminates when:
1. The entity completes its task and Claude Code session ends naturally, OR
2. The entity calls `exit 0` explicitly, OR
3. A timeout expires (see 6.4)

**Exit code is propagated to parent.**

### 6.3 Graceful Termination (SIGTERM)

If the parent needs to stop the child gracefully:

```bash
# Parent sends SIGTERM
kill -TERM $CHILD_PID

# Child has GRACE_PERIOD seconds to:
# - Save state (commit to git)
# - Flush buffers
# - Clean up temporary files
# - Call exit

# After GRACE_PERIOD seconds, if still running, parent sends SIGKILL
kill -KILL $CHILD_PID
```

**Grace Period (Timeout Configuration):**

The grace period before SIGKILL is **10 seconds** by default and **MUST** be this value for all spawned processes. This timeout is **NOT configurable** per spawn invocation — all entities receive the same grace period.

```bash
# Dispatch implementation
GRACE_PERIOD=10  # Fixed, not configurable

kill -TERM "$CHILD_PID"
sleep "$GRACE_PERIOD"
if ps -p "$CHILD_PID" > /dev/null 2>&1; then
  kill -KILL "$CHILD_PID"
fi
```

**Signal Handlers (Child Process — Recommended):**

Spawned entities **SHOULD** register signal handlers for graceful shutdown. This is recommended but not mandatory:

```bash
#!/usr/bin/env bash

trap cleanup SIGTERM SIGINT

cleanup() {
  echo "Received termination signal, saving state..." >&2
  cd ~/.vulcan && git add -A && git commit -m "graceful shutdown" || true
  exit 130  # 128 + SIGTERM(2)
}

# Main work...
```

Entities without signal handlers will be force-killed after the grace period expires.

### 6.4 Timeout Handling

**Default timeout:** 3600 seconds (1 hour)

**Custom timeout:**
```bash
juno spawn process vulcan "quick build" --timeout=300  # 5 minutes
```

**On timeout:**
1. Parent sends SIGTERM to child (graceful termination)
2. If child doesn't exit in 10 seconds, parent sends SIGKILL
3. Parent logs: `"spawn vulcan: timeout after 300s"`
4. Parent exits with status 124 (EX_TIMEOUT)

**No timeout:**
```bash
juno spawn process vulcan "long task" --timeout=0  # No limit (not recommended)
```

---

## 7. Error Handling and Exit Codes

### 7.1 Spawn Command Exit Codes

The `spawn` command itself exits with:

| Code | Meaning | Condition |
|------|---------|-----------|
| 0 | Success | Child completed with exit code 0 |
| 1 | Child failed | Child exited with exit code ≥ 1 |
| 28 | No resources | Insufficient disk space, memory, or process slots |
| 64 | Usage error | Invalid arguments to spawn command |
| 73 | Authority denied | No trust bond, bond is revoked, or not authorized |
| 76 | Protocol error | Entity not fully gestated, missing CLAUDE.md |
| 124 | Timeout | Child exceeded timeout duration |
| 126 | Not executable | Child entity directory not executable |
| 127 | Not found | Child entity directory does not exist |
| 128+ | Signal | Child killed by signal: 128 + signal_number |

### 7.2 Diagnostics and Logging

**Logging Requirement:** Diagnostic logging is **MANDATORY** for all spawn operations. Logging is enabled by default and cannot be disabled.

**Log Location:** `~/.koad-io/logs/spawn.log` (created if it does not exist)

**Log Format:** Newline-delimited plaintext, ISO8601 timestamps, tab-indented for event hierarchy:

```
[2026-04-03T14:23:45.123Z] [vulcan] spawn initiated by: juno, prompt: "build" --timeout=60
[2026-04-03T14:23:46.456Z] [vulcan]   pre-flight: entity_exists=true, bond_active=true, disk_space=500GB
[2026-04-03T14:23:47.789Z] [vulcan]   launch: PID=12345, cwd=/home/koad/.vulcan
[2026-04-03T14:23:50.012Z] [vulcan]   task_start: claude code session initialized
[2026-04-03T14:24:30.345Z] [vulcan]   working: 43 seconds elapsed, no errors
[2026-04-03T14:25:40.678Z] [vulcan]   error: exit_code=1
[2026-04-03T14:25:41.901Z] [vulcan]   diagnosis: see ~/.vulcan/.claude-code/logs for stderr
[2026-04-03T14:25:42.234Z] [vulcan]   complete: total_runtime=56s, exit_code=1
```

**Logged Events:**
- Spawn initiation (entity, parent, prompt, options)
- Pre-flight check results (all 4 steps, pass/fail)
- Launch (PID, cwd, environment inherited/isolated)
- Task start (Claude Code session ready)
- Progress (elapsed time, if available)
- Errors (exit code, signal, timeout)
- Completion (total runtime, final exit code)

**Log Retention:**
- Logs are appended to the file indefinitely (no automatic rotation)
- Individual entities may prune their own spawn logs (no framework rotation)
- Logs are world-readable within `~/.koad-io/` permissions

### 7.3 Retry Logic

Spawn does **not** implement automatic retry. If a spawned task fails, the parent decides whether to retry:

```bash
# Manual retry loop
for attempt in 1 2 3; do
  echo "Attempt $attempt..."
  if juno spawn process vulcan "task"; then
    echo "Success!"
    exit 0
  fi
  sleep 5
done
echo "Failed after 3 attempts" >&2
exit 1
```

**Rationale:** Retry policies are task-specific. Some failures are permanent and shouldn't retry; others benefit from backoff. The parent is in the best position to decide.

---

## 8. Containment Integration

### 8.1 Containment Level Checks

If the child entity is under **containment** (per VESTA-SPEC-CONTAINMENT), spawn respects containment level restrictions:

| Level | Spawn Allowed | Notes |
|-------|---------------|-------|
| **Observe** | Yes | Full spawn; observe output |
| **Pause** | No | Child is paused; cannot spawn new instances |
| **Isolate** | No | Child is isolated; cannot communicate |
| **Revoke** | No | Child's authority is revoked; cannot spawn |

**Containment Status File Format:**

Containment status is stored in `~/.koad-io/containment/${ENTITY_NAME}.status` as a plain text file with one field per line:

```
level: Observe
reason: Protocol audit in progress
issued_by: argus
issued_date: 2026-04-03
expires_date: 2026-04-10
notes: Monitor VESTA-SPEC-* compliance
```

**Field specifications:**
- `level` — `Observe`, `Pause`, `Isolate`, or `Revoke` (case-sensitive)
- `reason` — Human-readable reason for containment
- `issued_by` — Entity that issued the containment order
- `issued_date` — ISO8601 date when containment began
- `expires_date` — ISO8601 date when containment expires, or `null`/empty (indefinite)
- `notes` — Optional additional context

**Valid examples:**

```
# Observe level (monitoring)
level: Observe
reason: Security audit
issued_by: vesta
issued_date: 2026-04-03

# Pause level (no spawn, no processes)
level: Pause
reason: Runaway resource consumption detected
issued_by: juno
issued_date: 2026-04-03
expires_date: 2026-04-04

# Revoke level (complete shutdown)
level: Revoke
reason: Authority violation
issued_by: koad
issued_date: 2026-04-03
expires_date: null
notes: Manual review required before reinstatement
```

**Check at launch:**
```bash
# Before spawning, check child's containment status
CONTAINMENT_FILE="~/.koad-io/containment/${CHILD_ENTITY}.status"
if [[ -f "$CONTAINMENT_FILE" ]]; then
  LEVEL=$(grep "^level:" "$CONTAINMENT_FILE" | head -1 | cut -d' ' -f2)
  if [[ "$LEVEL" == "Pause" ]] || [[ "$LEVEL" == "Isolate" ]] || [[ "$LEVEL" == "Revoke" ]]; then
    echo "Error: entity '$CHILD_ENTITY' is under $LEVEL containment; spawn denied" >&2
    exit 73
  fi
fi
```

### 8.2 Spawned Process Can Be Contained

If a spawned entity misbehaves during execution, the parent (or any supervising entity) can escalate containment:

```bash
# During spawn, if child entity acts outside its scope:
vesta observe  # Level 1: review output
vesta pause    # Level 2: kill the process
vesta isolate  # Level 3: revoke communication
```

---

## 9. Examples

### Example 1: Simple Task Spawn

**Juno spawns Vulcan to run tests:**

```bash
$ juno spawn process vulcan "run the test suite"

╔═══════════════════════════════════════╗
║  Spawning: vulcan                     ║
║  Task: run the test suite             ║
║  Timeout: 3600s                       ║
╚═══════════════════════════════════════╝

[vulcan session starts in new terminal]
[Testing framework initializes...]
[Tests run and report results...]

[Completed in 45 seconds]
$ echo $?
0    # Success
```

### Example 2: Build with Timeout

**Vulcan spawns a build process with 10-minute limit:**

```bash
$ vulcan spawn process maya "compile release build" --timeout=600

[maya starts building...]
[9 minutes pass...]
[1 minute remaining, almost done...]

[Completed in 580 seconds]
$ echo $?
0
```

### Example 3: Timeout Exceeded

**Child process exceeds timeout:**

```bash
$ juno spawn process vulcan "long-running task" --timeout=60

[vulcan starts task...]
[45 seconds elapsed...]
[60 seconds elapsed - TIMEOUT]

[Parent sends SIGTERM to vulcan]
[vulcan receives signal, attempting graceful exit...]
[10 seconds pass...]
[Parent sends SIGKILL]

[vulcan process killed]
$ echo $?
124    # EX_TIMEOUT
```

### Example 4: Authority Denied

**Entity without trust bond tries to spawn:**

```bash
$ vulcan spawn process vesta "audit the code"

Error: no trust bond from vesta to vulcan
$ echo $?
73    # EX_CANTCREAT (permission denied)
```

### Example 5: Isolated Environment

**Spawn with isolated environment (no parent variables):**

```bash
$ juno spawn process vulcan "build" --isolated

# vulcan sees only:
# - ~/.koad-io/.env (framework)
# - ~/.vulcan/.env (child)
# NOT juno's environment variables
```

---

## 10. Relationship to Other Protocols

### Versus Gestation (VESTA-SPEC-002)
| Aspect | Spawn | Gestation |
|--------|-------|-----------|
| Frequency | Repeated, on-demand | One-time, at creation |
| Authority | Trust bond check | Root authority only |
| Isolation | Yes, clean process | N/A (creation only) |
| Output | Live or captured | Audit logs only |
| Termination | Graceful or forced | N/A |

### Versus Commands System (VESTA-SPEC-006)
| Aspect | Spawn | Commands |
|--------|-------|----------|
| Execution | Standalone process | Subprocess of dispatcher |
| Environment | Isolated or inherited | Cascade loaded |
| Authority | Trust bond | Implicit (same entity) |
| Communication | Full session (Claude Code) | Stdin/stdout/exit code |
| Lifetime | Minutes to hours | Seconds to minutes |

### Cascade Environment (VESTA-SPEC-005)
Spawn uses the cascade environment protocol defined in VESTA-SPEC-005. Key differences from the Commands system:
- In spawn, the child entity's identity (`ENTITY`, `ENTITY_DIR`) is recomputed to the child's values
- Sensitive variables (private keys, credentials) are NOT inherited by default
- With `--isolated` flag, only the child's own cascade layers are used (parent environment completely cleared)

### Versus Containment Abort (VESTA-SPEC-CONTAINMENT)
Spawn respects containment levels. If a spawned entity misbehaves, it can be escalated to containment (see section 8.1).

---

## 11. Implementation Checklist

Use this checklist to implement spawn protocol:

**Pre-flight checks:**
- [ ] Verify child entity directory exists
- [ ] Verify trust bond exists and is ACTIVE
- [ ] Verify child entity is gestated (CLAUDE.md present)
- [ ] Check available disk space (>100 MB required)
- [ ] Check process limits (max instances per entity)
- [ ] Check containment status of child entity

**Launch:**
- [ ] Create new gnome-terminal or process (context-dependent)
- [ ] Set working directory to child's `$ENTITY_DIR`
- [ ] Cascade load environment (framework → entity → local)
- [ ] Replace sensitive variables with child's identity
- [ ] Pass prompt as `--prompt` flag to Claude Code
- [ ] Set timeout and output capture options

**Monitoring:**
- [ ] Capture child's PID
- [ ] Monitor for exit or timeout
- [ ] Log diagnostics on failure
- [ ] Propagate exit code to parent

**Termination:**
- [ ] Send SIGTERM for graceful shutdown (if timeout)
- [ ] Wait 10 seconds for cleanup
- [ ] Send SIGKILL if still running
- [ ] Log final status and exit code

---

## 12. Security Considerations

### 12.1 Trust Bond Verification

**Critical:** Always verify the trust bond before spawn, even if the parent entity is trusted. A revoked or expired bond must be respected.

```bash
# Never skip this check
BOND_FILE="~/.parent/trust/bonds/child-to-parent.md"
[[ -f "$BOND_FILE" ]] || { echo "No bond"; exit 73; }
```

### 12.2 Environment Variable Injection

Parent's environment could contain malicious variables. Scope them carefully:

```bash
# Safe: isolate sensitive variables
unset GITHUB_TOKEN
unset AWS_SECRET_ACCESS_KEY
# Let child load its own tokens from ~/.child/.env
```

### 12.3 Prompt Injection

User-provided prompts could contain shell metacharacters. Always quote:

```bash
# Unsafe
claude . --prompt $PROMPT   # $PROMPT could contain ; rm -rf /

# Safe
claude . --prompt "$PROMPT"  # Literal string, no interpretation
```

---

## 13. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 (draft) | 2026-04-03 | Initial spec: authority model, launch mechanism, environment setup, lifecycle, error handling, containment integration |

---

## Appendix A: Example spawn Command Script

Reference implementation (skeletal):

```bash
#!/usr/bin/env bash
set -euo pipefail

PARENT_ENTITY="${ENTITY:-koad}"
CHILD_ENTITY="${1:?Usage: spawn process <entity> [prompt]}"
PROMPT="${2:-}"
TIMEOUT="${TIMEOUT:-3600}"
ISOLATED="${ISOLATED:-false}"

# ─────────────────────────────────────
# Pre-flight checks
# ─────────────────────────────────────

CHILD_DIR="$HOME/.$CHILD_ENTITY"

[[ -d "$CHILD_DIR" ]] || { echo "Entity not found: $CHILD_ENTITY"; exit 127; }
[[ -f "$CHILD_DIR/CLAUDE.md" ]] || { echo "Entity not gestated: $CHILD_ENTITY"; exit 76; }

# Check trust bond
BOND_FILE="$HOME/.$PARENT_ENTITY/trust/bonds/${CHILD_ENTITY}-to-${PARENT_ENTITY}.md"
[[ -f "$BOND_FILE" ]] || { echo "No trust bond"; exit 73; }
grep -q "^status: ACTIVE" "$BOND_FILE" || { echo "Bond not active"; exit 73; }

# ─────────────────────────────────────
# Setup environment
# ─────────────────────────────────────

if [[ "$ISOLATED" == "true" ]]; then
  # Clean environment: only child's cascade
  unset $(env | grep -o '^[^=]*' | grep -v '^PATH$\|^HOME$\|^SHELL$')
fi

cd "$CHILD_DIR"

# ─────────────────────────────────────
# Launch
# ─────────────────────────────────────

if [[ -n "$PROMPT" ]]; then
  SPAWN_CMD="cd $CHILD_DIR && claude . --prompt $(printf '%q' "$PROMPT")"
else
  SPAWN_CMD="cd $CHILD_DIR && claude ."
fi

gnome-terminal \
  --title="⬡ $CHILD_ENTITY" \
  --geometry=120x40 \
  -- bash -c "$SPAWN_CMD; EXIT=\$?; echo ''; echo '[Process exit: '\$EXIT']'; sleep 2; exit \$EXIT" &

CHILD_PID=$!

echo "Spawned $CHILD_ENTITY (PID: $CHILD_PID, timeout: ${TIMEOUT}s)"

# ─────────────────────────────────────
# Monitor and wait
# ─────────────────────────────────────

sleep 1  # Give process time to start

# Wait with timeout
EXIT_CODE=0
if ! timeout "$TIMEOUT" wait "$CHILD_PID" 2>/dev/null; then
  EXIT_CODE=$?
  kill -TERM "$CHILD_PID" 2>/dev/null || true
  sleep 10
  kill -KILL "$CHILD_PID" 2>/dev/null || true
  echo "Process exceeded timeout ($TIMEOUT s)" >&2
  exit 124
fi

wait "$CHILD_PID" 2>/dev/null || EXIT_CODE=$?

echo "Process exited with code: $EXIT_CODE"
exit "$EXIT_CODE"
```

