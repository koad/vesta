---
id: VESTA-SPEC-032
title: "Sovereignty Risk Assessment — Criteria, Risk Levels, Override Protocol, and Re-Assessment Triggers"
status: draft
created: 2026-04-04
author: Vesta
applies-to: all entities, tool adoption, dependency evaluation, trust bonds
related-specs:
  - VESTA-SPEC-007 (Trust Bond Protocol)
closes: koad/vesta#68
---

# VESTA-SPEC-032: Sovereignty Risk Assessment

## Purpose

Define the canonical framework for evaluating any tool, service, or dependency before adoption in the koad:io ecosystem. Aegis maintains a sovereignty trap registry (`~/.aegis/registry/sovereignty-traps.md`) that catalogs known bad actors. This spec defines the **assessment process** that produces registry entries and governs adoption decisions — the criteria, classification method, override protocol, and re-assessment triggers.

The registry is the output. This spec is the methodology.

---

## 1. Assessment Criteria

Every tool evaluated for adoption must be assessed against all seven criteria. Each criterion is a binary flag (pass / fail / unknown) plus a risk modifier.

### 1.1 Criterion Table

| # | Criterion | Pass condition | Risk modifier |
|---|-----------|---------------|---------------|
| C1 | **Data jurisdiction** | Data physically resides in a jurisdiction with favorable law, or self-hosted with no external data flow | `high` if adversarial jurisdiction (PRC, authoritarian states); `medium` if surveillance-capitalism jurisdiction (US, EU) without DPA |
| C2 | **Ownership transparency** | Company ownership is publicly known; no adversarial state interest or undisclosed investment | `high` if PRC-connected; `medium` if venture-backed with unclear data monetization |
| C3 | **Self-host option** | A functionally equivalent self-hosted version exists and is maintained | `high` if no self-host option AND data sensitivity is high; `medium` if no self-host but data is low-sensitivity |
| C4 | **Data portability** | Data can be exported in a usable format and deleted on request | `high` if no export; `medium` if export exists but is format-locked or throttled |
| C5 | **Kill switch exposure** | Vendor cannot unilaterally revoke access or destroy data without operator action | `high` if vendor can kill access with no notice or remedy (API shutdowns, account bans); `medium` if access is subscription-gated but data is portable |
| C6 | **Open source** | Core code is open source and auditable | `medium` if closed; does not escalate to `high` alone |
| C7 | **Track record** | No prior data incidents, surprise policy reversals, or sudden shutdowns in the past 3 years | `high` if shutdown history with data loss (e.g., Sora March 2026); `medium` if policy reversals without data loss |

### 1.2 Scoring

No numeric score. Risk level is the **highest severity** across all criteria:

- Any `high` criterion → **high risk**
- No `high` criteria, any `medium` criterion → **medium risk**
- All pass → **advisory** (document and monitor, no restriction)

Unknown criteria are treated as the worst-case modifier for their criterion until clarified. An assessment with unresolved unknowns is marked `incomplete` and may not be used for adoption decisions.

---

## 2. Risk Levels

### 2.1 Definitions

| Risk level | Meaning | Default action |
|-----------|---------|----------------|
| **high** | Blocked by default. One or more criteria fail with high-severity modifier. | Do not adopt. Requires koad override to use. |
| **medium** | Use with caution. No high-severity failures, but sovereign alternative is preferred. | Use if sovereign alternative is unavailable or unsuitable. Document the tradeoff. |
| **advisory** | Low concern. All criteria pass or fail only at low severity. | Adopt with monitoring. Log the entry in the registry. |

### 2.2 Risk-Level Examples from Registry

| Tool | Risk | Key failure |
|------|------|-------------|
| Kling AI | high | C1 (PRC jurisdiction), C3 (no self-host) |
| OpenAI API (non-Enterprise) | high | C5 (training rights without enterprise agreement), C3 (no self-host) |
| ElevenLabs (non-Enterprise) | high | C4 (3-year audio retention), C3 (no self-host) |
| Figma | medium | C3 (no self-host), C4 (all files in Figma cloud) |
| ElevenLabs (Enterprise + ZRM) | advisory | C3 (no self-host), mitigated by Zero Retention Mode |

---

## 3. Override Protocol

koad has root authority to knowingly accept a trapped tool. An override is not a risk reclassification — it is a documented exception.

### 3.1 When Override Is Appropriate

An override is appropriate when:
- The tool provides a unique capability with no sovereign equivalent at acceptable quality
- The tradeoff is explicit and bounded (specific use case, not blanket adoption)
- A migration path to a sovereign alternative is in progress or on the roadmap

An override is **not** appropriate when:
- The tool is simply convenient or cheaper
- A sovereign alternative exists and is functional
- The data involved is entity strategy, personas, or confidential client work

### 3.2 Override Format

Overrides are filed as a comment on the registry entry in `~/.aegis/registry/sovereignty-traps.md`:

```yaml
# In the tool's registry entry:
koad-override: conditional — [specific use case] permitted if [specific conditions]
override-rationale: [why the tradeoff is acceptable for this case]
override-expires: [date or "until sovereign alternative ships"]
```

An override with no expiry or condition is not a valid override — it is a policy change. Policy changes require a new entry (risk reclassification with updated criteria assessment), not an override.

### 3.3 Override Scope

An override is scoped to the condition stated. It does not grant general adoption. Examples:

- `conditional — permitted for Rufus video production where Wan 2.2 quality is insufficient` → Runway Gen-4.5 may be used for video production only, not for any other use case.
- `not permitted for content involving koad:io strategy, personas, or client work` → Kling AI remains blocked for those contexts even with override discussion.

Entities that use a tool outside its override scope are in violation of the assessment. Aegis may flag this.

---

## 4. Re-Assessment Triggers

An existing registry entry must be re-assessed when any of the following occur:

| Trigger | Urgency | Action |
|---------|---------|--------|
| **Acquisition** | High — within 7 days | Re-evaluate C1, C2 under new ownership. Risk may escalate (e.g., US company acquired by PRC-connected entity). |
| **Policy change** | High — within 7 days | Re-evaluate affected criteria. Data terms changed → re-check C1, C4. API pricing changed → re-check C5. |
| **Jurisdiction change** | High — within 7 days | Re-evaluate C1. Data center move to adversarial jurisdiction escalates to `high` immediately. |
| **Data incident** | High — within 24 hours | Re-evaluate C7. Any breach or unauthorized access triggers immediate review. Current usage suspended pending re-assessment. |
| **Shutdown announcement** | High — within 24 hours | Tool moves to `high` immediately. Migration to sovereign alternative begins. |
| **Enterprise agreement signed** | Medium — within 30 days | Re-evaluate C4, C5 under new contract terms. Risk may de-escalate (e.g., ElevenLabs non-Enterprise → Enterprise+ZRM). |
| **New self-host option released** | Low — next regular review | Re-evaluate C3. Risk may de-escalate. |
| **Annual review** | Low — recurring | All `medium` and `advisory` entries reviewed annually. `high` entries reviewed only if override is active. |

### 4.1 Who Triggers Re-Assessment

Any entity may file a re-assessment request by opening an issue on koad/aegis with the trigger event and the affected registry entry. Aegis owns the re-assessment process and updates the registry. Sibyl provides research support.

---

## 5. Relationship to Trust Bonds

A tool that fails the sovereignty assessment is not a trustable dependency — it cannot be a party to a trust bond and cannot be granted access to entity data through the bond system.

Practically:
- **High-risk tools**: May not receive entity data, API keys, or access to kingdom namespaces. If used at all (via override), interactions are sandboxed and logged.
- **Medium-risk tools**: May receive access proportional to their risk. A medium-risk social publishing tool (e.g., Postiz abstraction over Twitter API) may be granted access to public-facing content but not to private entity data or kingdom namespaces.
- **Advisory tools**: No restriction on trust bond grants. Standard bond process applies.

No `trust bond` type is created specifically for tool adoption. Instead, the sovereignty assessment outcome governs what data may flow to a tool via existing bond-mediated channels.

---

## 6. Assessment Procedure

The procedure for assessing a new tool:

```
1. Sibyl researches the tool against all seven criteria (§1.1)
2. Sibyl files a draft entry in ~/.aegis/registry/ with all criteria answers
3. Aegis reviews the draft, resolves unknowns, assigns risk level (§1.2)
4. Aegis commits the entry — it is now in effect
5. If high risk: entry blocks adoption by default
6. If override is needed: koad adds override fields and rationale (§3.2)
7. Entry is indexed in the registry; all entities read the registry before adopting new tooling
```

Turnaround target: 48 hours from Sibyl research request to committed entry.

---

## 7. Registry Location and Format

The registry lives at: `~/.aegis/registry/sovereignty-traps.md`

Each entry is a Markdown section with the following fields:

```markdown
## <Tool Name> [(Enterprise tier | specific version if relevant)]

- **Company/owner:** <company name and parent if any>
- **Jurisdiction:** <primary data jurisdiction>
- **Trap type(s):** <comma-separated list: adversarial data jurisdiction / surveillance capitalism / no self-host / kill switch / proprietary lock-in / ...>
- **Risk level:** high | medium | advisory
- **Self-host option:** yes | no | partial (note)
- **Criteria failures:** C<n>, C<n>, ... (from §1.1)
- **Flagged by:** <entity> on <date>
- **koad override:** no | conditional — <description> | yes — <rationale>
- **Notes:** <context, sovereign alternatives, prior incidents, anything relevant>
```

The `trap type` field is a human-readable label for the primary failure mode. It does not replace the criteria assessment — it summarizes it for quick scanning.

---

## 8. Sovereign Alternatives Catalog

Every high-risk entry in the registry should document the sovereign alternative. This catalog is the positive side of the assessment: not just what to avoid, but what to use instead.

Pattern:
```
Blocked: Kling AI (PRC jurisdiction, no self-host)
Sovereign alternative: Wan 2.2 (Apache 2.0, self-hostable on fourty4)

Blocked: ElevenLabs non-Enterprise (3-year audio retention)
Sovereign alternative: Kokoro TTS (self-hosted, zero cost)
```

When no sovereign alternative exists at acceptable quality, the registry notes this explicitly and the override protocol (§3) governs adoption. The absence of a sovereign alternative does not lower the risk classification — it is the argument for override, not for reclassification.

---

## 9. References

- `~/.aegis/registry/sovereignty-traps.md` — the registry this spec governs
- VESTA-SPEC-007: Trust Bond Protocol — §5 (relationship to tool adoption)
- koad/vesta#68 — original spec request
- koad/aegis#4 — Sibyl's Kling AI flag that triggered the registry
- Sora (OpenAI) shutdown March 24 2026 — the incident that made C7 (track record) a mandatory criterion

---

*Filed by Vesta, 2026-04-04. The assessment framework formalizes what Aegis and Sibyl were already doing informally. The registry entries in `~/.aegis/registry/sovereignty-traps.md` are the first outputs of this process — written before the process was documented, now retroactively conformant.*
