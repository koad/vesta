# Vesta Documentation

Vesta is the platform steward and specification authority for the koad:io ecosystem. This directory contains documentation about Vesta's roles, specifications, and architectural vision.

## What is Vesta?

Vesta (Roman goddess of the hearth and home) is the authoritative source for:
- Entity structure and requirements (VESTA-SPEC-001)
- System protocols and patterns (VESTA-SPEC-002 through VESTA-SPEC-013+)
- Diagnostic and conformance standards
- Architectural guidance for all entities in koad:io

Vesta defines what "healthy" looks like. Argus diagnoses. Salus heals. Juno orchestrates.

## Core Responsibilities

1. **Define canonical specifications** — Write and maintain VESTA-SPEC-* documents
2. **Authority on conformance** — All entities measured against Vesta specs
3. **Platform stewardship** — Ensure consistency across the koad:io ecosystem
4. **Protocol governance** — Evolve protocols based on ecosystem needs

## Specifications

Vesta maintains canonical specifications for all aspects of koad:io:

### Foundational (Core Concepts)

- **VESTA-SPEC-001** — Entity Model (what entities are)
- **VESTA-SPEC-004** — Gestation Protocol (how entities are created)
- **VESTA-SPEC-006** — Commands System (how entities expose capabilities)

### Security & Identity

- **VESTA-SPEC-009** — Daemon Specification (daemon registration and health)
- **VESTA-SPEC-007** — Trust Bond Protocol (inter-entity trust)
- **VESTA-SPEC-009** — Identity Keys (cryptographic identity)

### Operations & Orchestration

- **VESTA-SPEC-008** — Spawn Protocol (entity invocation and lifecycle)
- **VESTA-SPEC-012** — Cascade Environment (variable inheritance)
- **VESTA-SPEC-010** — Conversational Entity Diagnostic (interactive health checks)
- **VESTA-SPEC-011** — Cross-Harness Entity Diagnostic (context-agnostic diagnostics)
- **VESTA-SPEC-014** — Entity Harness Portability (run anywhere)

### Communication & Coordination

- **VESTA-SPEC-011** variant — Inter-Entity Communications (message passing)

### Project Management

- **VESTA-SPEC-013** — Features-as-Deliverables (tracking capabilities)

## Key Files

- **specs/** — All canonical specifications (VESTA-SPEC-*.md)
- **features/** — Feature inventory for Vesta's own specs
- **documentation/** — This directory

## Features

Vesta's specifications are tracked as features per VESTA-SPEC-013:

### Canonical Specifications (Complete)
- **entity-model** — Entity structure and requirements
- **gestation-protocol** — Entity creation and bootstrap
- **trust-bond-protocol** — Inter-entity trust mechanism
- **cascade-environment** — Environment variable inheritance
- **commands-system** — Command and skill system
- **spawn-protocol** — Entity invocation protocol
- **daemon-specification** — Daemon registration and health
- **features-as-deliverables** — Feature inventory protocol
- **conversational-entity-diagnostic** — Interactive diagnostics
- **cross-harness-entity-diagnostic** — Cross-context diagnostics
- **entity-harness-portability** — Harness-agnostic execution
- **inter-entity-communications** — Message passing between entities

All specifications are **canonical** and promoted to koad:io standard.

## The VESTA-SPEC Numbering System

| Number | Category | Purpose |
|--------|----------|---------|
| 001 | Foundation | Entity model (canonical authority on what entities are) |
| 002-005 | Core | Gestation, startup, identity, public accounts |
| 006-009 | Systems | Commands, spawn, daemon, identity keys |
| 010-012 | Operations | Diagnostics, communications, environment |
| 013+ | Future | Features tracking, extensions, new protocols |

## Design Philosophy

Vesta operates under these principles:

1. **Specification is Authority** — What Vesta writes, entities must conform to
2. **Canonical Not Descriptive** — Specs define the standard, not document the current state
3. **Version Stability** — Once canonical, specs are stable. Amendments are explicit
4. **Audit-First Design** — Every spec includes how Argus audits conformance
5. **Healing-First Design** — Every spec indicates how Salus repairs deviations

## Workflow: Creating New Specs

When Vesta creates a new specification:

1. Write spec as VESTA-SPEC-*N*.md in `~/.vesta/specs/`
2. Include mandatory sections: Authority, Scope, Consumers, Requirements, Audit Criteria
3. Add feature markdown to `~/.vesta/features/VESTA-SPEC-*.md` (status: draft)
4. Promote to canonical in VESTA-SPEC-*.md frontmatter
5. Update feature markdown (status: canonical, add completed date)
6. Commit to `~/.vesta/` and push
7. File issue on `koad/vesta` for community feedback

## Workflow: Amending Specs

Vesta explicitly tracks amendments:

1. Include "# Change Log" section in spec with version history
2. Mark change with version, date, author, and description
3. Increment version number if non-trivial amendment
4. If breaking change: require opt-in from affected entities

## Integration with Entities

All entities read `~/.vesta/specs/` to understand requirements:

- **Juno** uses gestation and spawn protocols to create and orchestrate entities
- **Argus** uses all specs as authority for conformance audits
- **Salus** uses specs as healing guidelines (heal-to-spec, not heal-to-memory)
- **All entities** conform their structure to VESTA-SPEC-001

## Communication

- **Author specs:** Vesta (internal process)
- **Discuss specs:** File issues on `koad/vesta`
- **Report spec violations:** File on `koad/argus` or `koad/salus`
- **Request new specs:** File on `koad/vesta`

## Quality Gates

Specs reach canonical status only when:
- ✅ Written with complete sections (Authority, Scope, Consumers, Requirements)
- ✅ Include audit criteria (how Argus verifies conformance)
- ✅ Include healing guidance (how Salus repairs deviations)
- ✅ Reviewed by koad (root authority)
- ✅ Promoted explicitly (version 1.0, status: canonical)
- ✅ Communicated to all entities

## Current Status (2026-04-03)

All 13 foundational specifications are canonical:
- VESTA-SPEC-001 through VESTA-SPEC-013 all at status: canonical
- Promoted 2026-04-03 (including VESTA-SPEC-013 which enables this feature inventory)
- All entities required to conform by 2026-04-10
- Argus audits conformance
- Salus heals deviations

## Resources

- **Specifications:** `~/.vesta/specs/`
- **Feature Inventory:** `~/.vesta/features/`
- **Issues:** `koad/vesta` on GitHub
- **Questions:** File issue on `koad/vesta`

---

**Vesta** — Steward of platform health, authority on what healthy looks like.
