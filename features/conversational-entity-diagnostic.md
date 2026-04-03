---
status: canonical
owner: vesta
priority: high
description: Define conversational entity diagnostic protocol (VESTA-SPEC-010)
completed: 2026-04-03
---

## Purpose

Establish the authoritative protocol for Argus to diagnose entity health through conversational queries. Enables interactive troubleshooting and constraint satisfaction.

## Specification

Diagnostic process:
1. Ask clarifying questions about entity symptoms
2. Collect diagnostic data from entity structure
3. Analyze against entity spec
4. Generate diagnosis JSON with findings and recommended actions
5. Return to Salus for healing

Output format: JSON with `conforms: true/false`, `issues: []`, `recommendations: []`.

## Implementation

Canonical reference at `~/.vesta/specs/conversational-entity-diagnostic-protocol.md`. Argus implements this. Salus consumes the output.

## Dependencies

- VESTA-SPEC-001 (entity model)

## Status Note

Canonical. Promoted 2026-04-03.
