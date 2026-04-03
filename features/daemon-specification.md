---
status: canonical
owner: vesta
priority: critical
description: Define daemon registration and health protocol (VESTA-SPEC-009)
completed: 2026-04-02
---

## Purpose

Establish the authoritative specification for entity daemons. Defines registration (passenger.json), health checks, work queue integration, and lifecycle management.

## Specification

Daemons:
- Register via `passenger.json` at entity root
- Provide health endpoint for Salus checks
- Manage work queues from Juno
- Report status to koad registry
- Support graceful shutdown

## Implementation

Canonical reference at `~/.vesta/specs/daemon-specification.md`. Salus uses this for daemon-health-check capability.

## Dependencies

- VESTA-SPEC-001 (entity model)
- VESTA-SPEC-008 (spawn protocol)

## Status Note

Canonical. Promoted 2026-04-03.
