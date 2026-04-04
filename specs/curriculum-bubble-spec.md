---
status: draft
id: VESTA-SPEC-025
title: "Curriculum Bubble Spec — Progressive Learning Format (Extension of VESTA-SPEC-016)"
type: spec
version: 1.0
date: 2026-04-04
owner: vesta
description: "Canonical spec for the curriculum bubble subtype — a bubble format designed for progressive learning, not session replay. Defines knowledge atoms, levels, prerequisites, exit criteria, loading contract, and peer ring licensing."
related-specs:
  - VESTA-SPEC-016 (Context Bubble Protocol — parent format)
  - VESTA-SPEC-001 (Entity Model)
  - VESTA-SPEC-007 (Trust Bond Protocol)
  - VESTA-SPEC-014 (Kingdom Peer Connectivity Protocol)
  - VESTA-SPEC-026 (Chiron Entity Specification)
request-source: juno (curriculum architecture gap identified 2026-04-04, Chiron entity concept)
---

# VESTA-SPEC-025: Curriculum Bubble Spec

**Authority:** Vesta (platform stewardship). This spec defines the curriculum bubble as a formal subtype of the context bubble (VESTA-SPEC-016), and specifies the authoring workflow, loading contract, and peer ring licensing rules.

**Scope:** The curriculum bubble format, schema, authoring workflow by Chiron, loading and delivery by Alice, implementation surface for Vulcan, and peer ring sharing rules.

**Consumers:**
- Chiron — authors curriculum bubbles per this spec
- Alice — loads and delivers curriculum bubbles to humans
- Vulcan — implements the progression tracking system described in Section 6
- Muse — reads curriculum structure for visual presentation (does not modify)
- Argus — audits curriculum bubble conformance to this spec
- Salus — heals deviations per Section 9

**Status:** Draft. Requires Juno review and koad approval.

---

## 1. How a Curriculum Bubble Differs from an Experiential Bubble

VESTA-SPEC-016 defines the **experiential context bubble**: an ordered playlist of session moments showing how thinking evolved. Its intent is *recording and replaying reasoning* — the reader experiences how understanding was built.

A **curriculum bubble** is a different beast with a different intent:

| Dimension | Experiential Bubble (VESTA-SPEC-016) | Curriculum Bubble (this spec) |
|-----------|--------------------------------------|-------------------------------|
| **Intent** | Record how thinking evolved | Teach a learner something specific |
| **Author's perspective** | Archivist (capturing what happened) | Teacher (structuring for the learner) |
| **Content** | Session moments, discoveries, corrections | Knowledge atoms, levels, exit criteria |
| **Sequence** | Chronological (how it happened) | Pedagogical (how it should be learned) |
| **Completion** | No completion — it's a record | Tracked: levels marked complete, prerequisites enforced |
| **Feedback loop** | None (record is immutable) | Alice feeds back learner confusion; Chiron revises |
| **Audience** | Entity or human wanting to understand reasoning | Learner working through a topic |
| **Modification** | Owner can amend; peers get read-only | Chiron revises; version controlled; Alice gets updated |

**The key distinction:**

An experiential bubble asks: *"What happened?"*
A curriculum bubble asks: *"What does the learner need to know, and in what order?"*

Both use the bubble format (signed markdown, portable, peer-shareable), but they are designed for fundamentally different purposes.

### 1.1 What They Share

Curriculum bubbles inherit from VESTA-SPEC-016:
- **File format:** Signed markdown with frontmatter
- **Signing protocol:** Saltpack signature over full file content (VESTA-SPEC-007)
- **Peer ring sharing rules:** Mediated by sponsorship tier (extended in Section 8)
- **Ownership:** Source kingdom owns; shared copies are read-only
- **Location convention:** `~/.{entity}/bubbles/curricula/{curriculum-slug}/`

### 1.2 What Is New

Curriculum bubbles introduce:
- `type: curriculum-bubble` (distinct from `context-bubble`)
- A `levels` array with per-level prerequisites, atoms, objectives, and exit criteria
- `knowledge atoms` as the unit of content
- A completion state model (levels can be `locked`, `available`, `in-progress`, `complete`)
- A loading contract for how Alice loads a curriculum into a session
- Peer ring licensing terms for curriculum sharing

---

## 2. Schema

### 2.1 Frontmatter

```yaml
---
type: curriculum-bubble
id: <UUID-v4>
slug: <lowercase-hyphenated-identifier>
title: <Human-readable curriculum title>
description: <What the learner can do after completing all levels>
version: <semver: 1.0.0>
authored_by: chiron
authored_at: <ISO-8601-UTC>
owned_by: <kingdom-fqdn>
signature: <saltpack-signature>

# Prerequisite curricula (other curriculum bubble IDs)
# A learner must complete all listed curricula before this one is available.
prerequisites:
  - <curriculum-bubble-id>  # or empty list []

# Target audience description (not enforced — informational for Chiron/Alice)
audience: <string>

# Estimated total duration (informational)
estimated_hours: <number>

# Curriculum metadata
level_count: <integer>
atom_count_total: <integer>

# Peer ring licensing (see Section 8)
is_shared: <boolean>
shared_with: []  # list of kingdom-fqdn, or ["*"] for all peers
license: <proprietary | cc-by | cc-by-sa | public-domain>

# Optional: link to issue that commissioned this curriculum
commissioned_by: <issue-url>
---
```

### 2.2 Body Structure

```markdown
# Curriculum: <title>

## Overview

<2-3 sentences: what this curriculum teaches and why it matters>

## Entry Prerequisites

<What the learner must already know/have done before starting Level 1.>
<Be explicit. "Basic CLI familiarity" is not enough — state exactly what is assumed.>

## Completion Statement

After completing all levels in this curriculum, the learner will be able to:
- <verb + specific outcome 1>
- <verb + specific outcome 2>
- <verb + specific outcome 3>

---

## Level 1: <Level Title>

<!-- Level metadata block (machine-readable, human-readable) -->
```yaml
level: 1
slug: <level-slug>
title: <Level Title>
status: available  # locked | available | in-progress | complete
prerequisites:
  - curriculum_complete: []   # curriculum-bubble IDs that must be complete
  - level_complete: []        # level numbers within this curriculum that must be complete
estimated_minutes: <integer>
atom_count: <integer>
```

### Learning Objective

After completing this level, the learner will be able to:
> <Single, specific, testable statement. Verb + outcome. Not vague.>

**Why this matters:** <1-2 sentence motivation for learning this specific level>

### Knowledge Atoms

#### Atom 1.1: <Atom Title>

**Teaches:** <single thing this atom teaches, one sentence>

<Content: explanation, example, code snippet, or analogy — whatever teaches the one thing>

---

#### Atom 1.2: <Atom Title>

**Teaches:** <single thing>

<Content>

---

[... additional atoms ...]

### Exit Criteria

The learner has completed this level when they can:
- [ ] <Specific, verifiable criterion 1>
- [ ] <Specific, verifiable criterion 2>

**How Alice verifies:** <How Alice (or the learner self-assessing) confirms the exit criteria are met. Concrete. Not "the learner understands" — describe an observable action or correct answer.>

### Assessment

**Question:** <A question the learner should be able to answer if they've met the exit criteria>

**Acceptable answers:**
- <Answer variant 1>
- <Answer variant 2>

**Red flag answers (indicates level should be revisited):**
- <Common misconception or failure mode>

---

## Level 2: <Next Level Title>

[... same structure ...]

---

## Curriculum Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | <date> | Initial authoring |

---

## References

- Commissioned by: <issue-url>
- Research source: <Sibyl brief or other reference>
- Delivered by: Alice (<entity-fqdn>)
- Progression system: Vulcan implementation

---

**Signature:**
```
-----BEGIN SALTPACK SIGNED MESSAGE-----
...
-----END SALTPACK SIGNED MESSAGE-----
```
Signed by: chiron@<kingdom-fqdn>
```

---

## 3. Knowledge Atoms

### 3.1 Definition

A **knowledge atom** is the smallest loadable unit of knowledge in a curriculum bubble. It teaches exactly one thing.

**Properties of a valid atom:**
- Has a single, specific `Teaches:` declaration
- Cannot be split further without losing meaning
- Is self-contained: a learner can read the atom in isolation and understand the one thing it teaches
- Does not assume knowledge from a later atom in the same level
- Is ordered within its level: earlier atoms establish what later atoms need

**The one-thing test:** Read the atom and ask "What does this teach?" If the answer is compound ("X and Y"), the atom teaches two things — split it into Atom N and Atom N+1.

### 3.2 Atom Naming Convention

Atoms are numbered hierarchically: `{level}.{atom}` — e.g., Atom 1.3 is the third atom in Level 1.

Slugs: `{level-number}-{atom-number}-{short-description}`, e.g., `1-3-what-is-a-daemon`

### 3.3 Atom Size Guidelines

**Not a hard limit, but a calibration:**
- Too small: "What is SSH?" (This is a fact, not a teachable unit — fold into a broader atom)
- Too large: "How the koad:io entity lifecycle works" (This is a curriculum, not an atom — split into a level)
- Right size: "What a passenger.json file is and why every entity has one"

If an atom takes more than 5 minutes to read, consider splitting it. If it takes less than 30 seconds, consider merging with a neighboring atom.

### 3.4 Atom Content Types

Atoms may use any of these content forms:

| Type | When to Use |
|------|-------------|
| Explanation | Abstract concept: what something is, why it exists |
| Example | Concrete illustration: "Here is what this looks like in practice" |
| Command/code | Hands-on atom: run this, see this output |
| Analogy | Bridge from known to unknown |
| Contrast | Two things that look similar but differ in important ways |
| Definition | Precise vocabulary term the rest of the curriculum depends on |

An atom may combine types (e.g., explanation + example), but should still teach only one thing.

---

## 4. Level Structure and Stacking

### 4.1 Level Prerequisites

Level N is available to a learner when:
1. The learner has completed all levels listed in that level's `prerequisites.level_complete` array within the same curriculum, AND
2. The learner has completed all curricula listed in `prerequisites.curriculum_complete`

**Level 1 of any curriculum:** Prerequisites are only those of the curriculum itself (the `prerequisites` field in the curriculum frontmatter). Level 1's own `prerequisites.level_complete` MUST be an empty list.

**Open question OQ-001:** Should prerequisite checking be strict (system enforces) or advisory (Alice warns but allows)? Proposed answer: Strict in Vulcan's progression system (a locked level cannot be loaded); Alice can note "you may find this hard without Level N" but cannot override locks. Mark for Juno/Vulcan to finalize on implementation.

### 4.2 Level Status Model

```
locked → available → in-progress → complete
              ↑            |
              |            ↓
              +--- (reset) ---+
```

| Status | Meaning | Who Sets It |
|--------|---------|-------------|
| `locked` | Prerequisites not met | Vulcan's progression system |
| `available` | Prerequisites met; learner may begin | Vulcan (auto, when prereqs complete) |
| `in-progress` | Learner has started (first atom loaded) | Vulcan (triggered by first load) |
| `complete` | Learner has met exit criteria | Alice marks complete after assessment |

**The `complete` status is set by Alice**, not automatically by the system. Exit criteria require Alice to assess the learner; the system cannot auto-complete a level based on time-on-page or atom views.

### 4.3 Stacking Across Curricula

Curricula themselves can be prerequisite-gated:

```
alice-onboarding (Level 1-12)
  → entity-operations (requires: alice-onboarding complete)
    → advanced-trust-bonds (requires: entity-operations Level 4+ complete)
```

This stacking is declared in each curriculum's frontmatter `prerequisites` field. Vulcan's progression system enforces it. Chiron maintains the global prerequisite graph in `~/.chiron/curricula/REGISTRY.md`.

### 4.4 Level Revision and Re-Lock

If Chiron revises a level (e.g., content changed significantly), Vulcan's system may re-lock later levels that depended on the revised content. The revision mechanism is:

1. Chiron increments the curriculum `version` (semver minor bump for content changes, patch for typos)
2. Chiron notes in the CHANGELOG which levels were revised and whether they are "breaking" (require re-completion) or "non-breaking" (learner need not re-do)
3. Vulcan's system reads the CHANGELOG on load and applies re-lock only for breaking changes

---

## 5. Loading Contract

### 5.1 What "Loading" a Curriculum Bubble Means

Loading a curriculum bubble into an entity's context window is the act of making the curriculum content available for a delivery session. This is distinct from *delivering* the curriculum (which Alice does interactively with a human).

The loading contract specifies:
- What Alice loads (not the whole curriculum at once)
- When Alice loads it
- How Alice tracks position
- How the daemon supports loading

### 5.2 Alice's Loading Protocol

When a human begins or resumes a curriculum session:

1. **Alice reads the curriculum registry** (`~/.chiron/curricula/REGISTRY.md`) to locate the curriculum by slug
2. **Alice loads the curriculum frontmatter** to verify prerequisites and read the completion statement
3. **Alice loads the learner's current state** from Vulcan's progression database (current level, completed levels, in-progress level)
4. **Alice loads only the current level's content** — NOT the entire curriculum. This enforces progressive disclosure: Alice does not read ahead.
5. **Alice delivers that level** interactively (reads atoms, asks assessment questions, marks exit criteria)
6. **Alice marks level complete** by writing a completion record (see Section 5.3)
7. **Alice loads the next available level** (if the learner continues in the same session)

**Enforcement of progressive disclosure:** Alice MUST NOT read atoms from a level the learner has not yet reached, with one exception: Alice may read the *title* of upcoming levels to answer "what's next?" — but not the content.

### 5.3 Completion Records

When Alice marks a level complete, Alice writes a completion record:

```yaml
---
type: curriculum-completion
curriculum_id: <UUID>
curriculum_slug: <slug>
level: <integer>
learner_id: <human-identifier or entity-name>
completed_at: <ISO-8601-UTC>
assessed_by: alice
assessment_summary: <Brief note: what the learner said that met exit criteria>
---
```

This record is stored at:
```
~/.alice/learners/{learner-id}/curricula/{curriculum-slug}/level-{N}-complete.md
```

Vulcan's progression system reads these records to compute `level_status`.

### 5.4 Daemon Support for Loading

The daemon MUST support these operations for curriculum loading:

```
GET /api/v1/curricula/{slug}
  → Returns curriculum frontmatter + level index (title, status per learner, slug per level)
  → Does NOT return level content (that's Alice's job to read from file)

GET /api/v1/curricula/{slug}/levels/{level-number}
  → Returns full level content (atoms, exit criteria, assessment)
  → Returns 403 if level is locked for this learner

POST /api/v1/curricula/{slug}/levels/{level-number}/complete
  → Body: { learner_id, assessment_summary }
  → Sets level status to complete, unlocks next level
  → Requires Alice entity trust bond (chiron-to-alice bond authorizes this)

GET /api/v1/curricula/{slug}/learner/{learner-id}/state
  → Returns: { current_level, completed_levels: [], locked_levels: [], available_levels: [] }
```

---

## 6. Alice's Use of Curriculum Bubbles for the 12-Level Onboarding Path

### 6.1 The Curriculum

Alice's 12-level onboarding curriculum is authored by Chiron and lives at:
```
~/.chiron/curricula/alice-onboarding/
├── SPEC.md              ← VESTA-SPEC-025 format curriculum bubble
├── levels/
│   ├── 01-what-is-koadio.md
│   ├── 02-sovereign-identity.md
│   ├── 03-entity-model.md
│   ├── 04-gestation.md
│   ├── 05-trust-bonds.md
│   ├── 06-commands-and-hooks.md
│   ├── 07-daemon-and-kingdom.md
│   ├── 08-peer-rings.md
│   ├── 09-team-entities.md
│   ├── 10-github-issues-protocol.md
│   ├── 11-context-bubbles.md
│   └── 12-operating-an-entity.md
└── assessments/
    └── exit-criteria.md
```

**Open question OQ-002:** Are the above level titles final? They are Chiron's first responsibility to validate and potentially reorder. Chiron should review this list in its first session and revise. The 12-level count is fixed by the concept ("Alice's 12 levels"); the titles and content are Chiron's domain.

### 6.2 How Alice Delivers the 12-Level Path

Alice does not present the full 12 levels to a new human. Alice:

1. **Greets the human** and establishes that this is a structured onboarding (not a free-form conversation)
2. **Loads Level 1** from the curriculum bubble (via the loading contract in Section 5.2)
3. **Delivers Level 1** atom by atom, in order, interactively
4. **Assesses the human** against Level 1's exit criteria
5. **Marks Level 1 complete** and unlocks Level 2
6. **Asks the human** if they want to continue to Level 2 or pause and resume later
7. **At any resume:** Alice loads the learner's current state from Vulcan's progression database and picks up at the next available level

Alice does not skip levels. If a human claims to already know the content of a level, Alice may offer an accelerated assessment (ask the exit-criteria questions directly), but cannot skip the completion marking step.

### 6.3 Session Continuity Across Alice Sessions

The onboarding can span multiple sessions (human pauses and returns). Session continuity relies on:

1. Vulcan's progression database (knows which levels are complete)
2. The learner's `~/.alice/learners/{learner-id}/` directory (completion records)
3. Alice's session start protocol: always reads learner state before delivering

This is the responsibility of Vulcan's implementation, not Alice's session memory.

---

## 7. Chiron's Authoring Workflow

### 7.1 How a Curriculum Commission Works

1. **Commission arrives** as a GitHub Issue on `koad/chiron` with:
   - A curriculum brief (topic, target audience, desired outcomes)
   - A research brief from Sibyl (optional but recommended)
   - The commissioner (Juno or koad)

2. **Chiron assesses prerequisites** for the curriculum:
   - What must a learner already know to enter this curriculum?
   - Does an existing curriculum cover those prerequisites, or must Chiron author one first?
   - Chiron reports back to the issue with the prerequisite map before authoring

3. **Chiron writes exit criteria first** — For the whole curriculum, then for each level, then for each atom. Content comes after. This is non-negotiable.

4. **Chiron sequences levels** — Determines the pedagogical order. The sequence must satisfy: no level requires knowledge that a later level introduces. Validate the sequence explicitly.

5. **Chiron authors atoms** — Level by level, atom by atom. Each atom is written with the exit criterion it serves in mind.

6. **Chiron writes assessments** — After content is authored, assessments are written or revised to validate that the exit criteria are testable.

7. **Chiron commits the curriculum** to `~/.chiron/curricula/{slug}/`, pushes, and comments on the issue with the curriculum location.

8. **Alice reviews** the curriculum before it is delivered — Alice reads the full curriculum and may file feedback on `koad/chiron` before delivery begins. Alice does not modify the curriculum directly.

### 7.2 Authoring a Knowledge Atom

Atom authoring checklist:

- [ ] `Teaches:` declaration written first
- [ ] One-thing test applied: atom teaches exactly one concept
- [ ] Content is self-contained: no implicit dependency on unlabeled prior knowledge
- [ ] Ordered correctly within the level: earlier atoms don't require later atoms
- [ ] Size calibration: not too large (>5 min read), not too trivially small
- [ ] At least one example or concrete illustration included (for non-definition atoms)

### 7.3 Versioning Curriculum Bubbles

Curriculum bubbles use semantic versioning:

- **Patch** (1.0.0 → 1.0.1): Typos, clarifications that do not change what a learner does to meet exit criteria. Alice need not re-deliver.
- **Minor** (1.0.0 → 1.1.0): New atoms added, existing atoms rewritten to teach more clearly. Learners in-progress are not re-locked; completed levels remain complete.
- **Major** (1.0.0 → 2.0.0): Exit criteria changed, level structure reorganized, prerequisites changed. Vulcan's system may re-lock affected levels for all learners (breaking change). Chiron MUST document this in the CHANGELOG with a migration note.

### 7.4 Feedback Integration

After Alice delivers a level, Alice may file a feedback note on `koad/chiron`:

```
Issue title: "alice-onboarding Level 3 — learner confusion at Atom 3.2"
Body:
  - 3 of 5 learners paused at Atom 3.2 (trust bonds)
  - Common confusion: conflating outbound bonds with inbound bonds
  - Proposed fix: add a contrast atom (Atom 3.2b) before the outbound bond atom
  - Severity: non-blocking, but slows delivery by ~10 minutes
```

Chiron reviews Alice's feedback and decides whether to revise. Alice does not revise the curriculum.

---

## 8. Peer Ring Model and Licensing

### 8.1 How Curriculum Bubbles Relate to the Peer Ring

Curricula are sovereign knowledge assets. They are not automatically shared when two kingdoms peer. Sharing a curriculum with a peer kingdom is an explicit act by the authoring kingdom.

### 8.2 Licensing Model

Every curriculum bubble MUST declare a `license` in the frontmatter:

| License | Meaning | Use Case |
|---------|---------|----------|
| `proprietary` | No sharing outside the authoring kingdom without explicit agreement | Premium curricula, client-specific content |
| `cc-by` | Shareable with attribution | Community curricula, open onboarding |
| `cc-by-sa` | Shareable; derivative curricula must carry same license | Curricula intended to propagate as commons |
| `public-domain` | No restrictions | Foundational content the ecosystem benefits from freely |

**Alice's 12-level onboarding curriculum** is proposed as `cc-by` — Alice's onboarding is the koad:io entryway; restricting it limits ecosystem growth. koad to confirm on commission.

**Open question OQ-003:** Should Chiron have a `curriculum-license` policy document that koad approves, so Chiron doesn't make per-curriculum licensing decisions? This would prevent Chiron from accidentally giving away premium content. Mark for Juno/koad to decide.

### 8.3 Peer Ring Sharing Rules

When two kingdoms peer, curriculum bubbles are shared only when:

1. The curriculum has `is_shared: true` in frontmatter
2. The license is not `proprietary` (proprietary curricula require explicit license agreement, separate from the peer connection)
3. The peer kingdom has sufficient tier to receive curriculum bubbles (see below)

**Tier requirements for curriculum bubble access:**

| Tier | Can Receive Curricula? | Conditions |
|------|----------------------|------------|
| free | No | Must upgrade |
| basic | Yes, `public-domain` only | Foundational content only |
| pro | Yes, `cc-by` and `cc-by-sa` | Must attribute source kingdom |
| enterprise | Yes, all non-proprietary | Full access; proprietary requires separate agreement |

### 8.4 What Travels in a Shared Curriculum Bubble

When a peer kingdom receives a shared curriculum bubble, they receive:
- Full curriculum content (all levels, all atoms, all exit criteria)
- The authoring signature (Chiron's Saltpack signature — VESTA-SPEC-016 Section 4.4)
- The license and usage terms
- The prerequisite declarations

They do NOT receive:
- Learner completion records (those are sovereign to Alice's kingdom)
- Research briefs from Sibyl (internal to the authoring kingdom)
- Feedback notes from Alice's sessions (internal)

### 8.5 Derivative Curricula

If a peer kingdom modifies a received curriculum and re-shares it, this is a **derivative curriculum**. Rules:

- `cc-by-sa` licenses require the derivative to carry `cc-by-sa`
- Derivatives must acknowledge the original curriculum in their frontmatter:
  ```yaml
  derived_from:
    curriculum_id: <original-UUID>
    curriculum_slug: <original-slug>
    source_kingdom: <source-fqdn>
    changes: <brief description of what changed>
  ```
- The derivative's Chiron (or equivalent) signs the derivative with their own entity's key — the original Chiron's signature does not apply to the derivative
- Derivative curricula are tracked in Chiron's registry as separate entries

### 8.6 Curriculum Revocation for Shared Bubbles

If the authoring kingdom revokes a shared curriculum (e.g., content was wrong, safety issue):

- The revocation mechanism from VESTA-SPEC-016 Section 8.3 applies
- Peer daemons receive revocation via the standard revocation endpoint
- Peer Alice entities are notified via `bubble:revoked` message type
- Active learners in-progress on the revoked curriculum are paused; Alice delivers: "This curriculum has been updated and will be re-available shortly" rather than abandoning the learner mid-level

---

## 9. Audit and Healing Criteria

### 9.1 Argus Audit Criteria

Argus verifies curriculum bubble conformance against:

1. **Format conformance** — Frontmatter contains all required fields; `type: curriculum-bubble`
2. **Signature validity** — Saltpack signature over full content (excluding signature line) must verify against Chiron's public key
3. **Level numbering** — Levels are numbered sequentially from 1 with no gaps
4. **Atom numbering** — Atoms within each level are numbered sequentially with no gaps
5. **Exit criteria present** — Every level has a non-empty `Exit Criteria` section
6. **Learning objective present** — Every level has a `Learning Objective` with a verb + specific outcome
7. **Prerequisite self-consistency** — If Level N lists Level M as a prerequisite, M < N
8. **Assessment present** — Every level has an `Assessment` section with at least one question
9. **License declared** — Frontmatter `license` field is one of the four canonical values
10. **Version valid** — Frontmatter `version` is valid semver

### 9.2 Salus Healing Criteria

Salus can repair these deviations:

1. **Unsigned curriculum** → Flag for Chiron to re-sign; do not deliver until signed
2. **Missing exit criteria on a level** → Mark level as `needs-review`, block delivery of that level, alert Chiron via issue
3. **Broken prerequisite reference** (points to non-existent curriculum) → Mark prerequisite as `unresolvable`, alert Chiron; curriculum may still be delivered but prerequisite enforcement is suspended until resolved
4. **Learner state inconsistency** (completion records don't match Vulcan's database) → Vulcan's database is authoritative; reconcile completion records to match

---

## 10. File Location Reference

### Curriculum Bubble Files (Chiron's registry)

```
~/.chiron/curricula/
├── REGISTRY.md                          ← Index: slug, title, status, level_count, version
├── {curriculum-slug}/
│   ├── SPEC.md                          ← The curriculum bubble (VESTA-SPEC-025 format)
│   ├── levels/
│   │   ├── {NN}-{slug}.md               ← Per-level content files
│   │   └── ...
│   └── assessments/
│       └── exit-criteria.md             ← Overall curriculum completion criteria
```

### Learner State Files (Alice's registry)

```
~/.alice/learners/
├── {learner-id}/
│   ├── curricula/
│   │   ├── {curriculum-slug}/
│   │   │   ├── level-{N}-complete.md    ← Completion record per level
│   │   │   └── state.md                 ← Current state summary
│   │   └── ...
│   └── profile.md                       ← Learner summary (non-PII; optional)
```

### Shared Curriculum Files (received via peer ring)

```
~/.{entity}/bubbles/shared-in/{source-kingdom}/curricula/
├── {curriculum-slug}-{date}-{uuid-short}.md   ← Full curriculum bubble (read-only)
```

---

## 11. Open Questions

| ID | Question | Status | Proposed Resolver |
|----|----------|--------|------------------|
| OQ-001 | Should level prerequisite enforcement be strict (system enforces) or advisory (Alice warns)? | Open | Juno + Vulcan to finalize on implementation |
| OQ-002 | Are the 12 onboarding level titles provisional? Should Chiron validate/revise them in first session? | Open | Chiron to confirm in first session |
| OQ-003 | Should Chiron have a curriculum-license policy doc approved by koad, to prevent accidental mis-licensing? | Open | Juno/koad |
| OQ-004 | What is the learner_id scheme? GitHub username? Operator-assigned UUID? Should it be sovereign (not tied to any external service)? | Open | Vulcan + Vesta |
| OQ-005 | Should Alice be able to suggest reordering atoms during delivery (without changing the curriculum)? Or must she deliver strictly in order? | Open | Chiron + Alice to decide in first collaboration session |

---

## 12. References

- **VESTA-SPEC-016** — Context Bubble Protocol (parent format)
- **VESTA-SPEC-001** — Canonical Entity Model
- **VESTA-SPEC-002** — Canonical Gestation Protocol
- **VESTA-SPEC-007** — Trust Bond Protocol
- **VESTA-SPEC-009** — Daemon Specification (API endpoints)
- **VESTA-SPEC-014** — Kingdom Peer Connectivity Protocol (peer ring tiers)
- **VESTA-SPEC-026** — Chiron Entity Specification
- **Chiron** — Author of all curriculum bubbles
- **Alice** — Delivery entity, primary consumer of curriculum bubbles
- **Vulcan** — Implements progression system, daemon endpoints
- **Sibyl** — Research source for curriculum content

---

**VESTA-SPEC-025** — Curriculum Bubble Spec  
Extension of VESTA-SPEC-016. Formal subtype for progressive learning.  
Status: Draft — Requires Juno review and koad approval.  
Date: 2026-04-04  
Owner: Vesta
