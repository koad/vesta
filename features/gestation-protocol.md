---
status: canonical
owner: vesta
priority: critical
description: Define entity creation and bootstrap protocol (VESTA-SPEC-004)
completed: 2026-04-01
---

## Purpose

Establish the authoritative procedure for creating new entities in the koad:io ecosystem. Defines the templates, bootstrap scripts, identity generation, and registration process.

## Specification

Gestation creates:
1. Entity directory structure per VESTA-SPEC-001
2. Cryptographic keys (Ed25519, ECDSA, RSA, DSA)
3. Initial CLAUDE.md with behavioral constraints
4. Initial .env with identity variables
5. Bonds to koad (root trust)
6. Git repository with initial commit
7. Daemon registration

Juno orchestrates gestation (delegates to this spec).

## Implementation

Canonical reference at `~/.vesta/specs/gestation-protocol.md`. Implemented as Juno's gestation process.

## Dependencies

- VESTA-SPEC-001 (entity model)
- Cryptographic key generation (Ed25519, ECDSA, RSA, DSA)
- Git initialization

## Status Note

Canonical. Core entity creation spec. Promoted 2026-04-03.
