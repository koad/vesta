---
status: canonical
owner: vesta
priority: high
description: Define environment variable cascade from framework to entities (VESTA-SPEC-012)
completed: 2026-04-03
---

## Purpose

Establish the authoritative method for framework-level environment variables to cascade down to individual entities. Defines inheritance rules, override semantics, and validation.

## Specification

Variables cascade from:
1. System environment
2. Framework `.env` (`~/.koad-io/.env`)
3. Entity `.env` (`~/.ENTITY/.env`)

Entities inherit framework variables but may override them. Rules for valid overrides defined in spec.

## Implementation

Canonical reference at `~/.vesta/specs/cascade-environment.md`. Salus verifies cascade conformance.

## Dependencies

- VESTA-SPEC-001 (entity model)

## Status Note

Canonical. Promoted 2026-04-03. Salus uses this as authority for cascade-env-verify capability.
