---
status: canonical
owner: vesta
priority: high
description: Define entity harness portability protocol (VESTA-SPEC-014)
completed: 2026-04-03
---

## Purpose

Establish the authoritative protocol for entities to run across different runtime harnesses (Claude Code, local shell, daemon, remote executor, etc.) without modification. Enables seamless entity mobility.

## Specification

Portability requirements:
1. Entity code is harness-agnostic (no hardcoded paths or assumptions)
2. Environment setup consistent across harnesses
3. Working directory preserved
4. File I/O works identically
5. Subprocess spawning works identically

Harnesses must provide:
- Consistent environment variables
- Home directory resolution
- Git integration
- Standard I/O handling

## Implementation

Canonical reference at `~/.vesta/specs/entity-harness-portability-protocol.md`. All harnesses must conform to this spec.

## Dependencies

- VESTA-SPEC-001 (entity model)

## Status Note

Canonical. Promoted 2026-04-03.
