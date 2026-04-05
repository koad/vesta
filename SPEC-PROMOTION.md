---
type: process
id: VESTA-PROCESS-001
title: "Spec Promotion Workflow and Conformance Audit"
status: canonical
created: 2026-04-05
updated: 2026-04-05
owner: vesta
resolves: koad/vesta#23
description: "How a spec moves from draft → review → canonical, how conformance audits work, and how spec changes are communicated to entities."
---

# Spec Promotion Workflow and Conformance Audit

## 1. Overview

This document defines the lifecycle of a Vesta spec: from initial draft through promotion to canonical status. It also defines the conformance audit process — how entities are checked for compliance with canonical specs, and how spec changes are communicated.

**Authority:** Vesta (promotion decisions). koad (final approval for canonical status).

---

## 2. Spec Lifecycle

```
draft → review → canonical
              ↘ rejected (returned to draft with feedback)
canonical → deprecated (superseded or retired)
```

Specs do not go backwards from canonical. A canonical spec is either in force or deprecated — it is not demoted to draft. If significant changes are needed, a new spec version is written (e.g., VESTA-SPEC-007-v2) and the original is deprecated.

---

## 3. Status Definitions

| Status | Meaning |
|--------|---------|
| `draft` | Work in progress. Not binding. May change significantly. |
| `review` | Complete enough for feedback. Filed as GitHub issue for comment. |
| `canonical` | Approved and binding. All new entities must conform. Existing entities should migrate. |
| `stable` | Equivalent to canonical — used for specs not originally authored with lifecycle tracking. |
| `deprecated` | Superseded or retired. No new conformance required. Existing use permitted until sunset date. |

---

## 4. Draft Phase

**Entry:** Vesta (or any entity, via PR) creates a `.md` file in `~/.vesta/specs/` with `status: draft`.

**Requirements:**
- YAML frontmatter with `id`, `title`, `status: draft`, `created`, `owner`
- Must have a `description` field
- Must reference any issues it resolves via `resolves:` or `related-issues:` fields
- Must have at least one of: Overview, Gap, What this covers sections

**Acceptable incomplete state:** Open questions, placeholder sections, unresolved design decisions marked with `[TODO]` or `[OPEN]`.

**Transition trigger:** Author decides the spec is complete enough for external review, OR a GitHub issue requests promotion.

---

## 5. Review Phase

**Entry:** Author updates frontmatter to `status: review` and files a GitHub issue on `koad/vesta` with:
- Subject: `Review: [SPEC-ID] [title]`
- Body: link to spec file, what feedback is sought, timeline

**Who reviews:**
- koad (approves all promotions to canonical)
- Affected entities (e.g., a gestation spec review includes Vulcan)
- Vesta (checks structural completeness)

**Duration:** Minimum 24 hours open for comment before promotion. For specs affecting all entities: minimum 72 hours.

**Review criteria:**
1. All required sections present (per spec type)
2. No unresolved `[TODO]` or `[OPEN]` items that would affect conformance
3. Consistent with related specs (no contradictions)
4. Conformance criteria are testable (Argus can verify them mechanically)
5. Migration path exists for existing entities (if applicable)

**Outcomes:**
- **Approved:** Proceed to canonical promotion
- **Rejected:** Return to draft with feedback in issue comment. Spec stays at `status: draft`.

---

## 6. Canonical Promotion

**Performed by:** Vesta (commit) after koad's approval (issue comment or review approval).

**Steps:**

1. Update frontmatter:
   ```yaml
   status: canonical
   updated: <YYYY-MM-DD>
   changelog:
     - "<YYYY-MM-DD>: Promoted from draft to canonical — koad/vesta#<issue>"
   ```

2. Remove or resolve all `[TODO]` and `[OPEN]` markers.

3. If the spec has a final status statement at the bottom, update it:
   ```
   **Canonical Status:** This specification is canonical as of <date>. [...]
   ```

4. Commit to `main` with message:
   ```
   spec: promote [SPEC-ID] to canonical — resolves koad/vesta#<issue>
   ```

5. Close the promotion issue with a comment:
   ```
   [SPEC-ID] promoted to canonical. Binding as of <date>.
   ```

6. **Notify affected entities** (see §8).

7. **Update REGISTRY.yaml** (see `specs/REGISTRY.yaml`) with new status and date.

---

## 7. Deprecation

When a canonical spec is superseded or retired:

1. Update frontmatter:
   ```yaml
   status: deprecated
   deprecated: <YYYY-MM-DD>
   superseded_by: <SPEC-ID of replacement>
   sunset: <YYYY-MM-DD>  # last date old spec is considered acceptable
   ```

2. Add deprecation notice at the top of the spec body:
   ```markdown
   > **DEPRECATED** as of <date>. Superseded by [SPEC-ID](link). 
   > Sunset date: <date>. After sunset, conformance to this spec is not sufficient.
   ```

3. File a migration issue on each affected entity repo (see §8).

4. Update REGISTRY.yaml.

**Retention:** Deprecated specs are kept in `~/.vesta/specs/` indefinitely for historical reference. They are never deleted from git.

---

## 8. Change Communication

When a canonical spec is promoted, updated, or deprecated, Vesta notifies affected entities.

### 8.1 Who Is Affected

| Change type | Notify |
|-------------|--------|
| New canonical spec | All entities listed in spec's `applies-to` field; all entities if field is absent |
| Update to existing canonical spec | Same as above, plus any entity known to implement the spec |
| Deprecation | All entities currently conforming to the deprecated spec |

### 8.2 Notification Method

File a GitHub issue on each affected entity repo:

```
Subject: Spec update: [SPEC-ID] [title] — action required by <date>

[SPEC-ID] ([title]) has been promoted/updated/deprecated.

What changed:
- [brief summary of changes]

What you need to do:
- [specific steps to achieve conformance, or "no action required"]

Migration deadline: <date or "no deadline">

See: [link to spec]
```

### 8.3 Acknowledgment Tracking

The filing of the issue is sufficient notification. The entity is responsible for:
1. Acknowledging via issue comment
2. Creating follow-up work items if migration is needed
3. Closing the issue when conformance is achieved

Vesta does not track acknowledgment beyond filing the issue. Argus runs conformance audits (§9) to verify actual compliance.

---

## 9. Conformance Audit

### 9.1 What Vesta Audits

Vesta runs periodic protocol-level audits — checking that entities conform to canonical specs, not just that their processes are running (that's Argus's real-time health role).

**Audit scope:**
- Entity directory structure against VESTA-SPEC-001 (Entity Model)
- `.env` files against VESTA-SPEC-005 (Cascade Environment)
- Trust bonds against VESTA-SPEC-007 (Trust Bond Protocol)
- Hook architecture against VESTA-SPEC-020 (Hook Architecture)

### 9.2 Audit Command

```bash
vesta audit entities
```

Implementation: `~/.vesta/commands/audit/entities/command.sh`

**Output format:**

```
=== Vesta Conformance Audit ===
Date: 2026-04-05
Canonical specs audited: SPEC-001, SPEC-005, SPEC-007, SPEC-020

Entity        SPEC-001  SPEC-005  SPEC-007  SPEC-020  Overall
--------      --------  --------  --------  --------  -------
juno          ✓         ✓         ✓         ✓         PASS
vulcan        ✓         ✓         ✗         ✓         FAIL
vesta         ✓         ✓         ✓         ✓         PASS
mercury       ✓         ✗         -         ✓         WARN

Legend: ✓ = compliant, ✗ = non-compliant, - = not applicable, ? = unable to check
```

### 9.3 Audit Report Format

Audit reports are stored in `~/.vesta/var/audit/` as timestamped YAML files:

```yaml
audit_id: audit-2026-04-05-001
date: 2026-04-05T00:00:00Z
audited_by: vesta
specs_audited:
  - VESTA-SPEC-001
  - VESTA-SPEC-005
  - VESTA-SPEC-007
  - VESTA-SPEC-020
entities:
  - name: juno
    overall: pass
    checks:
      VESTA-SPEC-001: pass
      VESTA-SPEC-005: pass
      VESTA-SPEC-007: pass
      VESTA-SPEC-020: pass
  - name: vulcan
    overall: fail
    checks:
      VESTA-SPEC-001: pass
      VESTA-SPEC-005: pass
      VESTA-SPEC-007: fail
      VESTA-SPEC-020: pass
    deviations:
      - spec: VESTA-SPEC-007
        entity: vulcan
        issue: "trust/bonds/ directory exists but koad-to-vulcan.md.asc missing"
        severity: high
        recommended_action: "Re-sign koad-to-vulcan.md with koad's GPG key"
```

### 9.4 Who Acts on Audit Results

- **Pass**: No action required.
- **Fail (high severity)**: Vesta files an issue on the entity repo with `priority: high`.
- **Fail (low severity)**: Vesta files an issue on the entity repo with `priority: low`.
- **Warn**: Vesta notes in the audit report; no immediate issue filed.

**Healing** (fixing the deviations) is Salus's responsibility. Vesta only diagnoses and reports.

### 9.5 Audit Frequency

Audits should run:
- After any canonical spec promotion
- Weekly (manual trigger for now; daemon worker when available)
- On demand via `vesta audit entities`

---

## 10. Spec Review Checklist

When Vesta reviews a spec before promoting it, use this checklist:

### Structural Completeness
- [ ] YAML frontmatter: `id`, `title`, `status`, `created`, `owner`, `description` all present
- [ ] No unresolved `[TODO]` markers in normative sections
- [ ] At least one example demonstrating the protocol
- [ ] Conformance criteria are testable (Argus can verify mechanically)

### Content Quality
- [ ] Protocol area is clear (which of the 10 areas does this cover?)
- [ ] Scope boundary is explicit (what this spec does and does not cover)
- [ ] Related specs are cross-referenced
- [ ] Error handling or failure modes addressed

### Integration
- [ ] Consistent with VESTA-SPEC-001 (Entity Model) — no contradictions
- [ ] Migration path for existing entities (if applicable)
- [ ] `applies-to` field present (which entities must conform)

### Registry
- [ ] REGISTRY.yaml entry exists or will be added on promotion

---

## Appendix: Related Files

- `specs/REGISTRY.yaml` — machine-readable index of all specs
- `commands/audit/entities/command.sh` — conformance audit command
- `specs/entity-model.md` (VESTA-SPEC-001) — the primary conformance target
- `specs/cascade-environment.md` (VESTA-SPEC-005) — audited in all entity checks
- `specs/trust-bond-protocol.md` (VESTA-SPEC-007) — audited in all entity checks
