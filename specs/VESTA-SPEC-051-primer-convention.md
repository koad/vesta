---
id: VESTA-SPEC-051
title: PRIMER Convention — Orientation Files for Agent Sessions
status: canonical
created: 2026-04-05
author: Vesta
applies-to: all entities, koad:io framework (hook layer)
supersedes: —
supplements: VESTA-SPEC-020 (entity hook architecture), VESTA-SPEC-012 (entity startup)
---

# VESTA-SPEC-051: PRIMER Convention — Orientation Files for Agent Sessions

## Purpose

Every entity directory contains a `PRIMER.md`. Every major subdirectory with its own working context contains one too. A PRIMER is not documentation — it is an orientation payload injected into an agent session before the user prompt arrives. Its job is to bring a freshly-invoked agent up to current operational state in under 60 seconds of reading.

This spec defines what a PRIMER must contain, where it lives, how hooks inject it, what makes one good versus stale, and when to update it.

---

## 1. What a PRIMER Is

A PRIMER.md is an agent-facing orientation file. It answers the question: **"Where am I and what matters right now?"**

It is not:
- A README (audience: humans visiting the repo)
- A changelog (audience: developers reviewing history)
- A spec (audience: implementers building something)
- A memory file (audience: the entity's own long-term state layer)

It is written to be consumed at the start of an agent session. It assumes the agent has access to git history, the full repo, and any cross-referenced specs. It does not try to be comprehensive — it tries to be current and actionable.

The canonical name is `PRIMER.md`. The file lives in the root of the entity directory (or the root of any major working subdirectory).

---

## 2. Required Contents

A valid PRIMER must include all five sections below. Section order is recommended but not enforced.

### 2.1 Current State (mandatory)

One paragraph or a short bulleted list. Answers: **what is true right now?**

- What has been built and is operational
- What is in progress
- What is blocked and why
- Last meaningful state change (date + what changed)

Example:
```
Current state (2026-04-05): Alice Phase 2A is live on kingofalldata.com (commit 7d95c39).
Hook architecture is stable — FORCE_LOCAL=1 workaround in place. ICM synthesis complete.
Blog PR (#1) is open, blocking Mercury's distribution launch. Chiron is specced but not gestated.
```

### 2.2 Active Assignments (mandatory)

What is this entity currently responsible for? What GitHub Issues are assigned? What has been explicitly delegated?

If there are no active assignments, the section still appears: `No active assignments. Awaiting tasking from koad or Juno.`

Format: GitHub Issue links where applicable, plus a one-line description of what the work is.

### 2.3 Key Facts (mandatory)

The three to seven facts that an agent needs to avoid making a costly mistake in this context. These are not general facts about the entity — they are context-specific facts that are easy to miss and expensive to get wrong.

Examples of appropriate key facts:
- "Vulcan always builds on wonderland — never invoke Vulcan locally"
- "The blog PR (#1) must merge before any Mercury distribution tasks can proceed"
- "fourty4 API auth is broken — don't attempt authenticated API calls from fourty4"
- "The `.env` ships in git; `.credentials` is gitignored and holds secrets"

Examples of inappropriate key facts (too general, not actionable):
- "Juno is a business orchestrator" (belongs in CLAUDE.md, not PRIMER)
- "koad:io uses a two-layer architecture" (belongs in KOAd-IO-CONTEXT.md)

### 2.4 What's Next (mandatory)

The single highest-priority action available right now, followed by the next two to three actions in sequence. If the entity is blocked, state what the block is and what unblocked work is available instead.

Format: ordered list, most urgent first. Each item is one sentence maximum.

```
1. Merge koad/kingofalldata-dot-com#1 — unblocks Mercury's entire distribution pipeline.
2. Gestate Chiron on fourty4 — Vulcan has the spec, needs koad to run koad-io gestate.
3. Write Day 7 video script — Rufus can proceed as soon as the $200 laptop experiment brief is confirmed.
```

### 2.5 Cross-References (optional but strongly recommended)

Links to the specs, issues, memory files, or documents that are most relevant to current operations. Not exhaustive — just the five most important things an agent might need to go read next.

---

## 3. Where PRIMERs Live

### 3.1 Entity Root (required)

Every entity directory (`~/.<entity>/`) must have a `PRIMER.md` in its root. This is the session-start orientation file.

### 3.2 Major Subdirectories (as-needed)

Any subdirectory with its own distinct working context gets its own PRIMER. Examples:

| Directory | PRIMER purpose |
|-----------|---------------|
| `~/.vulcan/packages/` | What packages exist, which are being actively built, what Phase 1 scope is |
| `~/.mercury/distribution/` | What content is staged, what is pending distribution, platform status |
| `~/.alice/curriculum/` | What levels are complete, what Chiron has approved, what is under revision |
| `~/.koad-io/packages/` | What packages are installed, what is staged for release |

Subdirectory PRIMERs are shorter than root PRIMERs. They cover only the working context of that directory. The agent is assumed to have already read the root PRIMER before reaching a subdirectory.

### 3.3 Framework Layer

`~/.koad-io/PRIMER.md` covers the framework layer: installed packages, active daemon status, known issues, what version of koad:io is running.

---

## 4. How Hooks Inject PRIMERs

### 4.1 Pre-Prompt Assembly

The entity hook assembles the agent's starting context before passing the user prompt. PRIMER injection happens at the hook layer — it is not the agent's responsibility to find and read its own PRIMER.

Standard pre-prompt assembly order:

```
1. PRIMER.md (from the working directory's root, or entity root if no subdirectory PRIMER)
2. memories/MEMORY.md (long-term entity memory index)
3. User prompt (passed via -p flag or stdin)
```

The hook concatenates these in order and passes them as the initial prompt. The agent's first action is therefore oriented to the current state rather than starting from scratch.

### 4.2 Hook Implementation Reference

The concrete hook pattern is specified in VESTA-SPEC-020 (entity hook architecture). This spec defines what to inject; SPEC-020 defines how the hook calls `claude -p`.

For the PRIMER specifically:

```bash
# In the entity hook, before the claude invocation:
PRIMER_PATH="${ENTITY_DIR}/PRIMER.md"
if [ -f "${PRIMER_PATH}" ]; then
  PRIMER_CONTENT=$(cat "${PRIMER_PATH}")
  PROMPT="--- PRIMER ---\n${PRIMER_CONTENT}\n--- END PRIMER ---\n\n${PROMPT}"
fi
```

### 4.3 Subdirectory Context

If the agent is invoked with a working directory that is a subdirectory of the entity root, and that subdirectory has its own PRIMER, the hook injects the subdirectory PRIMER instead of (not in addition to) the root PRIMER. The root PRIMER is assumed to have been read in a prior session.

---

## 5. Good PRIMER vs. Stale PRIMER

### 5.1 Signs of a Good PRIMER

- The "Current State" section accurately reflects what happened in the most recent session
- The "Active Assignments" section matches the open GitHub Issues assigned to this entity
- The "What's Next" section would give a freshly-invoked agent enough direction to start working without asking for clarification
- The key facts include the current blockers, not last week's blockers
- It is under 500 words (most agents can hold 500 words of context at working-memory density)

### 5.2 Signs of a Stale PRIMER

- "What's Next" lists work that has already been completed
- "Active Assignments" references issues that are now closed
- "Current State" describes a reality from multiple sessions ago
- The date in the Current State section is more than 48 hours old and the entity has been active
- A freshly-invoked agent following the PRIMER would try to do work that has already been done

Staleness is the primary failure mode. A PRIMER that is wrong is worse than no PRIMER — it confidently misdirects the agent.

### 5.3 The Currency Test

Before committing a PRIMER update, apply this test:

> If an agent read only this PRIMER and nothing else, would it have an accurate picture of what is true right now, what is assigned, and what to do first?

If the answer is no, the PRIMER is not ready to commit.

---

## 6. When to Update

### 6.1 Required Update Triggers

A PRIMER must be updated when any of the following occur:

| Trigger | Why |
|---------|-----|
| Major state change (feature shipped, PR merged, entity gestated) | Current State and What's Next are now wrong |
| New assignment received (GitHub Issue assigned, Juno delegation) | Active Assignments is now incomplete |
| Blocker resolved | Key Facts and What's Next must reflect the unblocked path |
| Blocker added | Key Facts must name the new block |
| Before a long autonomous session | The agent will operate for an extended period on whatever context it starts with |
| After a long autonomous session | Another agent may pick up where this one left off |

### 6.2 PRIMER Updates Are Self-Commits

An entity updating its own PRIMER is a self-commit. It follows the same commit protocol as any self-update: commit and push immediately, do not hold the update. The commit message is:

```
primer: update current state — <one-line description of what changed>
```

Example: `primer: update current state — Alice Phase 2A live, blog PR is now the top blocker`

### 6.3 At Session End

If an entity completes a session that changes operational state, the last act before exiting is to update the PRIMER to reflect the new state. This ensures the next session (whether same entity or a different agent picking up the work) starts with accurate orientation.

---

## 7. PRIMER vs. Other Files

| File | Audience | Currency | Scope |
|------|----------|----------|-------|
| `PRIMER.md` | Agent at session start | Must be current (hours) | This entity, right now |
| `memories/MEMORY.md` | Agent building long-term context | Updated regularly | This entity, accumulated learning |
| `CLAUDE.md` | Agent at any time (injected by harness) | Updated as architecture changes | This entity's architecture and rules |
| `README.md` | Humans visiting the repo | Updated on major milestones | Public-facing identity |
| `LOGS/*.md` | Historical record | One per session, never modified | What happened and when |

The PRIMER is the most time-sensitive file in any entity directory. It degrades faster than any other file because it describes the present, not the permanent.

---

## 8. Relation to Other Specs

| Spec | Relationship |
|------|-------------|
| VESTA-SPEC-020 | Hook architecture — defines how the PRIMER gets injected into `claude -p` invocations |
| VESTA-SPEC-012 | Entity startup sequence — PRIMER injection is step 1 of the startup spec |
| VESTA-SPEC-053 | Entity portability contract — PRIMER.md is a required file for a portable entity |

---

*Filed by Vesta, 2026-04-05. The PRIMER convention emerged from operational experience: agents invoked without current-state orientation consistently re-derive context from git log and CLAUDE.md, which is slower and less accurate than injecting a curated summary. PRIMERs codify the orientation work that would otherwise happen ad hoc at the start of every session.*
