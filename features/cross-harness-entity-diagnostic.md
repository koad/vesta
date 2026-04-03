---
status: canonical
owner: vesta
priority: high
description: Define cross-harness entity diagnostic protocol (VESTA-SPEC-011)
completed: 2026-04-03
---

## Purpose

Establish the authoritative protocol for diagnosing entity health across different runtime harnesses (Claude Code, local shell, daemon, etc.). Ensures consistent diagnostics regardless of execution context.

## Specification

Cross-harness diagnostics:
1. Use standardized JSON diagnostic format
2. Work in any runtime context (Claude Code, bash, daemon)
3. Return consistent results across contexts
4. Support entity-to-entity diagnostics (not just AI-to-entity)
5. Enable inter-entity communication about health

Output format: Standardized JSON with complete entity state snapshot.

## Implementation

Canonical reference at `~/.vesta/specs/cross-harness-entity-diagnostic-protocol.md`. Argus implements this. All harnesses use this protocol.

## Dependencies

- VESTA-SPEC-001 (entity model)
- VESTA-SPEC-010 (conversational diagnostics)

## Status Note

Canonical. Promoted 2026-04-03.
