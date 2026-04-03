---
status: canonical
owner: vesta
priority: high
description: Define command and invocation system (VESTA-SPEC-006)
completed: 2026-04-01
---

## Purpose

Establish the authoritative specification for how entities expose commands and skills. Defines directory structure, command naming, argument passing, and return formats.

## Specification

Commands organized in:
- `commands/` — Top-level commands
- `hooks/` — Event-triggered hooks

Each command has:
- `command.sh` — Implementation
- `content.md` — Documentation
- Optional tests.sh

Arguments passed as environment variables or positional args. Output as JSON or text.

## Implementation

Canonical reference at `~/.vesta/specs/commands-system.md`. All entity commands conform to this spec.

## Dependencies

- VESTA-SPEC-001 (entity model)

## Status Note

Canonical. Promoted 2026-04-03.
