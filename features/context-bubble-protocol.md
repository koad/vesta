---
status: draft
owner: vesta
priority: high
description: Context Bubble Protocol (VESTA-SPEC-016) — experiential knowledge transfer via playlists of session moments
started: 2026-04-03
completed: null
---

# Context Bubble Protocol (VESTA-SPEC-016)

## Summary

Specification defining how koad:io entities create, curate, share, and consume context bubbles — ordered playlists of session moments that encode human and AI reasoning for experiential knowledge transfer.

## Specification File

- **Spec:** `~/.vesta/specs/context-bubble-protocol.md`
- **Status:** Draft
- **Version:** 1.0

## Scope

- **Creation:** Automatic moment capture during sessions; manual curation by operators
- **Format:** Markdown with YAML frontmatter; cryptographically signed with Keybase/Saltpack
- **Consumption:** By entities (context before session), humans (playback-machine), peer rings (inter-kingdom sharing)
- **Journalism Model:** Bubbles as verifiable, traceable records of thinking — not summaries
- **Peer Sharing:** Mediated by sponsorship tier; shared bubbles are read-only to recipients
- **Security:** Owner-signed; tampering detection; explicit revocation

## Key Concepts

### Context Bubble
An ordered playlist of (session_id, timestamp_start, timestamp_end, topic_tags[]) — moments of human or AI reasoning around a topic.

### Moment
A contiguous time window within a session, classified as: input, discovery, hypothesis, test, failure, correction, or conclusion.

### Journalism Model
Bubbles encode the evolution of understanding, not just the conclusion. Reader experiences how thinking happened, building trust through visibility of reasoning process.

### Peer Ring Sharing
When kingdoms peer, bubbles flow based on sponsorship tier. Shared bubbles are read-only; source kingdom retains ownership and control.

## Deliverables

- [x] Draft VESTA-SPEC-016 with full sections
  - Definition and philosophy
  - Core concepts (bubble, moment, topic)
  - Creation and curation workflow
  - File format (markdown with YAML)
  - Consumption by entities, humans, peer rings
  - Journalism model
  - Peer ring sharing model
  - Security (ownership, read-only, revocation, tampering detection)
  - Daemon API endpoints
  - Audit criteria (Argus)
  - Healing criteria (Salus)

- [ ] Entity implementation (Vulcan) — bubble creation, storage, API
- [ ] Playback-machine enhancement — render bubbles interactively
- [ ] Daemon peer protocol extension — bubble endpoints
- [ ] Argus audit module — verify bubble conformance
- [ ] Salus healing module — repair deviations

## Issues and References

- **Filed:** koad/juno (awaiting review)
- **Request source:** koad/vulcan#9 (playback-machine, journalistic records concept)
- **Related specs:**
  - VESTA-SPEC-014 (Kingdom Peer Connectivity) — peer discovery, tiers
  - VESTA-SPEC-009 (Daemon Specification) — API structure
  - VESTA-SPEC-011 (Inter-Entity Communications) — messaging

## Notes

This is a significant conceptual addition to koad:io — it reframes knowledge transfer from textual (conclusional) to experiential (journalistic records). The spec includes security boundaries, peer visibility rules, and audit/healing criteria per koad governance.

Implementation timing: After koad review and approval.
