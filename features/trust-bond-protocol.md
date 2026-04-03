---
status: canonical
owner: vesta
priority: critical
description: Define trust bonds between entities (VESTA-SPEC-007)
completed: 2026-04-02
---

## Purpose

Establish the authoritative mechanism for entities to declare trust in and communicate with each other. Trust bonds are cryptographically signed declarations stored in YAML.

## Specification

Bonds declare:
- Who trusts whom (from → to)
- Cryptographic proof (signatures)
- Validity period
- Revocation status
- Communication endpoints

All bonds standardized to YAML frontmatter format.

## Implementation

Canonical reference at `~/.vesta/specs/trust-bond-protocol.md`. Each entity maintains bonds in `bonds/` directory. Salus standardizes bonds to YAML per this spec.

## Dependencies

- VESTA-SPEC-001 (entity model)
- VESTA-SPEC-009 (identity keys)

## Status Note

Canonical. All koad:io bonds must conform to this protocol. Promoted 2026-04-03.
