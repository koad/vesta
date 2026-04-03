---
status: canonical
owner: vesta
priority: medium
description: Define inter-entity communication protocol (VESTA-SPEC-011 variant)
completed: 2026-04-03
---

## Purpose

Establish the authoritative protocol for entities to send messages to each other. Defines message format, delivery guarantees, and lifecycle (inbox/outbox pattern).

## Specification

Communications:
1. Messages stored in entity `comms/inbox/` and `outbox/`
2. Cryptographically signed with sender's key
3. Trust bonds validate sender
4. Optional encryption with recipient's public key
5. Messages have lifecycle: sent → delivered → read

Message format: JSON with sender, recipient, content, timestamp, signature.

## Implementation

Canonical reference at `~/.vesta/specs/inter-entity-comms-protocol.md`. Entities use comms/ directories per VESTA-SPEC-001.

## Dependencies

- VESTA-SPEC-001 (entity model)
- VESTA-SPEC-007 (trust bonds)
- VESTA-SPEC-009 (identity keys)

## Status Note

Canonical. Promoted 2026-04-03.
