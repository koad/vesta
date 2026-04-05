---
status: canonical
id: VESTA-SPEC-049
title: "Alice CLI Interface — Invocation Flags, UX Flows, Progress Output, Export, Error Cases"
type: spec
version: 1.0
date: 2026-04-05
owner: vesta
related-specs:
  - VESTA-SPEC-048 (Alice Entity Architecture — hook behavior and routing)
  - VESTA-SPEC-044 (Alice Conversation Protocol — session state format)
  - VESTA-SPEC-047 (Alice Session Sync Model — manual transfer path)
  - VESTA-SPEC-025 (Curriculum Bubble Spec — level and exit criteria format)
resolves:
  - koad/alice#2 (Alice CLI design)
---

# VESTA-SPEC-049: Alice CLI Interface

**Authority:** Vesta (platform stewardship). This spec defines what `alice` looks like from the command line — every flag, the UX flow for each, progress output format, export archive format, and how Alice handles errors when the curriculum or learner state is missing or corrupted.

**Scope:** `alice` (no args), `alice --new`, `alice --resume`, `alice --progress`, `alice --export`, error cases.

**Consumers:**
- Vulcan — implements the CLI flags and underlying commands
- Alice — the entity that responds to these invocations
- Learners — the humans who type `alice` into their terminal
- Argus — may consume `--progress` output for monitoring

**Status:** Canonical. Depends on VESTA-SPEC-048 for the hook behavior that underpins these flags.

---

## 1. `alice` — No Arguments

**Description:** Start a new session, or resume the most recent session on this machine. This is the primary invocation. A learner should only ever need to type `alice`.

**Routing logic (delegates to VESTA-SPEC-048 §5.1):**

```
~/.alice/learners/ is empty or absent  →  New learner path (§1.1)
~/.alice/learners/ has exactly one UUID →  Resume that learner (§1.2)
~/.alice/learners/ has multiple UUIDs  →  Resume most-recent by last_seen_at (VESTA-SPEC-048 §6.2)
```

### 1.1 New Learner UX

When no learner state exists, Alice opens a fresh conversation. There is no preamble printed to the terminal before Claude starts. Alice's first message is the welcome. She introduces herself, asks for the learner's name, and begins Level 0.

The conversation is the UX. No banner, no splash screen, no setup wizard. The learner types `alice`, the terminal clears (or a new Claude session begins), and Alice is talking.

**First message pattern (Alice-authored, not templated):**

> "Hi. I'm Alice — I'm here to walk you through what koad:io is and why it was built. Before we get into anything else: what should I call you?"

Alice waits for the name. After the learner replies, Alice confirms:

> "Great — I'll call you Jordan. Let me start with something simple."

Alice then creates `identity.md` with the confirmed name and a fresh UUIDv4 (VESTA-SPEC-048 §3.1). The learner never sees the UUID at this point.

### 1.2 Returning Learner UX

When learner state exists, Alice opens a resumed session. No preamble. Alice's first message is an orientation greeting (VESTA-SPEC-048 §5.1):

> "Welcome back, Jordan. When we left off, we were talking about the difference between data ownership and key ownership. Want to pick up there?"

If the most recent level has a completion record but no session state (learner finished a level cleanly and is returning to start the next), Alice's greeting shifts:

> "Welcome back, Jordan. You completed Level 3 last time — nice work. Ready to move on to Level 4?"

---

## 2. `alice --new` — Explicit New Session

**Description:** Force-start a new learner session, regardless of existing state on this machine.

**Use case:** A second learner on the same machine wants to start their own curriculum. Or a learner wants a fresh start without using their old progress.

**Behavior:**

1. Alice does **not** look up any existing learner UUID.
2. Alice begins the new-learner flow (§1.1): asks for a name, generates a new UUID, creates a new identity file.
3. The new learner's directory is independent of any prior learner directory. No existing state is deleted.

**Warning if multiple learners already exist:**

```
alice: starting a new session. Existing sessions on this machine will not be affected.
(Use 'alice --resume <uuid>' to return to a prior session.)
```

This warning is printed to stderr before Alice starts. It is informational — it does not block the session.

---

## 3. `alice --resume <uuid>` — Explicit Resume by UUID

**Description:** Resume a specific learner session by UUID. Bypasses recency-based routing.

**Use case:**
- A machine has multiple learners and the operator wants to explicitly select one.
- A learner knows their UUID (from their certificate or a prior `--progress` call) and wants to ensure they resume the right session.
- UUID-based recovery from another device (VESTA-SPEC-047 §4.1).

**Behavior:**

1. Alice verifies that `~/.alice/learners/{uuid}/identity.md` exists.
2. If found: opens that learner's session directly, applying the standard resume flow (VESTA-SPEC-048 §5.1).
3. If not found: error (§6.3).

**UUID format:** Full UUIDv4, e.g. `alice --resume a9f3c2e1-7b4d-4f2a-9c8e-123456789abc`

Partial UUID matching (prefix) is **not** supported in Phase 1. Full UUID required.

---

## 4. `alice --progress` — Learner Progress Summary

**Description:** Print a progress summary for the current (or specified) learner. Does not open a conversation session. Exits after printing.

**Invocation variants:**

```bash
alice --progress                        # Summary for the most-recent learner
alice --progress --learner <uuid>       # Summary for a specific learner
alice --progress --all                  # Summary for all learners on this machine
```

### 4.1 Single Learner Output Format

```
Alice Progress — Jordan
UUID: a9f3c2e1-7b4d-4f2a-9c8e-123456789abc
First seen: 2026-04-03
Last seen:  2026-04-05

Curriculum: koad:io Human Onboarding (alice-onboarding v1.3.0)

Level Progress:
  ✓ Level 0  — The First File           completed 2026-04-03 (12 min)
  ✓ Level 1  — First Contact            completed 2026-04-03 (18 min)
  ✓ Level 2  — What Is an Entity?       completed 2026-04-04 (22 min)
  ● Level 3  — Keys & Identity          in progress
  ○ Level 4  — How Entities Trust       locked
  ○ Level 5  — Commands and Hooks       locked
  ○ Level 6  — The Daemon and Kingdom   locked
  ○ Level 7  — Peer Rings               locked
  ○ Level 8  — The Entity Team          locked
  ○ Level 9  — GitHub Issues            locked
  ○ Level 10 — Context Bubbles          locked
  ○ Level 11 — Running an Entity        locked
  ○ Level 12 — The Commitment           locked

Legend: ✓ complete  ● in progress  ○ locked

Levels completed: 3 / 13
Estimated time remaining: ~3.5 hours
```

**Status symbols:**
- `✓` — `level-{N}-complete.md` exists and is well-formed
- `●` — `session-state.md` exists for this level (in progress)
- `○` — neither file exists (locked)

**Exit criteria met** (shown below each completed level when `--verbose` flag is passed):

```
  ✓ Level 0  — The First File           completed 2026-04-03 (12 min)
      Exit criteria met:
        - Created PRIMER.md with a personal description of the koad:io philosophy
        - Read the file back and confirmed what was written
```

### 4.2 All Learners Output Format

```
Alice Learners — this machine

UUID (short)   Display Name   Levels    Last Seen
a9f3c2e1...    Jordan         3 / 13    2026-04-05
f7e2b841...    Theo           1 / 13    2026-04-04

2 learners. Use 'alice --progress --learner <uuid>' for full detail.
```

### 4.3 Machine-Readable Output

When invoked non-interactively (no TTY), `--progress` outputs JSON:

```json
{
  "learner_id": "a9f3c2e1-7b4d-4f2a-9c8e-123456789abc",
  "display_name": "Jordan",
  "curriculum_id": "alice-onboarding",
  "curriculum_version": "1.3.0",
  "levels_complete": 3,
  "levels_total": 13,
  "level_status": [
    { "level": 0, "status": "complete", "completed_at": "2026-04-03T12:14:00Z", "duration_seconds": 720 },
    { "level": 1, "status": "complete", "completed_at": "2026-04-03T14:22:00Z", "duration_seconds": 1080 },
    { "level": 2, "status": "complete", "completed_at": "2026-04-04T09:18:00Z", "duration_seconds": 1320 },
    { "level": 3, "status": "in_progress" },
    ...
  ]
}
```

JSON is emitted to stdout. Errors are emitted to stderr.

---

## 5. `alice --export` — Export Progress Archive

**Description:** Export a learner's full state as a portable archive. Implements the manual transfer path described in VESTA-SPEC-047 §4.2.

**Invocation variants:**

```bash
alice --export                           # Export most-recent learner to ./alice-export-{uuid}.tar.gz
alice --export --learner <uuid>          # Export specific learner
alice --export --output /path/to/file    # Specify output path
```

### 5.1 Archive Contents

The export archive is a gzipped tar of the learner's full state directory:

```
alice-export-a9f3c2e1-2026-04-05.tar.gz
└── learners/
    └── a9f3c2e1-7b4d-4f2a-9c8e-123456789abc/
        ├── identity.md
        └── curricula/
            └── alice-onboarding/
                ├── session-state.md        (if present — in-progress session)
                ├── level-00-complete.md
                ├── level-01-complete.md
                ├── level-02-complete.md
                └── certificate.md          (if graduated)
```

The archive preserves the full directory structure rooted at `learners/`. This allows direct extraction into a `~/.alice/` directory on another machine.

### 5.2 Import Path

To import on another machine:

```bash
tar -xzf alice-export-a9f3c2e1-2026-04-05.tar.gz -C ~/.alice/
```

After extraction, `alice --resume a9f3c2e1-...` will find the learner's state. Alice will resume the session as if the learner had been on this machine all along.

This is the complete manual transfer path (VESTA-SPEC-047 §4.2). No additional infrastructure needed.

### 5.3 Export Output

```
Exporting learner: Jordan (a9f3c2e1-...)
  Levels complete: 3 / 13
  Session state: in progress (Level 3)
  Certificate: not yet issued

Archive written: ./alice-export-a9f3c2e1-2026-04-05.tar.gz (4.2 KB)

To import on another machine:
  tar -xzf alice-export-a9f3c2e1-2026-04-05.tar.gz -C ~/.alice/
```

---

## 6. Error Cases

### 6.1 Curriculum Files Missing

**Trigger:** `~/.chiron/curricula/alice-onboarding/SPEC.md` does not exist when any Alice command is run that requires teaching.

**Affects:** `alice` (no args), `alice --new`, `alice --resume`

**Does not affect:** `alice --progress`, `alice --export` (these read only learner state, not curriculum)

**Error output (stderr):**

```
alice: curriculum not found

Expected: ~/.chiron/curricula/alice-onboarding/SPEC.md
Alice cannot teach without Chiron's curriculum installed.

To fix:
  koad-io install chiron
  # or, if ~/.chiron/ exists but the curriculum is missing:
  cd ~/.chiron && git pull
```

**Exit code:** 1

If the SPEC.md exists but individual level files are missing (partial install), Alice emits a warning and proceeds with the available levels. She notes missing levels as unavailable rather than locked:

```
alice: warning — Level 4 content missing (expected ~/.chiron/curricula/alice-onboarding/levels/level-04.md)
Alice will teach available levels. Run 'cd ~/.chiron && git pull' to restore missing content.
```

### 6.2 Learner State Corrupted

**Trigger:** A file in `~/.alice/learners/{uuid}/` exists but is not parseable as valid YAML-frontmatter markdown.

**Affects:** Any command that reads learner state.

**Corruption cases and responses:**

| Corrupted file | Response |
|---------------|----------|
| `identity.md` — unparseable YAML | Emit error. Refuse to open session. Do not overwrite. Operator must manually inspect or delete. |
| `identity.md` — `learner_id` field missing | Emit error. Same response as above. |
| `session-state.md` — unparseable | Warn. Treat as if `session-state.md` absent. Begin level fresh. Log the issue. |
| `level-{N}-complete.md` — unparseable YAML | Warn. Treat level as incomplete (locked). Do not delete the file. |
| `level-{N}-complete.md` — `learner_id` field does not match UUID directory | Emit error. Treat as locked. This is a data integrity violation. |

**Error output for identity corruption:**

```
alice: learner state corrupted

File: ~/.alice/learners/a9f3c2e1-.../identity.md
Problem: YAML frontmatter could not be parsed

Alice cannot safely continue without a valid identity file.
This file must be inspected and repaired or deleted manually.

To inspect: cat ~/.alice/learners/a9f3c2e1-.../identity.md
To start fresh (CAUTION — loses this learner's progress): rm -rf ~/.alice/learners/a9f3c2e1-.../
```

**Exit code:** 1 for identity corruption; 0 with warning printed for session-state or completion record corruption (session proceeds, degraded).

### 6.3 UUID Not Found (`--resume`)

**Trigger:** `alice --resume {uuid}` is called but `~/.alice/learners/{uuid}/identity.md` does not exist.

**Error output:**

```
alice: learner not found

UUID: a9f3c2e1-7b4d-4f2a-9c8e-123456789abc
No learner state found at ~/.alice/learners/a9f3c2e1-.../

If this learner's state is on another machine, export and import it first:
  # On the other machine:
  alice --export --learner a9f3c2e1-...
  # Then copy the archive here and:
  tar -xzf alice-export-a9f3c2e1-*.tar.gz -C ~/.alice/

To start a new session: alice --new
```

**Exit code:** 1

### 6.4 No Learners Found (`--progress`, `--export` with no UUID)

**Trigger:** `alice --progress` or `alice --export` called when `~/.alice/learners/` is empty or absent.

**Error output:**

```
alice: no learner sessions found on this machine

Run 'alice' to start a new session.
```

**Exit code:** 1

### 6.5 Chiron Not Installed (vs. Curriculum Missing)

The error in §6.1 covers both cases. The distinction:

- `~/.chiron/` does not exist at all → suggest `koad-io install chiron`
- `~/.chiron/` exists but `curricula/alice-onboarding/SPEC.md` is missing → suggest `cd ~/.chiron && git pull`

Alice checks for `~/.chiron/` first. If the directory exists, she assumes Chiron is installed and the curriculum may just need a pull.

---

## 7. Flag Summary

| Flag | Arguments | Description |
|------|-----------|-------------|
| *(none)* | — | New session or resume most-recent learner |
| `--new` | — | Force new learner session |
| `--resume` | `<uuid>` | Resume specific learner by UUID |
| `--progress` | `[--learner <uuid>]` `[--all]` `[--verbose]` | Print progress summary; exits after |
| `--export` | `[--learner <uuid>]` `[--output <path>]` | Export learner archive; exits after |
| `--help` | — | Print usage summary and exit |

---

## 8. Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (session ended normally, or progress/export completed) |
| 1 | Fatal error (curriculum missing, identity corrupted, UUID not found) |
| 2 | Invalid arguments (unrecognized flag, missing required argument) |

---

## 9. What This Spec Does Not Cover

- The conversational content of Alice's sessions — Alice's own judgment and Chiron's curriculum content
- Session state file format — VESTA-SPEC-044
- Hook internals and learner routing logic — VESTA-SPEC-048
- Cross-device sync — VESTA-SPEC-047
- Hosted Alice deployment (kingofalldata.com) — Vulcan's operational concern
- `alice install` or entity gestation — koad-io framework concern
