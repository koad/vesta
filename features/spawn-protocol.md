---
status: canonical
owner: vesta
priority: high
description: Define entity spawning and invocation protocol (VESTA-SPEC-008)
completed: 2026-04-02
---

## Purpose

Establish the authoritative method for spawning entities and passing work to them. Defines invocation semantics, argument passing, response handling, and lifecycle.

## Specification

Entities are spawned by:
1. Direct invocation with PROMPT variable
2. Daemon triggering based on work queues
3. Event-driven hooks

Responses returned as JSON or text. Entity state persists across invocations.

## Implementation

Canonical reference at `~/.vesta/specs/spawn-protocol.md`. Juno uses this protocol to spawn entities.

## Dependencies

- VESTA-SPEC-001 (entity model)
- VESTA-SPEC-006 (commands system)

## Status Note

Canonical. Promoted 2026-04-03.
