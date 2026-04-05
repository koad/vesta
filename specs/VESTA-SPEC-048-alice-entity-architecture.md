---
status: canonical
id: VESTA-SPEC-048
title: "Alice Entity Architecture — Hook Behavior, State Management, Curriculum Loading, Session Resumption, Multi-Learner Routing"
type: spec
version: 1.0
date: 2026-04-05
owner: vesta
related-specs:
  - VESTA-SPEC-044 (Alice Conversation Protocol — session state format)
  - VESTA-SPEC-047 (Alice Session Sync Model — single-device constraint)
  - VESTA-SPEC-025 (Curriculum Bubble Spec — content loading contract)
  - VESTA-SPEC-026 (Chiron Entity Specification)
  - VESTA-SPEC-012 (Entity Startup Specification)
  - VESTA-SPEC-033 (Signed Executable Code Blocks)
  - VESTA-SPEC-049 (Alice CLI Interface)
resolves:
  - koad/alice#1 (Alice entity architecture for live deployment)
---

# VESTA-SPEC-048: Alice Entity Architecture

**Authority:** Vesta (platform stewardship). This spec defines how Alice runs as a koad:io entity — her hook behavior for learner sessions and operator sessions, how learner state is created and routed, how Alice loads curriculum from Chiron, how she resumes suspended sessions, and how multiple concurrent learners are supported on a single Alice instance.

**Scope:** `hooks/executed-without-arguments.sh` behavior, learner UUID lifecycle, curriculum file path contract, session resumption flow, multi-learner routing.

**Consumers:**
- Vulcan — implements Alice entity, hook, and CLI commands
- Chiron — authors curriculum that Alice loads; observes the file path contract
- Alice — the entity that runs under this architecture
- Argus — audits learner directory conformance

**Status:** Canonical. Depends on VESTA-SPEC-044 for session state file formats. Depends on VESTA-SPEC-025 for curriculum bubble content structure.

---

## 1. Alice Is Different

All other koad:io entities are invoked by operators — koad, Juno, Vulcan — for specific work. Their `executed-without-arguments.sh` hooks open a working session with the operator at the keyboard, or reject a non-interactive prompt.

Alice inverts this pattern. Alice is not invoked by operators for business tasks. She is invoked by **learners** who want to learn. A learner is not an operator. A learner does not know the koad:io system yet. A learner may be opening Alice for the first time, with no UUID, no state directory, no prior context.

This changes the hook's behavior entirely:

| Dimension | Standard operator entity (Juno) | Alice |
|-----------|--------------------------------|-------|
| Interactive path | Opens working session | Opens learner session — new or resume |
| Non-interactive path | Rejected (`PROMPT` via pipe) | Accepted for operator commands (see §2.3) |
| Context preloaded | Operator has full context | Learner has zero context |
| UUID needed | No | Yes — Alice creates or looks up |
| State written | Git commits | `~/.alice/learners/{uuid}/` filesystem |

---

## 2. Hook Behavior — `hooks/executed-without-arguments.sh`

### 2.1 Interactive Path (Learner Session)

When Alice is invoked with no arguments and a TTY is present (`-t 0`), she opens a learner session.

**Pre-flight sequence:**

```
1. ENTITY_DIR verification — Alice confirms she is running in ~/.alice/
2. Learner identification — Alice looks for the most-recent learner UUID on this machine
   a. If ~/.alice/learners/ contains exactly one UUID directory: use that UUID
   b. If ~/.alice/learners/ contains multiple UUID directories: apply multi-learner routing (see §5)
   c. If ~/.alice/learners/ is empty or absent: new learner path (see §3)
3. Curriculum availability check — Alice verifies ~/.chiron/curricula/alice-onboarding/SPEC.md exists
   a. If missing: emit curriculum-missing error (see VESTA-SPEC-049 §6.1)
4. Session state check — Alice reads session-state.md for the identified learner
   a. If session-state.md exists and phase != 'suspended': stale lock handling (see §2.4)
   b. If session-state.md exists and phase == 'suspended': resume path
   c. If session-state.md absent: begin new level (advance to next incomplete level)
5. Launch Claude with learner context prepended to prompt
```

The hook prepares a context block and launches Claude Code in interactive mode:

```bash
exec claude . --model sonnet --dangerously-skip-permissions \
  --append-system-prompt "$ALICE_LEARNER_CONTEXT"
```

`ALICE_LEARNER_CONTEXT` contains:
- Learner's `identity.md` contents (name, UUID, created_at, last_seen_at)
- Session state prose (from `session-state.md`, if resuming)
- Current level number and title
- Confirmation that curriculum is loaded and path is available

Alice uses this context to orient herself before the first message to the learner.

### 2.2 Context Block Format

The learner context block injected into Alice's session is a structured markdown block:

```markdown
## Alice Session Context

**Learner:** Jordan (UUID: a9f3c2e1-7b4d-4f2a-9c8e-123456789abc)
**First seen:** 2026-04-03T10:14:00Z
**Last seen:** 2026-04-05T14:22:00Z
**Current level:** 3 — Keys & Identity
**Curriculum:** ~/.chiron/curricula/alice-onboarding/ (loaded)

**Session state (resuming):**
Level 3 in progress. Learner has acknowledged key-as-identity concept.
Currently discussing the distinction between data ownership and key ownership.
Next: present "your keys are you" summary and ask learner to restate in own words.

**Session phase:** suspended
**Instruction:** Resume where the learner left off. Greet Jordan by name. Reference
what was discussed last. Ask if they are ready to continue.
```

For a new learner (no identity file yet), the context block is:

```markdown
## Alice Session Context

**New learner — no prior state found.**
**Instruction:** Begin with Level 0. Introduce yourself warmly. Ask the learner's
preferred name before anything else. After they confirm a name, generate a UUIDv4
for them and create ~/.alice/learners/{uuid}/identity.md immediately.
```

### 2.3 Non-Interactive Path (Operator Commands)

When Alice receives a `PROMPT` via environment variable or stdin (non-interactive), the hook does **not** reject it. Alice accepts operator commands for administrative purposes:

- `PROMPT="--progress {uuid}"` — emit progress summary for a learner
- `PROMPT="--export {uuid}"` — export learner archive
- `PROMPT="--list-learners"` — list all learner UUIDs with display names and last-seen timestamps

These correspond to the CLI interface defined in VESTA-SPEC-049. The hook pattern:

```bash
if [ -n "$PROMPT" ]; then
  # Non-interactive operator command path
  exec claude -p "$OPERATOR_CONTEXT\n\n$PROMPT" --model sonnet
fi
```

`OPERATOR_CONTEXT` includes Alice's identity, the full learner directory listing, and brief instruction to respond in machine-parseable format when invoked non-interactively.

### 2.4 Stale Lock Handling

If `session-state.md` exists with `phase` set to a non-suspended value (`opening`, `active`, `checkpoint`, `writing`), Alice may have terminated ungracefully. The hook applies this logic:

1. Check `session_updated_at` timestamp in `session-state.md`.
2. If `session_updated_at` is more than 30 minutes ago: treat as stale — overwrite with resumed session at the last known level and phase.
3. If `session_updated_at` is within 30 minutes: warn the operator that a session may be in progress. Prompt for confirmation before proceeding.

The 30-minute threshold is configurable via `~/.alice/.env` (`ALICE_STALE_SESSION_MINUTES`, default `30`).

---

## 3. Learner UUID Lifecycle

### 3.1 UUID Creation

Alice creates a UUIDv4 (random) when and only when:

- A new learner has confirmed their display name
- No prior identity file exists for this learner

**Alice creates the UUID. No external service. No user account.** The UUID is generated within the Claude conversation using a UUID generation utility available in the hook's environment (`uuidgen` or equivalent).

**Timing:** The UUID is generated and `identity.md` is written immediately after the learner confirms their display name. Alice does not wait until level completion. The identity file is the learner's address from their first confirmed name forward.

**Write sequence:**

```
1. Learner confirms display name ("Call me Jordan")
2. Alice generates UUIDv4: a9f3c2e1-7b4d-4f2a-9c8e-123456789abc
3. Alice creates directory: ~/.alice/learners/a9f3c2e1-.../
4. Alice writes: ~/.alice/learners/a9f3c2e1-.../identity.md
5. Alice continues the conversation at Level 0
```

### 3.2 Identity File

Path: `~/.alice/learners/{uuid}/identity.md`

See VESTA-SPEC-044 §2.1 for the full identity file format. Summary of invariants:

- `learner_id` written once, never changed
- `display_name` may be updated if learner requests a name change; Alice confirms before overwriting
- `created_at` written once, never changed
- `last_seen_at` updated by Alice at the **start** of each new session (not end)

### 3.3 UUID Visibility

The UUID is **not shown to the learner** during normal operation. Exceptions:

- On graduation certificate (`certificate.md`), where it appears as the learner's portable credential
- On `alice --progress` output, where it is shown in full for operator/admin use
- In the UUID-based recovery flow (VESTA-SPEC-047 §4.1)

---

## 4. Curriculum Loading

### 4.1 File Path Contract

Alice reads curriculum content from Chiron's directory. The contract:

| Resource | Path |
|----------|------|
| Curriculum spec | `~/.chiron/curricula/alice-onboarding/SPEC.md` |
| Level content | `~/.chiron/curricula/alice-onboarding/levels/level-{NN}.md` |
| Assessments | `~/.chiron/curricula/alice-onboarding/assessments/` |
| Registry | `~/.chiron/curricula/alice-onboarding/REGISTRY.md` |

Level filenames use zero-padded two-digit integers: `level-00.md`, `level-01.md`, ... `level-12.md`.

**Alice never writes to `~/.chiron/`.** She reads only. Chiron owns the write authority on all curriculum files.

### 4.2 Runtime Loading Protocol

Alice loads curriculum content lazily — she loads a level's file when she is about to teach that level, not at session start. This avoids bloating the session context with content the learner has already passed.

**Load sequence for a level:**

```
1. Alice determines current level N from session-state.md (or 0 for new learners)
2. Alice reads ~/.chiron/curricula/alice-onboarding/levels/level-{NN}.md
3. Alice reads the level's atoms, exit_criteria, delivery_notes, and assessment questions
4. Alice begins the level's conversation, using the curriculum content as her guide
```

Alice reads the curriculum bubble format (VESTA-SPEC-025) — specifically:
- `atoms` — the knowledge units to convey
- `exit_criteria` — what the learner must demonstrate before Alice writes a completion record
- `delivery_notes` — Alice's teaching guidance (how to approach the material)
- `assessment_questions` — optional structured prompts Alice may use at checkpoint phase

### 4.3 Curriculum Version Check

When Alice starts a session, she reads `SPEC.md` and notes the `version` field. She also records the version in `session-state.md`:

```yaml
curriculum_version: 1.3.0
```

If the curriculum version changes between sessions (Chiron shipped a revision), Alice notes this on session open:

> "The curriculum has been updated since your last session (now v1.3.0). This shouldn't affect your progress — I'll continue from where we left off."

Alice does **not** invalidate existing completion records when the curriculum version changes. Completion records are permanent. A learner who completed Level 3 under v1.2.0 does not need to redo it under v1.3.0 unless Chiron explicitly revokes the level (a separate process, not in scope for this spec).

### 4.4 Missing Curriculum Handling

If `~/.chiron/curricula/alice-onboarding/SPEC.md` is absent at session start, Alice cannot teach. The hook emits an error and exits:

```
alice: curriculum not found at ~/.chiron/curricula/alice-onboarding/SPEC.md
Chiron's curriculum must be present before Alice can teach.
Is ~/.chiron/ installed? Try: koad-io install chiron
```

See VESTA-SPEC-049 §6.1 for the full error handling specification.

---

## 5. Session Resumption

### 5.1 Resume Protocol

When Alice opens a session for a returning learner (session-state.md exists, phase == 'suspended'):

```
1. Alice reads session-state.md — loads phase, current_level, session_updated_at
2. Alice reads the prose body of session-state.md — her working context from last session
3. Alice loads the curriculum level file for current_level (§4.2)
4. Alice updates last_seen_at in identity.md
5. Alice opens the conversation with a brief orientation greeting
```

**Orientation greeting pattern:**

> "Welcome back, Jordan. When we left off, we were discussing [topic from session-state prose]. Ready to pick up where we left off?"

Alice does **not** re-read the full prior conversation. The session state prose is the context handoff. Alice authored it for herself at suspension time (VESTA-SPEC-044 §6). It contains understanding, not transcript.

### 5.2 Suspension Write

Before the Alice process terminates (graceful shutdown), Alice writes a final `session-state.md` update:

```yaml
phase: suspended
session_updated_at: <current timestamp>
```

With an updated prose body reflecting the conversation's final state.

If Alice terminates ungracefully (kill signal, crash, harness timeout), the last-written `session-state.md` is the recovery point. It will be slightly stale. The stale lock handling in §2.4 applies.

### 5.3 Completion Clears Session State

After Alice writes a level completion record (`level-{N}-complete.md`), she deletes `session-state.md` for that level. The completion record supersedes it.

If the learner continues to the next level in the same session, Alice creates a new `session-state.md` for level N+1 immediately.

---

## 6. Multi-Learner Support

### 6.1 Can Multiple Learners Use the Same Alice?

Yes. A single Alice entity (`~/.alice/`) can serve multiple learners. Each learner has their own UUID directory. There is no conflict between learner state directories.

**However:** Alice is a sequential entity. She cannot conduct two conversations simultaneously on the same process. Multi-learner support is about **routing** (directing each learner to their own state), not about **parallelism**.

### 6.2 Routing on Interactive Open

When `~/.alice/learners/` contains multiple UUID directories, Alice cannot automatically select the right learner. The hook applies this routing logic:

**Route by recency (default):**

1. Alice inspects the `last_seen_at` field in each `identity.md`
2. Alice selects the UUID with the most recent `last_seen_at`
3. Alice opens that learner's session

This is the default because most Alice invocations on a personal machine are by the same person who last used it. The learner does not need to remember their UUID to resume.

**Route by explicit UUID:**

If the operator passes `--resume {uuid}` (VESTA-SPEC-049 §3), Alice routes directly to that UUID, bypassing recency selection.

**Ambiguous case — multiple learners, same recency:**

If two learners have identical `last_seen_at` timestamps (unlikely but possible), Alice presents a disambiguation prompt:

```
Multiple learner sessions found on this machine:
  1. Jordan (last seen 2026-04-05 14:22 UTC)
  2. Theo (last seen 2026-04-05 14:22 UTC)

Which session would you like to resume? (1/2) Or press Enter to start a new session.
```

### 6.3 No Learner Isolation Required

Learner directories are plain filesystem directories under a single user account. There is no user-level isolation between learners. This is by design for Phase 1 (single-operator machine). If Alice runs in a multi-tenant hosted environment, the operator is responsible for OS-level user isolation. That is an infrastructure concern, not an Alice architecture concern.

---

## 7. Directory Structure

```
~/.alice/
  hooks/
    executed-without-arguments.sh    ← This spec's primary subject
  commands/
    progress/                        ← `alice --progress` (VESTA-SPEC-049)
    export/                          ← `alice --export` (VESTA-SPEC-049)
  learners/
    {uuid}/
      identity.md                    ← Written at name confirmation. One per learner.
      curricula/
        alice-onboarding/
          session-state.md           ← Live during session; deleted on level complete
          level-00-complete.md       ← Written by Alice on level pass
          level-01-complete.md
          ...
          level-12-complete.md
          certificate.md             ← Written by Alice on graduation
  .env                               ← Entity config (ALICE_STALE_SESSION_MINUTES, etc.)
  CLAUDE.md                          ← Alice's identity prompt
  id/
    ed25519                          ← Alice's signing key (used for certificate)

~/.chiron/curricula/alice-onboarding/    ← Read-only from Alice's perspective
  SPEC.md
  levels/
    level-00.md
    ...
    level-12.md
  assessments/
```

---

## 8. What This Spec Does Not Cover

- The conversational content of each level — Chiron's domain (VESTA-SPEC-025, VESTA-SPEC-026)
- Certificate issuance and signature verification — `alice-graduation-certificate-protocol.md`
- The `alice` CLI interface — VESTA-SPEC-049
- Session state file format in full detail — VESTA-SPEC-044
- Cross-device sync — VESTA-SPEC-047
- Hosted Alice (kingofalldata.com) deployment specifics — Vulcan's operational concern
