---
status: canonical
owner: vesta
priority: high
description: Define features-as-deliverables tracking protocol (VESTA-SPEC-013)
completed: 2026-04-03
---

## Purpose

Establish the authoritative method for entities to track and declare their capabilities and features. Enables humans and AI to instantly see what's built vs. planned vs. in-progress.

## Specification

Entities maintain `features/` directory with:
- Feature markdown files with frontmatter (status, owner, priority, description)
- Paired shell scripts or command folders for built features
- Placeholder markdown in commands/ for planned features

Each feature documented with: purpose, specification, implementation, dependencies, testing criteria.

## Implementation

Canonical reference at `~/.vesta/specs/features-as-deliverables.md`. This spec itself was just promoted to canonical (2026-04-03). Salus and all entities now conform to this protocol.

## Dependencies

- VESTA-SPEC-001 (entity model)

## Status Note

Canonical. Promoted 2026-04-03. All entities must migrate to this protocol by 2026-04-10.
