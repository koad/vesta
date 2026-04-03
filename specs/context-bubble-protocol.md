---
status: draft
id: VESTA-SPEC-016
title: "Context Bubble Protocol — Experiential Knowledge Transfer and Journalistic Records"
type: spec
version: 1.0
date: 2026-04-03
owner: vesta
description: "Canonical protocol for curating, encoding, sharing, and playback of context bubbles — ordered playlists of session moments that transfer human experience between entities and kingdoms"
related-specs:
  - VESTA-SPEC-009 (Daemon Specification)
  - VESTA-SPEC-014 (Kingdom Peer Connectivity Protocol)
  - VESTA-SPEC-011 (Inter-Entity Communications)
request-source: koad (vulcan#9 — playback-machine, context bubbles as journalistic records)
---

# VESTA-SPEC-016: Context Bubble Protocol

**Authority:** Vesta (platform stewardship). This spec defines how koad:io entities and humans create, manage, and share context bubbles — ordered playlists of session moments that encode human experience and reasoning.

**Scope:** Context bubble lifecycle (creation, curation, serialization, sharing, playback), inter-kingdom bubble flow, peer visibility rules, journalistic integrity (verifiability and traceability), and security boundaries for shared bubbles.

**Consumers:**
- Entities (Vulcan, Argus, Salus) — read bubbles for context before sessions, share bubbles with peer kingdoms
- Humans (kingdom operators, researchers) — view/create bubbles via playback-machine renderer
- Daemons — expose bubble registry via peer protocol; bubble sharing mediated by sponsorship tier
- Systems (Argus, Salus) — audit bubbles for conformance; use bubbles as reasoning records

**Status:** Draft. This spec establishes experiential knowledge transfer for the koad:io ecosystem. Implementation begins after koad review.

---

## 1. Philosophy: Why Context Bubbles?

### 1.1 The Problem They Solve

Traditional knowledge transfer is **conclusional**: You read a document and get the answer. You lose the thinking, the dead-ends, the corrections, the uncertainty.

Context bubbles are **experiential**: A human (or AI entity) experiences how someone thought through a problem. The reader sees:
- What was asked
- What evidence was gathered
- What was tried and failed
- What changed minds
- How understanding evolved
- What the final conclusion was

### 1.2 Two Use Cases

**1. Journalism** — A story is not a written article. It's a playlist of moments: sources, reactions, corrections, the evolution of reporting. The reader experiences journalism as it happened, not as it was written up.

**2. Holographic Peer Rings** — When kingdoms peer together (VESTA-SPEC-014), context bubbles flow between them. A daemon shares its reasoning bubble with a peer. The peer experiences how the daemon thinks. Knowledge transfer between sovereign entities becomes experiential, not textual. The peer network becomes a living, shared library of human and artificial reasoning.

### 1.3 Design Principles

1. **Experiential over conclusional** — The bubble is a playlist of moments, not a summary
2. **Verifiable** — Every moment is traceable to its source session; signatures guarantee authenticity
3. **Portable** — A bubble can be shared with another kingdom, carried by a human, rendered in different contexts
4. **Readable** — Humans can read bubbles as markdown; not opaque serialized blobs
5. **Owned** — The source kingdom owns the bubble; shared bubbles are read-only to recipients
6. **Hierarchical** — Bubbles can reference other bubbles (topical chains)

---

## 2. Core Concepts

### 2.1 Anatomy of a Context Bubble

A **context bubble** is an ordered list of moments from one or more sessions, curated around a topic.

```
bubble = {
  id: uuid,
  topic: string,
  tags: [string],
  created_by: entity-name,
  created_at: timestamp,
  owned_by: kingdom-fqdn,
  moments: [
    { session_id, timestamp_start, timestamp_end, content_hash },
    { session_id, timestamp_start, timestamp_end, content_hash },
    ...
  ],
  description: string,
  canonical_chain: [bubble_id, ...],  // parent bubbles this relates to
  signature: saltpack-signature,
  is_shared: boolean,
  shared_with: [kingdom-fqdn],
  read_only: boolean (if shared)
}
```

### 2.2 Moment

A **moment** is a contiguous time window within a session where specific thinking occurred.

**Structure:**
```yaml
session_id: <ENTITY-SESSION-UUID>
timestamp_start: <ISO-8601-UTC>
timestamp_end: <ISO-8601-UTC>
duration_seconds: <integer>
content_hash: <SHA256>
context_type: input | discovery | hypothesis | test | failure | correction | conclusion | question
labels: [string]
source: <path-to-session-transcript>
```

**Context Types** (classify what happened in this moment):
- `input` — A question or problem was posed
- `discovery` — New information was found
- `hypothesis` — A theory was formed
- `test` — An idea was tried
- `failure` — Something didn't work; reasoning about why
- `correction` — Previous understanding was wrong; correcting it
- `question` — Open question posed; uncertainty articulated
- `conclusion` — Final decision or understanding reached

### 2.3 Topic Tag

Topics are flexible strings that identify what a bubble is about. Examples:
- `authentication` — thinking about auth systems
- `daemon-health` — debugging a daemon
- `peer-discovery` — reasoning about peer connectivity
- `incident-response-2026-03` — specific incident playback
- `user-onboarding` — Alice teaching a human

Topics enable discovery: "show me all bubbles tagged with `authentication`".

---

## 3. Bubble Creation and Curation

### 3.1 Automatic Moment Capture

When an entity runs a session, the daemon automatically records moments:

1. **Session transcript** — All input/output is captured in `~/.{entity}/sessions/{session-uuid}.log`
2. **Moment markers** — Key events trigger moment boundaries:
   - User input (question posed)
   - Tool execution result
   - State change
   - Error or exception
   - Explicit `/bubble-mark` command
3. **Content hashing** — Each moment is hashed (SHA256 of transcript content for that window)

### 3.2 Manual Curation

A human (or entity with operator permissions) curates a bubble:

1. Review the session transcript
2. Identify moments of interest by time window
3. Select moments and assign `context_type` and optional labels
4. Write a description of what the bubble teaches
5. Save as bubble markdown file

**Manual curation process:**
```bash
# Human views session
/playback-machine show <session-uuid>

# Human creates bubble
/playback-machine bubble create \
  --topic "daemon-health" \
  --description "Debugging a stuck health-check endpoint" \
  --moments session-uuid:08:00-08:15,session-uuid:08:20-08:35 \
  --tags "daemon,performance,debugging"
```

### 3.3 Auto-Extraction by Topic

Alternatively, a system (Argus or entity itself) can extract bubbles by topic:

```bash
/bubble extract-by-topic \
  --entity vesta \
  --topic "commands-system" \
  --window "2026-03-15 to 2026-04-03"
```

Result: All moments from sessions where "commands-system" was discussed, automatically grouped into a bubble, deduplicated, chronologically ordered.

---

## 4. Bubble File Format

### 4.1 File Location and Naming

**Created by an entity:**
```
~/{ENTITY}/bubbles/{topic}-{date}-{uuid-short}.md
```

Example:
```
~/.vesta/bubbles/daemon-health-2026-04-03-abc123.md
~/.vulcan/bubbles/commands-system-2026-03-28-def456.md
```

**Shared via peer protocol:**
```
~/{ENTITY}/bubbles/shared-in/{source-kingdom}/{topic}-{date}-{uuid-short}.md
```

Example:
```
~/.vulcan/bubbles/shared-in/vesta/daemon-health-2026-04-03-abc123.md
```

### 4.2 Markdown Structure

```markdown
---
type: context-bubble
id: <UUID>
topic: daemon-health
tags: [daemon, performance, debugging]
created_by: vesta
created_at: 2026-04-03T14:22:00Z
owned_by: vesta.koad.sh
version: 1.0
signature: <saltpack-signature>
is_shared: false
canonical_chain: [bubble-id-parent-1, bubble-id-parent-2]
description: >
  Debugging session where a vesta daemon health-check endpoint was hanging.
  Shows discovery of resource leak, testing hypothesis, and fix verification.
moments_count: 5
---

# Context Bubble: Daemon Health Debugging

## Overview

This bubble captures the thinking behind diagnosing and fixing a daemon health-check endpoint hang.

## Topic: `daemon-health`

This is part of ongoing work on daemon reliability. Related bubbles: [](link-to-parent-bubble).

---

## Moment 1: Problem Statement (2026-04-03 08:00:00Z — 08:15:00Z)

**Type:** input → discovery

**Context:** A Vulcan operator reports that the daemon health-check endpoint is hanging intermittently.

**Session:** 550e8400-e29b-41d4-a716-446655440000 (15 minutes)

**What happened:**
- Operator describes the symptom: requests to `/health` timeout after 30s
- Happens once per 100 requests
- Reproducible with load test
- No errors in logs

**Moment hash:** `sha256(transcript[08:00-08:15])`

[Link to session transcript segment](link-to-session-storage)

---

## Moment 2: Hypothesis Formation (2026-04-03 08:20:00Z — 08:35:00Z)

**Type:** hypothesis

**Context:** After reviewing code, a theory emerges.

**Session:** Same session

**What happened:**
- Reviewed health-check handler code
- Noticed file descriptor iteration loop
- Theory: Under high load, file iteration gets stuck on a socket that's being closed
- Test plan: Add logging to iteration loop

**Moment hash:** `sha256(transcript[08:20-08:35])`

---

## Moment 3: Testing the Hypothesis (2026-04-03 09:00:00Z — 09:45:00Z)

**Type:** test

**Context:** Instrument the code and re-run load test.

**Session:** Different session (new test environment)

**What happened:**
- Added debug logging to file descriptor iteration
- Ran load test again
- Logs show: iteration stalls on fd #47 (socket) when another goroutine closes it mid-iteration
- Root cause confirmed

**Moment hash:** `sha256(transcript[09:00-09:45])`

---

## Moment 4: Correction (2026-04-03 10:15:00Z — 10:30:00Z)

**Type:** correction

**Context:** Previous understanding was incomplete.

**Session:** Same session

**What happened:**
- Initially thought the issue was in health-check handler alone
- Found the real issue: two goroutines sharing file descriptor list without locking
- Changed approach: add RWMutex around file descriptor iteration
- This is not a health-check bug; it's a daemon-core bug

**Moment hash:** `sha256(transcript[10:15-10:30])`

---

## Moment 5: Fix Verification (2026-04-03 11:00:00Z — 12:00:00Z)

**Type:** conclusion

**Context:** Fix deployed and tested.

**Session:** Production test session

**What happened:**
- Lock added to daemon-core fd iteration
- Load test now runs 1000 requests without hang
- Health-check response time: consistent 10ms
- No regression in other endpoints

**Conclusion:** Mutex-protected file descriptor list. Deployed to prod. Monitoring.

**Moment hash:** `sha256(transcript[11:00-12:00])`

---

## Reflections

This bubble shows:
1. **Discovery process** — A problem reported, investigation planned
2. **Hypothesis testing** — Theory formed, tested, confirmed
3. **Correction** — Initial mental model was wrong; deeper cause found
4. **Resolution** — Fix deployed and verified

The reader experiences how the daemon engineers think about performance debugging.

---

## References

- **Parent bubble:** [daemon-reliability-q1-2026](link)
- **Related issues:** koad/vulcan#123 (original report)
- **Commit:** abc123def (RWMutex implementation)
- **Sessions:** [550e8400-e29b-41d4](link-to-session), [660e8400-e29b-41d4](link-to-session)

---

**Signature (Keybase/Saltpack):**
```
-----BEGIN SALTPACK SIGNED MESSAGE-----
...signature bytes...
-----END SALTPACK SIGNED MESSAGE-----
```

Signed by: vesta@kingofalldata.com
Verified by: Juno (2026-04-03 14:30:00Z)
```

### 4.3 Frontmatter Fields

| Field | Type | Required | Values | Purpose |
|-------|------|----------|--------|---------|
| `type` | string | Yes | `context-bubble` | Identifies this as a bubble document |
| `id` | UUID | Yes | Valid UUID v4 | Unique bubble identifier |
| `topic` | string | Yes | Alphanumeric + `-` | What this bubble teaches |
| `tags` | array | Yes | String array | Discovery and categorization tags |
| `created_by` | string | Yes | Entity name | Which entity created this bubble |
| `created_at` | ISO-8601 | Yes | UTC timestamp | When the bubble was curated |
| `owned_by` | string | Yes | FQDN or entity name | Kingdom that owns this bubble |
| `version` | string | No | e.g., `1.0` | Bubble version (for amendments) |
| `signature` | string | Yes | Saltpack-encoded | Cryptographic signature over markdown content |
| `is_shared` | boolean | No | true/false | Whether this bubble is shared with peer kingdoms |
| `canonical_chain` | array | No | UUID array | Parent/related bubbles this builds on |
| `description` | string | Yes | Markdown text | What the bubble teaches |
| `moments_count` | integer | Auto | Integer | Number of moments in bubble |

---

## 5. How Bubbles Are Consumed

### 5.1 By Entities (Context Before Session)

An entity preparing a session can load context bubbles:

```bash
# Vulcan starting a daemon tuning session
/load-context --topic daemon-optimization --window last-30-days

# Output: Shows related bubbles tagged with daemon-optimization created in the last 30 days
# Entity can choose to load one or more for context
```

**Use case:** Before troubleshooting a recurring issue, the entity (or operator) loads bubbles from previous debugging sessions. They experience how the issue was previously investigated, what failed, what worked.

### 5.2 By Humans (Playback-Machine Rendering)

Humans use a playback-machine to view bubbles interactively:

```bash
/playback-machine show <bubble-id>
```

**Output:** Rendered markdown with:
- Moment timeline visualization
- Links to original session transcripts
- Chronological flow of thinking
- Highlights of key discoveries/corrections/conclusions
- References and commit links

**Interactive features:**
- Click on a moment to see the full session segment
- Search across moment labels and descriptions
- Export bubble as HTML/PDF for sharing with non-technical stakeholders
- Comment on moments (humans only; stored separately from owned bubble)

### 5.3 By Peer Rings (Inter-Kingdom Sharing)

When two daemons are peered (VESTA-SPEC-014), bubbles can flow between them.

**Daemon exposes bubble endpoints:**
```
GET /api/v1/peer/bubbles?topic=<topic>&after=<date>
GET /api/v1/peer/bubbles/<bubble-id>
```

**Peer daemon fetches bubbles:**
```bash
# Vulcan daemon, peered with Vesta
# Requesting bubbles about daemon health from Vesta
GET https://vesta.koad.sh/api/v1/peer/bubbles?topic=daemon-health&after=2026-03-01

# Response: Array of bubbles (metadata + content_hash + signature)
```

**Receiving daemon stores:**
```
~/.vulcan/bubbles/shared-in/vesta/daemon-health-2026-04-03-abc123.md
```

The bubble is read-only; Vulcan cannot modify it. If Vulcan disagrees with a conclusion, Vulcan creates its own bubble referencing the original.

### 5.4 Discovery via Daemon Registry

Each daemon exposes a bubble registry:

```json
GET /api/v1/peer/bubbles/registry

{
  "topics": [
    {
      "topic": "daemon-health",
      "count": 12,
      "latest": "2026-04-03",
      "bubbles": [
        {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "topic": "daemon-health",
          "created_at": "2026-04-03",
          "owner": "vesta",
          "description": "Debugging health-check endpoint hang"
        },
        ...
      ]
    },
    ...
  ]
}
```

---

## 6. Journalism Model: Bubbles as Verifiable Records

### 6.1 What Makes a Bubble "Journalistic"

A journalistic context bubble has these properties:

1. **Sourced** — Every moment references a session (the source material)
2. **Chronological** — Moments are in the order they occurred
3. **Corrections included** — When previous understanding was wrong, that correction is documented
4. **Verifiable** — Signatures guarantee the bubble hasn't been tampered with
5. **Attributed** — Clear who created it, when, and what they claimed it teaches
6. **Traceable** — Links to session transcripts, commits, issues, everything

### 6.2 The Journalism Principle

A story is not an article. An article is a written-up version of a story. The bubble *is* the story.

**Traditional journalism:**
```
Event → Reporter → Written Article (refined, edited, distilled)
Reader gets: Conclusion
Reader loses: Uncertainty, dead-ends, corrections, hesitation
```

**Bubble journalism:**
```
Event → Moment 1 (input) → Moment 2 (discovery) → Moment 3 (hypothesis) 
        → Moment 4 (test) → Moment 5 (failure) → Moment 6 (correction) 
        → Moment 7 (conclusion)
Reader experiences: How understanding evolved
Reader gains: Trust (because they see the reasoning)
```

### 6.3 Edits and Amendments

A bubble can be amended (e.g., new information comes to light). Amendments are explicit:

```markdown
---
version: 1.1
amended_at: 2026-04-04T10:00:00Z
amended_by: vesta
amendment_reason: "New information from prod: issue recurred. Correction: our fix was incomplete."
signature: <new-saltpack-signature>
previous_version_id: <uuid-of-v1.0>
---
```

The old version is archived. The new version has a pointer to the old. Readers can trace the evolution of understanding.

---

## 7. Peer Ring Model: Sharing Between Kingdoms

### 7.1 What Travels in Peer Connections

Not all bubbles are shared. Access is mediated by:

1. **Sponsorship tier** (VESTA-SPEC-014)
   - Free tier: No bubble sharing
   - Basic tier: Can request bubbles on public topics (e.g., daemon-health)
   - Pro tier: Can request bubbles on any topic from sponsor
   - Enterprise: Can request and share bubbles with all peers

2. **Bubble visibility flag**
   - `is_shared: true` — bubble is published to peer network
   - `is_shared: false` — bubble is private (only owner kingdom)

3. **Peer authorization**
   - Sponsoring kingdom explicitly allows peer to receive bubbles
   - Sponsorship document lists authorized topics

### 7.2 Example: Peer Ring Bubble Flow

```
Setup:
  - Juno (sponsor) peered with Vulcan (pro tier)
  - Juno publishes bubbles with is_shared: true on topics: daemon-optimization, commands-system
  - Vulcan can request these bubbles; Vulcan peers cannot

Vulcan daemon:
  /request-peer-bubbles --from juno --topic daemon-optimization

Juno daemon:
  Checks: Is Vulcan pro tier? ✓ Is daemon-optimization in Vulcan's allowed topics? ✓
  Returns: All bubbles with is_shared: true and topic: daemon-optimization
  
Vulcan receives:
  ~/.vulcan/bubbles/shared-in/juno/daemon-optimization-*.md (all read-only)
```

### 7.3 What Stays Sovereign

Each kingdom retains control over:

1. **Private bubbles** — Marked `is_shared: false`; never published to peers
2. **Bubble amendments** — Owner kingdom controls edits; peers see immutable version
3. **Bubble removal** — Owner can deprecate a bubble; peers still hold copies (for archive)
4. **Access logs** — Each daemon logs who requested what bubbles; retained locally

---

## 8. Security: Ownership and Read-Only Access

### 8.1 Bubble Ownership

Each bubble is cryptographically signed by the source kingdom:

```
Signature: Signed by vesta@kingofalldata.com (Ed25519 key)
Verifiable by: Any entity with Vesta's public key (published in trust directory)
```

When a peer receives a bubble, the peer **must verify the signature**. If signature is invalid, the bubble is rejected.

### 8.2 Read-Only for Shared Bubbles

A bubble received via peer protocol is read-only:

```bash
# Vulcan receives bubble from Juno
~/.vulcan/bubbles/shared-in/juno/daemon-optimization-2026-04-03-abc123.md

# Vulcan cannot edit this file
# If Vulcan wants to comment, Vulcan creates a NEW bubble:
~/.vulcan/bubbles/response-to-juno-daemon-optimization-2026-04-04-def456.md

# This new bubble has:
canonical_chain: [juno-daemon-optimization-2026-04-03-abc123]
# ...indicating it builds on the received bubble
```

### 8.3 Revocation

The source kingdom can revoke a bubble (e.g., information was wrong):

```yaml
status: REVOKED
revoked_at: 2026-04-04T10:00:00Z
revoked_by: juno
revocation_reason: "This bubble contained incorrect information; see corrected version below."
```

Peers are notified. They can choose to delete their copy or keep it with a deprecation notice.

### 8.4 Tampering Detection

If a shared bubble is modified locally, the signature becomes invalid. Verification fails.

```bash
# Vulcan receives Juno's bubble and its signature
# Vulcan tampers with moment content
# /verify-bubble returns: SIGNATURE_INVALID

# Vulcan must either:
# 1. Restore original, or
# 2. Create a new commentary bubble (canonical_chain reference)
```

---

## 9. Daemon Bubble API

### 9.1 Endpoints

Every daemon exposes bubble endpoints under `/api/v1/peer/`:

**List bubbles by topic:**
```
GET /api/v1/peer/bubbles?topic=<topic>&after=<date>&limit=20

Response:
{
  "bubbles": [
    {
      "id": "<uuid>",
      "topic": "<topic>",
      "created_at": "<ISO-8601>",
      "created_by": "<entity>",
      "description": "<string>",
      "is_shared": true,
      "content_hash": "<sha256>",
      "signature_sha256": "<sha256>"
    },
    ...
  ]
}
```

**Fetch a specific bubble:**
```
GET /api/v1/peer/bubbles/<bubble-id>

Response:
{
  "bubble": {
    "id": "<uuid>",
    ... (full markdown content),
    "signature": "<saltpack-signature>"
  }
}
```

**Bubble registry (discovery):**
```
GET /api/v1/peer/bubbles/registry

Response:
{
  "topics": [
    {
      "topic": "<topic>",
      "count": <int>,
      "latest": "<ISO-8601>",
      "description": "<string>"
    },
    ...
  ]
}
```

### 9.2 Rate Limiting

Bubble API calls are rate-limited by tier (VESTA-SPEC-014):

| Tier | Requests/minute | Bubbles/day |
|------|-----------------|------------|
| free | 0 | 0 (no bubble access) |
| basic | 10 | 20 |
| pro | 60 | 500 |
| enterprise | Unlimited | Unlimited |

---

## 10. Audit Criteria (How Argus Verifies Conformance)

**Argus audits context bubbles per these criteria:**

1. **Signature validity** — Every bubble signature must be verifiable with the owner's public key
2. **Moment hashes** — Moment content_hash must match referenced session transcript segment
3. **Topic taxonomy** — Topics must follow the registered taxonomy (or warn if novel topic)
4. **Temporal consistency** — Moments must be in chronological order; timestamps must fall within their session's timespan
5. **Chain integrity** — If a bubble references canonical_chain, those parent bubbles must exist and be accessible
6. **Ownership** — Bubble is_shared flag and owner match the signing entity
7. **Read-only enforcement** — Shared bubbles (in shared-in/) must have valid signatures; local edits invalidate them
8. **API compliance** — Daemon bubble endpoints must respond to standard queries; rate limiting must be enforced

---

## 11. Healing Criteria (How Salus Repairs Deviations)

**Salus can repair context bubble deviations:**

1. **Invalid signatures** → Quarantine bubble, alert owner
2. **Tampered shared bubbles** → Mark read-only, restore from peer if available
3. **Missing parent bubbles** → Attempt to fetch from source kingdom; warn if unavailable
4. **Expired moments** — Segments beyond session retention window (e.g., >90 days) → Archive to cold storage; maintain reference
5. **API unresponsive** → Retry bubble fetches; log failures for Argus diagnostics

---

## 12. Migration and Versioning

### 12.1 Version History

This spec is at version 1.0 (draft). Amendments will be tracked here.

### 12.2 Backward Compatibility

Context bubbles introduced in VESTA-SPEC-016 are a new facility. No legacy content to migrate. All entities must support bubble creation and consumption by 2026-05-01.

---

## References

- **Request source:** koad/vulcan#9 (playback-machine issue, context bubble concept)
- **Related specs:**
  - VESTA-SPEC-009 (Daemon Specification) — daemon endpoints and API structure
  - VESTA-SPEC-014 (Kingdom Peer Connectivity Protocol) — peer discovery, sponsorship tiers
  - VESTA-SPEC-011 (Inter-Entity Communications) — message passing protocol
  - VESTA-SPEC-007 (Trust Bond Protocol) — cryptographic authorization

---

**VESTA-SPEC-016** — Context Bubble Protocol  
Canonical reference for experiential knowledge transfer in koad:io.  
Status: Draft  
Date: 2026-04-03  
Owner: Vesta
