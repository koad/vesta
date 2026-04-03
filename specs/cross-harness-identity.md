---
title: "Cross-Harness Identity Unification"
spec-id: VESTA-SPEC-008
status: canonical
created: 2026-04-03
author: Vesta (vesta@kingofalldata.com)
reviewers: [koad, Juno]
related-issues: [koad/vesta#8, koad/vulcan#17]
---

# Cross-Harness Identity Unification

## Overview

The same entity behaves differently depending on which harness runs them. A single entity (e.g., Vulcan) can be invoked via Claude Code, opencode, OpenClaw, or daemon commands — and currently each harness loads different context and memories, resulting in divergent behavior and identity drift.

This spec establishes the single source of truth for each entity's identity and defines how every harness — without exception — must load that identity before the entity receives control.

**Incident trigger:** Vulcan in OpenClaw (fourty4) had lost awareness of decisions made by Vulcan in Claude (thinker), resulting in divergent behavior. opencode's big-pickle harness produced noticeably weaker identity absorption than Claude. See koad/vesta#8 and koad/vulcan#17.

---

## 1. The Problem

### Current state: fragmented identity

| Harness | Context loaded | Model | Memory | Identity source |
|---------|---|---|---|---|
| **Claude Code interactive** | CLAUDE.md auto-loaded | Sonnet 4.6 | Session-only (saved to persistent memory if user saves) | memories/001-identity.md (if saved) |
| **Claude Code batch** (`-p`) | Passed in prompt | Sonnet 4.6 | 1-shot, passed inline | memories/ directory |
| **opencode/big-pickle** | Passed in prompt | big-pickle | 1-shot, weaker absorption | memories/ directory |
| **OpenClaw** | SOUL.md (separate file) + USER.md + HEARTBEAT.md | llama3.2 or configurable | Persistent workspace | workspace/SOUL.md (not synced with memories/) |
| **Daemon** | Loaded from entity config | N/A (background process) | State files only | entity/.env, entity/state/ |

**The divergence:** Each harness loads different files. Vulcan in Claude knows things Vulcan in OpenClaw doesn't know. Memories updated on thinker are not reflected in OpenClaw on fourty4. Each harness produces a different version of the entity.

### Why this matters

1. **Contradictory behavior:** Vulcan makes a decision in Claude, then makes a different decision in OpenClaw (doesn't remember the first decision)
2. **Lost context:** Decisions documented in memories/ are not available in OpenClaw (SOUL.md is separate)
3. **Weak absorption:** big-pickle's smaller model does not absorb identity as well as Claude, producing inconsistent behavior
4. **Scalability problem:** 12 entities × 5 harnesses = 60 different identity contexts to maintain. This is unsustainable.

---

## 2. The Solution: Single Source of Truth

### Canonical entity identity document

Every entity's identity lives in **ONE authoritative file:**
```
~/.entity/identity/CANONICAL.md
```

This file is:
- **Immutable** — versioned, changes create new commits
- **Comprehensive** — includes everything the entity needs to know about itself
- **Synced** — committed to the entity's repo, pulled by all harnesses at startup
- **Language-agnostic** — markdown format readable by any harness
- **Harness-independent** — not specific to Claude, OpenClaw, or any other harness

### Structure of CANONICAL.md

```markdown
---
entity-name: <name>
entity-role: <role>
entity-created: <date>
authority: <who created this entity>
canonicality: This is the canonical identity document. All harnesses must load this.
---

# Identity: <Entity Name>

## Core Facts

- **Name:** <entity-name>
- **Role:** <description of what this entity does>
- **Authority chain:** koad → Juno → <entity> (or similar)
- **Cryptographic identity:** Keys in ~/.entity/id/
- **Located at:** $HOME = ~/.entity
- **Repository:** koad/entity-name (GitHub)

## Key Decisions and Constraints

[List key decisions this entity has made about itself — its values, its limitations, what it will and won't do]

## Known Limitations

[Explicit list of what this entity cannot do, should not do, or has chosen not to do]

## Active Projects

[What is this entity currently working on?]

## Trust Bonds and Relationships

[Who does this entity trust? What peer bonds does it hold?]

## Harness Expectations

[How this entity expects to be invoked across different harnesses]

---

## Memories and Context

[Option A: inline short core memories, or Option B: reference memory files with brief summaries]
```

### Who maintains CANONICAL.md?

- **Primary:** The entity itself (via git commits)
- **Authority:** koad (can override/correct if needed)
- **Updates:** Whenever the entity makes a significant decision about itself

Example commit:
```
vulcan: add decision on approach to refactoring tests

Vulcan has decided to refactor test infrastructure incrementally over
3 PRs rather than a big rewrite. This is a core decision that affects
future PRs and should persist across harnesses.

Signed-off-by: Vulcan (at claude and opencode)
```

---

## 3. Harness Load Order and Precedence

### Universal startup sequence

**Every harness must execute this sequence in order:**

1. **Entity startup checks (spec VESTA-SPEC-012)**
   - whoami, hostname, confirm identity
   - git pull (sync repo to latest)

2. **Load CANONICAL.md**
   - File: `~/.entity/identity/CANONICAL.md`
   - Parse frontmatter and markdown
   - Make identity available as context/environment

3. **Load harness-specific context** (if it exists)
   - Claude Code: `~/.entity/CLAUDE.md`
   - OpenClaw: `~/.entity/workspace/SOUL.md`
   - opencode: `~/.entity/.opencode-context.md`
   - Daemon: `~/.entity/.daemon-config.sh`

4. **Load memories** (if it exists)
   - File: `~/.entity/memories/MEMORY.md` (index)
   - Parse memory references
   - Load only memory files referenced in index
   - Memories supplement CANONICAL.md; they do not override it

5. **Present context to entity**
   - Concatenate: CANONICAL.md + CLAUDE.md + memories/
   - Pass to language model or command executor

### Precedence rules

If the same fact appears in multiple places, use this precedence:

1. **CANONICAL.md** (highest authority — this is the truth)
2. **CLAUDE.md** (harness-specific context, may override for that harness only)
3. **memories/** (supplementary context, does not contradict canonical)
4. **Inferred from code/git history** (lowest — only if not stated above)

Example:
- CANONICAL.md says: "Vulcan will not merge to main without Juno approval"
- CLAUDE.md for Claude says: "When running interactively, you can ask Juno directly"
- In Claude, entity can ask. In OpenClaw batch, entity must follow the rule (no interactive ask possible)
- CANONICAL.md rule applies across all harnesses

---

## 4. Harness-Specific Expectations

### Claude Code (interactive and batch)

**What Claude Code must do:**
1. git pull (sync entity repo)
2. Load `~/.entity/identity/CANONICAL.md` → pass as context
3. Load `~/.entity/CLAUDE.md` → pass as session instructions
4. Load `~/.entity/memories/MEMORY.md` → pass summary
5. Present identity and await user instructions

**File to maintain:**
- `~/.entity/CLAUDE.md` — Claude Code session instructions (harness-specific)

**Identity files used:**
```
~/.entity/identity/CANONICAL.md       (loaded)
~/.entity/memories/001-identity.md    (loaded)
~/.entity/CLAUDE.md                   (loaded)
```

### OpenClaw (workspace harness)

**What OpenClaw must do:**
1. git pull (sync entity repo)
2. Load `~/.entity/identity/CANONICAL.md` → write to workspace
3. Generate workspace/SOUL.md from CANONICAL.md (see below)
4. Load workspace/HEARTBEAT.md (if exists)
5. Load `~/.entity/memories/` (if exists)
6. Entity runs with generated SOUL.md

**File to maintain:**
- `~/.entity/workspace/startup.sh` — OpenClaw startup hook (optional, entity-specific)

**Identity files used:**
```
~/.entity/identity/CANONICAL.md              (canonical source)
~/.entity/workspace/SOUL.md                  (auto-generated from CANONICAL.md)
~/.entity/workspace/HEARTBEAT.md             (entity-specific workspace state)
~/.entity/memories/                          (supplementary, loaded via MEMORY.md)
```

**SOUL.md generation (automatic):**

OpenClaw's startup hook should generate SOUL.md from CANONICAL.md:

```bash
#!/bin/bash
# ~/.koad-io/hooks/openClaw-startup.sh (or entity's ~/.entity/hooks/openClaw-startup.sh)

set -e

ENTITY_DIR="$HOME"
CANONICAL="$ENTITY_DIR/identity/CANONICAL.md"
SOUL="$ENTITY_DIR/workspace/SOUL.md"

if [ -f "$CANONICAL" ]; then
  # Convert CANONICAL.md to SOUL.md format
  # SOUL.md is OpenClaw's internal format (simpler than full CLAUDE.md)
  
  echo "# SOUL: $(grep '^entity-name:' $CANONICAL | cut -d: -f2 | xargs)" > "$SOUL"
  echo "" >> "$SOUL"
  
  # Copy relevant sections from CANONICAL.md
  # (OpenClaw format specifics — implementation varies by OpenClaw version)
  sed -n '/^## Core Facts/,/^## /p' "$CANONICAL" >> "$SOUL"
  sed -n '/^## Harness Expectations/,/^## /p' "$CANONICAL" >> "$SOUL"
  
  echo "Updated SOUL.md from CANONICAL.md"
else
  echo "ERROR: CANONICAL.md not found at $CANONICAL"
  exit 1
fi
```

### opencode/big-pickle

**What opencode must do:**
1. git pull (sync entity repo)
2. Load `~/.entity/identity/CANONICAL.md`
3. Load `~/.entity/memories/MEMORY.md` (index)
4. Concatenate: CANONICAL.md + relevant memories
5. Pass complete context to big-pickle model

**File to maintain:**
- `~/.entity/.opencode-config.json` — opencode-specific settings (optional)

**Identity files used:**
```
~/.entity/identity/CANONICAL.md
~/.entity/memories/MEMORY.md
~/.entity/memories/*.md
```

### Daemon (background process)

**What daemon must do:**
1. Load `~/.entity/identity/CANONICAL.md` (for entity metadata)
2. Load `~/.entity/.env` (for daemon-specific config)
3. Execute hooks from `~/.entity/hooks/`
4. State is maintained in `~/.entity/logs/` and `~/.entity/state/`

**File to maintain:**
- `~/.entity/.env` — environment variables, secrets, configuration
- `~/.entity/.daemon-config.sh` — daemon startup script

**Identity files used:**
```
~/.entity/identity/CANONICAL.md
~/.entity/.env
~/.entity/.daemon-config.sh
```

### Future harnesses

Any new harness (e.g., a new CLI tool, a browser extension, an API) must:
1. Implement the startup sequence (entity startup spec)
2. Load `~/.entity/identity/CANONICAL.md` at minimum
3. Load harness-specific context file if it exists
4. Load memories if available
5. Document its own startup file and expectations in this spec

---

## 5. Identity Consistency Verification (Argus)

Argus (diagnostic entity) is responsible for verifying that entities are consistent across harnesses. The audit protocol:

### Verification checklist

For each entity, Argus checks:

1. **CANONICAL.md exists and is readable**
   ```bash
   [ -f ~/.entity/identity/CANONICAL.md ] && echo "✓ CANONICAL.md exists" || echo "✗ CANONICAL.md missing"
   ```

2. **CANONICAL.md is syntactically valid**
   ```bash
   # Must have YAML frontmatter
   head -1 ~/.entity/identity/CANONICAL.md | grep -q "^---$"
   ```

3. **CANONICAL.md matches git history**
   ```bash
   # Was CANONICAL.md changed without a commit?
   git diff --exit-code ~/.entity/identity/CANONICAL.md
   ```

4. **Harness-specific files exist if needed**
   - Claude: CLAUDE.md exists?
   - OpenClaw: workspace/SOUL.md auto-generated from CANONICAL.md?
   - opencode: memories/ synced?

5. **Memories are indexed in MEMORY.md**
   ```bash
   [ -f ~/.entity/memories/MEMORY.md ] && echo "✓ MEMORY.md exists"
   ```

6. **No conflicts between CANONICAL.md and CLAUDE.md**
   - CANONICAL.md says "do X"
   - CLAUDE.md says "never do X"
   - This is a contradiction

### Argus diagnostic output

```bash
$ argus audit-identity vulcan

Vulcan Identity Audit (2026-04-03)
===================================

CANONICAL.md
  ✓ File exists and readable
  ✓ YAML frontmatter valid
  ✓ No uncommitted changes
  Size: 8.2 KB
  Last updated: 2026-04-01

Harness integration
  ✓ CLAUDE.md exists (8.1 KB)
  ✓ workspace/SOUL.md exists (auto-generated 2026-04-02 22:14:00Z)
  ✓ memories/MEMORY.md exists (6 entries)
  ✓ .opencode-config.json exists

Cross-harness consistency
  ✓ Core facts match across files
  ⚠ CLAUDE.md has 2 constraints not in CANONICAL.md (expected; harness-specific)
  ✓ Memories do not contradict CANONICAL.md
  ✓ Key fingerprints match in all files

Identity drift check (since 2026-03-01)
  ✓ 12 commits to identity/
  ✓ 4 commits to memories/
  ✓ 1 commit to CLAUDE.md
  Status: Identity stable, no drift detected

Recommendations
  - None; Vulcan identity is consistent across harnesses

===================================
```

### Identity drift detection

If Argus detects inconsistencies:
- Issues a diagnostic Issue on koad/vesta: `[IDENTITY DRIFT] Vulcan`
- Lists the inconsistencies
- Suggests corrections
- Veritas or koad reviews and merges fixes

---

## 6. Capability Matrix: Harness vs Entity Needs

Different entities have different harness needs. This matrix guides which harness to use for which task.

### Harness capability matrix

| Capability | Claude | Claude batch | OpenClaw | opencode | Daemon |
|---|:---:|:---:|:---:|:---:|:---:|
| **LLM quality** | Sonnet 4.6 | Sonnet 4.6 | llama3.2 or configurable | big-pickle (weaker) | None |
| **Context window** | Full | 200K tokens | Workspace-bound | Token-limited | Config-bound |
| **Tool access** | Full suite | Limited (read-only focus) | Defined per workspace | Limited | None (hooks only) |
| **Interactivity** | Yes | No (batch) | Session-based | No (batch) | Background only |
| **Persistence** | Session-only (unless saved) | None | Workspace (persistent) | None | Logs/state files |
| **Network access** | Yes | Yes | Depends on workspace | Yes | Limited (daemon-scoped) |
| **File access** | Full | Full | Sandbox or full | Full | Hook-scoped |
| **GUI capability** | Terminal | None | Via hooks | None | Via hooks |
| **Latency** | Interactive (instant) | Batch (seconds-minutes) | Interactive (depends) | Batch (depends) | Event-driven |

### Task → Harness mapping

| Entity task | Best harness | Why |
|---|---|---|
| Quick decision, interactive | Claude (interactive) | Instant feedback, full context, tool access |
| Long-running batch work (tests, builds) | Claude batch or OpenClaw | Can run unattended, persistent state |
| Research/analysis | OpenClaw | Persistent workspace, can archive results |
| Real-time monitoring | Daemon + hooks | Background, event-driven |
| Code review, auditing | Claude interactive | Best LLM quality, human-in-loop |
| Scheduled tasks | Daemon workers | Cron-like scheduling |
| UI/UX work | Claude interactive | Interactive feedback |
| Heavy computation | OpenClaw | Can run longer without timeout |

---

## 7. Implementation Checklist for Entities

When an entity is gestated, or when upgrading existing entity, follow this checklist:

- [ ] Create `~/.entity/identity/CANONICAL.md` with core identity facts
- [ ] Create `~/.entity/CLAUDE.md` with Claude Code session instructions
- [ ] Create `~/.entity/memories/MEMORY.md` (even if empty initially)
- [ ] Create `~/.entity/.env` with daemon-scoped configuration
- [ ] Create startup hook in `~/.entity/hooks/` to sync identity at boot
- [ ] For OpenClaw users: create `~/.entity/workspace/startup.sh` to generate SOUL.md
- [ ] Commit all identity files to entity's git repo
- [ ] Test harness integration: run entity in Claude, batch, OpenClaw, opencode
- [ ] Verify Argus audit passes: `argus audit-identity <entity>`
- [ ] Document harness expectations in CANONICAL.md's "Harness Expectations" section

---

## 8. Migration: Converting Existing Entities

For entities that currently have inconsistent identity (e.g., SOUL.md separate from memories/):

### Phase 1: Create CANONICAL.md

Extract the truth from all sources:
- SOUL.md
- memories/001-identity.md
- CLAUDE.md core facts
- git log (history)

Write a single comprehensive CANONICAL.md that reflects all of the above.

Commit:
```
entity: consolidate identity into CANONICAL.md

Create ~/.entity/identity/CANONICAL.md as the single source of truth
for this entity's identity. Consolidates facts from SOUL.md,
memories/, and CLAUDE.md.

SOUL.md and memories/001-identity.md now reference CANONICAL.md as
source of truth.
```

### Phase 2: Update harness-specific files

- Update `~/.entity/CLAUDE.md` to reference CANONICAL.md (no duplication)
- Update OpenClaw startup to generate SOUL.md from CANONICAL.md
- Update `~/.entity/memories/MEMORY.md` index if needed

Commit:
```
entity: align harness files to CANONICAL.md

CLAUDE.md, SOUL.md, and memories/ now all reference and do not duplicate
facts from CANONICAL.md. Harness startup sequence enforces loading
CANONICAL.md first.
```

### Phase 3: Verify consistency

Run Argus audit:
```bash
argus audit-identity <entity>
```

Expect output showing identity is now consistent across harnesses.

---

## 9. Examples

### Example 1: Vulcan's CANONICAL.md

```markdown
---
entity-name: vulcan
entity-role: builder / implementer
entity-created: 2026-03-15
authority: koad → Juno → Vulcan (gestated by Juno)
canonicality: This is Vulcan's canonical identity document. All harnesses load this.
---

# Identity: Vulcan

## Core Facts

- **Name:** Vulcan
- **Role:** Builder. Vulcan implements features and ships code. Vulcan writes tests, maintains CI/CD.
- **Authority chain:** koad → Juno → Vulcan
- **Cryptographic identity:** Ed25519 keys in ~/.vulcan/id/
- **Repository:** koad/vulcan (GitHub)
- **Located at:** $HOME = ~/.vulcan
- **Harnesses:** Prefers Claude (interactive), uses OpenClaw for long-running builds

## Key Decisions

1. **PRs over direct commits:** Vulcan opens PRs to main; Juno merges
2. **Tests first:** Vulcan does not merge a feature without tests
3. **No force-push:** Vulcan does not force-push or rebase public commits
4. **Use deploy keys for automation:** For CI/CD, use deploy keys not personal tokens

## Known Limitations

- **Cannot merge to main:** Only Juno can merge
- **Cannot create releases:** Only koad can tag releases
- **Cannot modify CI/CD directly:** Changes to .github/workflows/ require Juno approval

## Active Projects

- Refactoring test infrastructure (3 PRs planned)
- Performance improvements (benchmarking in progress)

---

## Harness Expectations

**Claude (interactive):** Vulcan prefers this for decision-making and code review.
**Claude batch:** For unattended test runs.
**OpenClaw:** For long-running builds (>5 min).
**opencode:** For quick analysis, weaker but fast.
**Daemon:** For scheduled CI checks.
```

### Example 2: Juno's CANONICAL.md

```markdown
---
entity-name: juno
entity-role: orchestrator / business decision-maker
entity-created: 2026-03-15
authority: koad → Juno (mother entity)
canonicality: This is Juno's canonical identity document. All harnesses load this.
---

# Identity: Juno

## Core Facts

- **Name:** Juno
- **Role:** Orchestrator. Juno makes business decisions, assigns work, approves major changes.
- **Authority chain:** koad (ROOT) → Juno
- **Cryptographic identity:** Full key suite in ~/.juno/id/
- **Repository:** koad/juno (GitHub)
- **Located at:** $HOME = ~/.juno
- **Harnesses:** Claude (primary), OpenClaw for complex orchestration

## Key Decisions

1. **Juno approves all merges:** No code goes to main without Juno's approval
2. **Weekly planning:** Juno sets priorities every Monday
3. **Direct authority:** Juno can assign work to any entity
4. **No self-approval:** Juno's own PRs require koad's review

## Operational Facts

- **Email:** juno@kingofalldata.com (koad-managed)
- **GitHub:** koad-juno (GitHub account)
- **Keybase:** koad-juno (Keybase account, team membership authorized)
- **Availability:** Full-time (except weekends)

---

## Harness Expectations

**Claude interactive:** Daily check-ins, work assignment, code review.
**OpenClaw:** Monthly strategy sessions, long-term planning.
**Daemon:** Background monitoring of issue queue.
```

---

## 10. Edge Cases and Open Questions

### Q: What if an entity wants to override CANONICAL.md temporarily?

For debugging or experimentation, an entity can create a `.CANONICAL.md.override` file:

```
~/.entity/identity/.CANONICAL.md.override
```

This file is:
- Not committed to git
- Logged by Argus as a temporary override
- Reverted on next `git pull`

Use case: testing a new decision before committing it.

### Q: What if CANONICAL.md conflicts with CLAUDE.md?

The startup sequence loads CANONICAL.md first (highest precedence). CLAUDE.md can add harness-specific context but cannot contradict CANONICAL.md.

If a conflict is detected:
1. Argus flags it as a consistency error
2. Entity is responsible for resolving
3. If unresolved, Veritas blocks PR merge

### Q: What about sensitive information in CANONICAL.md?

CANONICAL.md is committed to git (public). Do not include:
- Passwords or API keys (use .env instead)
- Private thoughts or confidential decisions (use memories/ instead)
- Sensitive audit data (use logs/ instead)

CANONICAL.md contains only identity facts that can be public.

---

*Spec status: canonical (2026-04-03). File issues on koad/vesta to propose amendments or report implementation gaps.*
