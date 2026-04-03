---
status: canonical
id: VESTA-SPEC-013
version: 1.0
date: 2026-04-03
promoted: 2026-04-03
owner: vesta
references:
  - VESTA-SPEC-001 (entity model)
  - VESTA-SPEC-006 (commands system)
  - koad request (2026-04-03)
---

# VESTA-SPEC-013: Features-as-Deliverables Protocol

**Authority:** Vesta (platform stewardship). This spec defines how koad:io entities declare and track features, capabilities, and deliverables as first-class filesystem artifacts.

**Scope:** All autonomous entities in the koad:io ecosystem use this protocol to make project progress instantly readable by humans and AI — distinguishing built features from planned ones.

**Consumers:** All entities (Vulcan, Argus, Juno, Salus, etc.), Argus (auditing), humans (filesystem navigation).

---

## 1. Philosophy

Every feature or capability an entity owns should be:

1. **Discoverable** — visible in the filesystem without tooling
2. **Parseable** — AI and humans can instantly understand what's built vs. planned
3. **Trackable** — a single source of truth for project completion
4. **Auditable** — Argus can report entity-level feature completion rates

**The Principle:** The filesystem IS the feature inventory. No separate wiki, task tracker, or documentation required. A feature exists as a markdown file when planned, and is accompanied by (or replaced with) a working `.sh` file or command folder when built.

---

## 2. Features Directory Structure

### Location and Organization

Every entity MUST have a `features/` directory at its root (see VESTA-SPEC-001 Section 2.2):

```
~/.ENTITY/features/
├── feature-one.md          ← Planned feature (no implementation yet)
├── feature-two.md          ← Planned feature
├── feature-one.sh          ← Built feature (shell command or script)
├── api-endpoints/
│   ├── get-status.md       ← Planned capability within domain
│   ├── get-status.sh       ← Built endpoint
│   ├── create-user.md
│   └── delete-cache.sh
├── diagnostics/
│   ├── health-check.md
│   ├── audit-logs.md
│   └── audit-logs.sh
└── healing/
    ├── recover-keys.md
    ├── rebuild-env.sh
    └── restore-bonds.sh
```

### Organization Principles

- **Flat for small feature sets:** If an entity has <10 features, keep them flat in `features/`
- **Domain grouping:** Use subdirectories to organize by functional domain (e.g., `diagnostics/`, `healing/`, `api-endpoints/`)
- **No nesting beyond 2 levels:** Subdirectories may contain features, but those features should not have subdirectories

### File Naming

- **Markdown placeholders:** `kebab-case.md` (e.g., `recover-keys.md`)
- **Shell implementations:** `kebab-case.sh` (e.g., `recover-keys.sh`)
- **Command folders:** `kebab-case/` (e.g., `diagnose-entity/`) containing a `command.sh` file

---

## 3. Feature Markdown File Format

Every planned or built feature has a markdown file with required frontmatter.

### Frontmatter Schema

```yaml
---
status: draft | in-progress | complete
owner: <entity-name>
priority: critical | high | medium | low
description: <one-line summary>
started: <YYYY-MM-DD> (optional, date work began)
completed: <YYYY-MM-DD> (optional, date feature finished)
---
```

### Field Definitions

| Field | Type | Required | Values | Purpose |
|-------|------|----------|--------|---------|
| `status` | enum | Yes | `draft`, `in-progress`, `complete` | Lifecycle stage of the feature |
| `owner` | string | Yes | Entity name (e.g., `vesta`, `salus`) | Who owns this feature |
| `priority` | enum | Yes | `critical`, `high`, `medium`, `low` | Feature importance |
| `description` | string | Yes | One-line summary | Human-readable description |
| `started` | date | No | `YYYY-MM-DD` | When implementation began |
| `completed` | date | No | `YYYY-MM-DD` | When feature was completed |

### Content Structure

After frontmatter, the markdown file MUST contain:

1. **## Purpose** — Why this feature exists, what problem it solves
2. **## Specification** — Detailed behavior, inputs, outputs, edge cases
3. **## Implementation** — (If built) notes on how it's implemented
4. **## Dependencies** — Other features or entities this depends on
5. **## Testing** — How it's tested, acceptance criteria
6. **## Status Note** — (Optional) current blockers, design decisions, or notes

### Example: Planned Feature

```markdown
---
status: draft
owner: salus
priority: high
description: Recover missing cryptographic keys from backup
started: 2026-04-03
---

## Purpose

When an entity's private keys are lost but the entity was backed up, Salus should be able to restore keys from the backup vault. This unblocks entities that would otherwise be permanently inaccessible.

## Specification

**Input:** Entity name (`ENTITY`), backup location

**Output:** Restored keys in `~/.ENTITY/id/`, verification report

**Behavior:**
- Authenticate to backup vault (Keybase/Saltpack or manual)
- Fetch encrypted key bundle for entity
- Decrypt with entity's recovery passphrase
- Verify keys are valid Ed25519/ECDSA/RSA
- Write to `id/` with correct permissions (600 for private, 644 for public)
- Emit recovery log

**Edge cases:**
- Recovery passphrase incorrect → emit warning, abort
- Keys already present → confirm overwrite before proceeding
- Backup corrupted → emit diagnostic, abort

## Implementation

(Not yet built)

## Dependencies

- Keybase integration (VESTA-SPEC-015)
- Entity backup protocol (TBD)

## Testing

Acceptance criteria:
- [ ] Can recover keys for test entity
- [ ] Permissions are correct
- [ ] Entity can sign messages with recovered keys
- [ ] Recovery logs are emitted

## Status Note

Blocked on Keybase integration completion (VESTA-SPEC-015 canonical 2026-04-10).
```

### Example: Built Feature

```markdown
---
status: complete
owner: argus
priority: critical
description: Audit entity structure against VESTA-SPEC-001
completed: 2026-04-02
---

## Purpose

Argus must be able to verify that any entity conforms to the canonical entity model. This is the core diagnostic capability.

## Specification

**Input:** Entity directory path

**Output:** JSON report with pass/fail for each conformance criterion

**Behavior:**
- Check required directories exist and are non-empty
- Verify all required files present (CLAUDE.md, .env, etc.)
- Validate cryptographic keys (all types present, permissions correct)
- Verify trust bonds (at least one koad-to-<entity> present)
- Check .env schema (all required variables set)
- Audit git state (clean, main branch, correct remote)
- Verify skills array matches hooks/ directory

**Output format:**
```json
{
  "entity": "vesta",
  "conforms": true,
  "checks": [
    {"name": "directories", "pass": true},
    {"name": "required_files", "pass": true},
    ...
  ],
  "timestamp": "2026-04-03T14:30:00Z"
}
```

## Implementation

Implemented in `diagnose-entity.sh`. See `hooks/diagnose-entity.sh` for code.

## Dependencies

- VESTA-SPEC-001 canonical (met)
- VESTA-SPEC-006 hook spec (met)

## Testing

Tested against all 11 entities in koad:io ecosystem. 100% pass rate.

## Status Note

Ready for production use.
```

---

## 4. Placeholder Pattern in `commands/` and `hooks/`

When a command or hook is planned but not yet built, use a markdown placeholder in its location.

### Example: Planned Command

Before implementation:
```
~/.ENTITY/commands/publish/
├── content.md        ← Specification (this is the placeholder)
└── (no command.sh yet)
```

**File: `commands/publish/content.md`**

```markdown
---
status: draft
owner: mercury
priority: high
description: Publish release to production
---

## Purpose

Mercury needs to be able to push a release build to production systems, including version bumping, changelog generation, and rollout.

## Interface

**Arguments:**
- `--version` (required): semantic version to publish
- `--changelog` (optional): path to changelog file
- `--environment` (optional): target environment (staging, prod)

**Output:** JSON report with deployment status

## Specification

(Detailed behavior...)

## Testing

(Acceptance criteria...)

## Status Note

Design review pending with koad (2026-04-05).
```

After implementation:
```
~/.ENTITY/commands/publish/
├── command.sh        ← Implementation
├── content.md        ← Now documents the built feature
└── tests.sh          ← Optional test suite
```

**Update `content.md`:**

```markdown
---
status: complete
owner: mercury
priority: high
description: Publish release to production
completed: 2026-04-04
---

## Purpose

Mercury publishes release builds to production, handling version bumping, changelog generation, and rollout.

## Interface

(Same as before)

## Implementation

Implemented in `command.sh`. Uses semantic versioning with changelog generation via `git log` parsing.

## Status Note

Production-ready.
```

### Example: Planned Hook

Before implementation:
```
~/.ENTITY/hooks/
├── audit-inventory.md   ← Hook specification
└── (no audit-inventory.sh yet)
```

**File: `hooks/audit-inventory.md`**

```markdown
---
status: draft
owner: argus
priority: critical
description: List and audit all files in an entity
---

## Purpose

(Hook specification and interface)
```

After implementation:
```
~/.ENTITY/hooks/
├── audit-inventory.sh   ← Implementation
└── audit-inventory.md   ← Still documents the hook
```

---

## 5. Features Directory as a Checklist

The `features/` directory serves as a **project checklist**. When Argus or any observer reads `features/`, they immediately see:

- How many features are planned (`*.md` files with `status: draft`)
- How many are in progress (`*.md` files with `status: in-progress`)
- How many are complete (`*.md` files with `status: complete`, often paired with `.sh` files)
- What the priorities are

**Quick audit:**
```bash
# Count by status
grep -r "^status:" features/ | grep draft | wc -l      # Planned
grep -r "^status:" features/ | grep in-progress | wc -l # In-progress
grep -r "^status:" features/ | grep complete | wc -l    # Complete
```

---

## 6. Argus Feature Audit Criteria

When Argus audits feature completion, it verifies:

### 6.1 Directory Existence

- `features/` directory exists at entity root
- All feature files (`.md` and `.sh`) have matching frontmatter or pair

### 6.2 Frontmatter Validation

For every feature markdown file:
- `status` is one of: `draft`, `in-progress`, `complete`
- `owner` matches entity name or is a documented delegated owner
- `priority` is one of: `critical`, `high`, `medium`, `low`
- `description` is a non-empty string
- If `status: complete`, `completed` date is present
- If `status: in-progress`, at least one of `started` or `completed` is present
- If `status: draft`, `started` and `completed` are absent (or `completed` is absent)

### 6.3 Implementation Pairing

- If `status: complete`, the feature MUST be paired with either:
  - A corresponding `.sh` file (for shell commands)
  - A corresponding `kebab-case/command.sh` folder (for command subsystems)
  - If no `.sh` exists, `## Implementation` section must document where the code lives

### 6.4 Content Completeness

For every feature markdown file with `status: draft` or `in-progress`:
- MUST have `## Purpose` section
- MUST have `## Specification` section
- MUST have `## Testing` section (acceptance criteria for completion)

For every feature with `status: complete`:
- MUST have `## Implementation` section
- MUST have `## Testing` section (showing how it was tested)

### 6.5 Audit Report Format

Argus generates a feature completion report:

```json
{
  "entity": "vulcan",
  "report_date": "2026-04-03T14:35:00Z",
  "features": {
    "total": 24,
    "draft": 8,
    "in_progress": 5,
    "complete": 11,
    "completion_rate": 0.458
  },
  "by_priority": {
    "critical": {"total": 5, "complete": 3, "completion_rate": 0.6},
    "high": {"total": 6, "complete": 4, "completion_rate": 0.667},
    "medium": {"total": 8, "complete": 3, "completion_rate": 0.375},
    "low": {"total": 5, "complete": 1, "completion_rate": 0.2}
  },
  "issues": [
    {
      "feature": "rebuild-env",
      "status": "in_progress",
      "issue": "started 2026-03-28, no `started` date in frontmatter"
    },
    {
      "feature": "health-check",
      "status": "complete",
      "issue": "no corresponding .sh file found"
    }
  ]
}
```

---

## 7. Integration with Entity Lifecycle

### Gestation (Juno)

When Juno creates a new entity:
1. Creates `features/` directory
2. (Optional) Seeds with placeholder features for core responsibilities

### Activation (Entity)

No special action. Entity reads `features/` to understand its own scope.

### Maintenance (Argus / Salus)

**Argus:**
- Audits feature inventory as part of entity conformance check
- Reports completion rates to koad for project planning
- Flags features with inconsistent frontmatter or missing implementations

**Salus:**
- Can reconstruct `features/` directory structure from git history if corrupted
- Repairs malformed frontmatter

---

## 8. Examples

### Vesta Features Inventory

```
~/.vesta/features/
├── entity-model.md                    ← VESTA-SPEC-001
├── gestation-protocol.md              ← VESTA-SPEC-004
├── identity-keys.md                   ← VESTA-SPEC-009
├── trust-bonds.md                     ← VESTA-SPEC-003
├── commands-system.md                 ← VESTA-SPEC-006
├── spawn-protocol.md                  ← VESTA-SPEC-008
├── inter-entity-comms.md              ← VESTA-SPEC-011
├── daemon-specification.md            ← VESTA-SPEC-010
├── keybase-saltpack.md                ← VESTA-SPEC-015 (marked complete 2026-04-10)
├── features-as-deliverables.md        ← This spec!
└── diagnostics/
    ├── entity-audit.md
    ├── conformance-check.sh
    └── key-verification.md
```

### Salus Features Inventory

```
~/.salus/features/
├── diagnose-entity.sh                 ← Complete
├── repair-env.sh                      ← Complete
├── recover-keys.md                    ← Draft (blocked on backups)
├── restore-bonds.sh                   ← Complete
├── rebuild-memories.md                ← In-progress
├── healing/
│   ├── rebuild-directory-structure.sh ← Complete
│   ├── restore-git-history.sh         ← Complete
│   ├── recover-from-corruption.md     ← Draft
│   └── verify-integrity.sh            ← Complete
└── reporting/
    ├── healing-report.sh              ← Complete
    └── audit-results.sh               ← Complete
```

---

## 9. Change Log

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 1.0 (canonical) | 2026-04-03 | vesta | **CANONICAL** — Initial protocol for features-as-deliverables, including features/ directory structure, markdown file format with frontmatter, placeholder pattern for commands/ and hooks/, and Argus audit criteria. |

---

## 10. Migration Notes

### For Existing Entities

Entities created before this spec SHOULD migrate their feature tracking to this protocol:

1. **Create `features/` directory** at entity root
2. **Inventory all capabilities:** Walk through `commands/`, `hooks/`, and specs to identify what's built
3. **Create feature markdown for each:**
   - Built features: `status: complete`, include `completed` date
   - Planned features: `status: draft` or `in-progress`
4. **Commit with migration message:** e.g., "spec: migrate feature tracking to VESTA-SPEC-013"

**Timeline:** All entities should migrate by 2026-04-10 (one week).

---

## 11. Notes for Future Enhancement

- Consider a `features/` index file (e.g., `index.json`) for faster auditing by Argus
- Consider integration with GitHub Issues/Projects (track which features have open issues)
- Consider metrics over time (feature completion velocity, burn-down charts)

---

**Status:** Canonical (promoted 2026-04-03). All entities must adopt this protocol. Argus begins auditing feature compliance immediately. Migration deadline: 2026-04-10.

File issues on koad/vesta to propose amendments or ask questions about this protocol.
