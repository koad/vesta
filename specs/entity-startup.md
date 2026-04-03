---
title: "Entity Startup Specification"
spec-id: VESTA-SPEC-012
status: canonical
created: 2026-04-03
author: Vesta (vesta@kingofalldata.com)
reviewers: [koad, Juno]
related-issues: [koad/vesta#12, koad/juno#47]
---

# Entity Startup Specification

## Overview

All entities must execute a canonical startup sequence before performing any networked operations, external file access, or state-modifying actions. This sequence establishes ground truth about the entity's execution environment (user account, hostname, machine identity) and prevents self-referential loops and misidentified environment assumptions.

**Trigger incident:** Juno at session start attempted SSH from dotsh to dotsh, creating a self-loop and blocking initialization. Root cause: no verification of current hostname before executing outbound commands. See koad/juno#47.

---

## 1. Canonical Startup Sequence

Every entity harness (Claude Code interactive, Claude Code batch, opencode, OpenClaw, etc.) must execute this sequence at session initialization, **before any other actions**:

### Step 1: Establish Identity and Location

```bash
# Establish ground truth about this execution context
CURRENT_USER=$(whoami)
CURRENT_HOST=$(hostname)
CURRENT_HOME=$(pwd)  # or ${HOME} — context-dependent

# Log for audit trail (optional but recommended)
echo "[STARTUP] User: $CURRENT_USER | Host: $CURRENT_HOST | Home: $CURRENT_HOME" >> ~/.STARTUP_LOG
```

**Why this is first:** Before the entity makes ANY external call (SSH, network, API), before it reads ANY config file expecting to apply to THIS machine, the entity must KNOW what "this" means.

**Critical for preventing:** Self-loops, misidentified machine assumptions, entity migrations (thinker → dotsh) where stale config is applied.

### Step 2: Sync with Remote (if git-managed)

```bash
cd $ENTITY_DIR  # e.g., ~/.vesta, ~/.juno, ~/.vulcan
git pull  # Sync repo to latest state
```

**Why after Step 1:** The entity knows which machine it is on, so it can validate whether this pull is expected or anomalous.

### Step 3: State Review and Report

```bash
# Report current state — load any status files, check for pending work
git status --porcelain  # Uncommitted changes?
gh issue list --state open  # Open issues assigned to this entity?
# Entity-specific state checks (check memory, load CLAUDE.md, etc.)
```

**Why after Step 2:** Entity's repo is in sync. Now it can accurately assess what work is pending.

---

## 2. Harness Responsibility

### Claude Code interactive (claude .)

- Automatic: CLAUDE.md auto-loads at session start
- Must add: `whoami` + `hostname` explicitly in CLAUDE.md's session-start hook (see below)
- Memory system: session-only unless user saves to `~/.claude/projects/<project>/memory/`

### Claude Code batch (claude -p, -f flags)

- No interactive CLAUDE.md loading
- Must add: startup sequence to the prompt itself or via pre-prompt hook
- Memory: passed inline as context

### opencode (big-pickle et al)

- Startup: passed via command line flags
- Must guarantee: `whoami`, `hostname` evaluated before entity receives prompt
- Memory: passed inline, 1-shot

### OpenClaw (workspace harness)

- Startup: via `workspace/startup.sh` hook (defined in OpenClaw, not Vesta)
- Must guarantee: SOUL.md is synced from current entity reality before first task
- Workspace persistence: entity state survives across sessions — **extra critical that identity is verified each session**

### Any future harness

- Must implement: whoami + hostname → ENTITY context vars
- Must document: how it guarantees this happens before entity receives control
- Must align: with the canonical sequence above

---

## 3. Entity-Level Implementation in CLAUDE.md

Entities should document their startup expectations in CLAUDE.md (their own session instructions), in the "Session Start" section:

### Template for CLAUDE.md Session Start section

```markdown
## Session Start

1. Verify identity and location:
   - Run: whoami, hostname
   - Confirm you are running as <ENTITY_USER> on <EXPECTED_HOST>
   - If not, STOP and report mismatch before proceeding

2. git pull — sync with remote
   - Working directory: $ENTITY_DIR (e.g., ~/.juno)
   - Fetch latest state from koad repo

3. State review:
   - git status — any uncommitted changes?
   - gh issue list --state open — what work is pending?
   - Check <ENTITY_SPECIFIC_STATUS> (e.g., check memory, check daemon status)

4. Report and proceed
   - Output current state summary
   - Begin work on highest-priority issue
```

### Example: Vesta's Session Start (this entity)

```markdown
## Session Start

1. whoami → vesta, hostname → thinker
   - If different, report mismatch and abort
   - Thinker is Vesta's canonical location (koad's machine)

2. git pull → sync ~/.vesta with koad/vesta

3. State review:
   - git status (should be clean unless in-progress branch exists)
   - gh issue list --state open (5 open spec issues as of 2026-04-03)
   - Loaded MEMORY.md from ~/.claude/projects/-home-koad--vesta/memory/

4. Proceed
   - Report status: X open issues, Y specs in draft, Z specs canonical
   - Work on highest-priority open issue (sorted by dependency)
```

---

## 4. Expected Outputs at Session Start

Every entity session should produce output in this order:

```
[STARTUP] User: <whoami> | Host: <hostname>
[STARTUP] Location: <pwd>
[STARTUP] Syncing: <repo path>
[STARTUP] Git status: <X files changed, Y uncommitted, Z untracked>
[STARTUP] State summary: <entity-specific state>
[STARTUP] Ready.
```

This forms an audit trail. If an entity makes a wrong decision later, the startup log shows whether it had correct identity at that moment.

---

## 5. Special Case: Entity Migrations

### Machine migration scenario

Entity is moving from Machine A to Machine B (e.g., Vulcan migrating from thinker to fourty4 for OpenClaw).

**At startup on new machine:**
1. whoami + hostname → confirm new context
2. Check: does ENTITY_DIR exist on new machine?
3. Check: is `~/.koad-io/` synced?
4. Check: are `.env` overrides correct for new machine?
5. Verify environment before first outbound action

**The startup sequence prevents:** entity making an SSH call based on old machine's config before it realizes it's on a new machine.

### Multi-harness scenario

Entity runs on Claude Code (thinker) AND OpenClaw (fourty4) for the same work.

**Harness 1 (Claude, thinker):** startup sequence confirms thinker context
**Harness 2 (OpenClaw, fourty4):** startup sequence confirms fourty4 context

Each harness maintains its own session state. The entity's identity remains constant across harnesses (same keys, same CLAUDE.md), but the startup sequence confirms each harness knows its own location.

---

## 6. Failure Modes and Recovery

### Startup check fails: wrong user

```
[STARTUP] User: nobody | Host: thinker
[STARTUP ABORT] Expected user: vesta, got: nobody
```

**Recovery:** Restart harness with correct user context.

### Startup check fails: wrong host

```
[STARTUP] User: koad | Host: dotsh
[STARTUP ABORT] Expected host: thinker, got: dotsh
```

**Recovery:** Verify routing and confirm intent. May be legitimate (if entity is supposed to run on dotsh); if unexpected, abort and investigate.

### git pull fails

```
[STARTUP] User: vesta | Host: thinker
[STARTUP] Syncing: ~/.vesta
[ERROR] git pull: cannot access 'koad/vesta': connection refused
[STARTUP ABORT] git pull failed. Check network connection before proceeding.
```

**Recovery:** Resolve network connectivity. Startup is blocked until git succeeds (prevents stale state being used in critical decisions).

### Startup sequence is skipped

An entity proceeds to work without confirming identity.

**Detection:** Argus audit would show entity behavior inconsistent with its canonical context (e.g., attempt to SSH to a host it shouldn't know about).

**Prevention:** Harness enforces startup sequence is not skipped. CLAUDE.md documents this as non-optional.

---

## 7. Audit Trail Requirements

### What must be logged

1. **Timestamp** — when startup executed
2. **User** — whoami output
3. **Host** — hostname output
4. **Directory** — pwd output (or HOME if running remotely)
5. **Git status** — git rev-parse HEAD (commit being used)
6. **Environment** — ENTITY, ENTITY_DIR, HARNESS (e.g., claude, opencode, openclaw)

### Logging mechanism

Entity may log to:
- `~/.STARTUP_LOG` (plaintext, rotated daily)
- `~/.entity/logs/startup.jsonl` (machine-readable)
- Within CLAUDE.md's session-start hook (inline with session)

### Retention

Startup logs retained for:
- Current session: always
- Previous 30 days: in `~/.entity/logs/`
- Annual archive: optional, for compliance/audit

---

## 8. Cross-Harness Consistency

The startup sequence must be **identical in spirit** across all harnesses, differing only in syntax:

| Harness | Startup mechanism | Verification |
|---------|---|---|
| Claude Code | CLAUDE.md session hook + explicit whoami/hostname | Logged to terminal |
| opencode | Via `-p` prompt or pre-prompt hook | Logged to stdout |
| OpenClaw | `workspace/startup.sh` hook | Logged to workspace/STARTUP |
| future | Per harness documentation | Logged to harness-defined location |

All harnesses produce the same output format: `[STARTUP] ...` lines that form an audit trail.

---

## 9. Impact on Other Specs

### Entity gestation (VESTA-SPEC-002)

New entity startup includes running `setup.sh` which should invoke the startup sequence. Gestation template must include this.

### Entity harness spec (VESTA-SPEC-008, cross-harness identity)

Harness consistency requires that all harnesses implement startup identically. This spec is a dependency of that spec.

### Daemon spec (VESTA-SPEC-006)

Daemon startup should also follow this sequence before accepting DDP connections. Daemon is a harness.

### Hooks catalog (VESTA-SPEC-009)

Hooks system depends on entity knowing its own context. Startup sequence is a prerequisite to predictable hook behavior.

---

*Spec status: canonical (2026-04-03). Implementation deadline: all entity CLAUDE.md files updated to include Session Start section by 2026-04-10. File issues on koad/vesta to propose amendments or report implementation gaps.*
