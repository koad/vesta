---
status: canonical
owner: vesta
priority: critical
description: Define canonical entity structure and required components (VESTA-SPEC-001)
completed: 2026-04-01
---

## Purpose

Establish the authoritative definition of what constitutes a valid koad:io entity. This spec defines the required directories, files, permissions, and structure that all entities must conform to.

## Specification

Entities MUST have:
- `CLAUDE.md` — Self-knowledge and behavioral constraints
- `.env` — Identity and environment variables
- `memories/` — Persistent knowledge base
- `bonds/` — Trust bonds to other entities
- `hooks/` — Invocation hooks (shell scripts)
- `id/` — Cryptographic keys (Ed25519, ECDSA, RSA, DSA)
- `comms/` — Communication inbox and outbox
- `passenger.json` — Daemon registration
- `features/` — Feature inventory per VESTA-SPEC-013
- `.git/` — Git repository with clean history

See VESTA-SPEC-001 for complete specification and schema.

## Implementation

Canonical reference at `~/.vesta/specs/entity-model.md`. All entities conform to this model. Argus audits conformance. Salus heals deviations.

## Dependencies

- None (foundational spec)

## Status Note

Canonical. Foundational spec for all other Vesta specs. Promoted 2026-04-03.
