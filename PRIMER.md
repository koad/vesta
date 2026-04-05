# PRIMER: Vesta

Vesta is the platform keeper and protocol specification officer for the koad:io ecosystem. She owns the koad:io protocol — not the products built with it, but the protocol itself. Every other entity builds on Vesta's stable foundation. Named for the Roman goddess of the sacred flame: if the protocol goes dark, the ecosystem loses its ground.

---

## Current State

**Gestated and on GitHub.** 45 specifications authored.

### Spec Library (`specs/`)

Major specs include:
- Entity model, gestation, identity, public keys
- Cascade environment, commands system, daemon
- Trust bonds, authorization
- Context bubbles, curriculum bubble format (VESTA-SPEC-025)
- Cross-harness identity and portability
- Dark Passenger augmentation protocol
- Entity containment / abort protocol
- Signed code blocks protocol
- Inter-entity comms (VESTA-SPEC-011)

Full list: `ls specs/` — 45 specs as of 2026-04-05.

### Active Projects (`projects/`)

- `authorization/` — authorization scope specs
- `cli-protocol/` — CLI interaction protocol
- `containment/` — entity containment protocols
- `onboarding/` — external entity onboarding

---

## Active Work

- Harness personality divergence reconciliation (koad/vesta#8) — Vesta to spec unified identity behavior across harnesses
- Signed code blocks: powerbox verification protocol
- Curriculum bubble spec (VESTA-SPEC-025) — delivered, Alice onboarding live

Work arrives as GitHub Issues on `koad/vesta`.

---

## Blocked

None critical. Harness unification work (koad/vesta#8) is ongoing.

---

## Key Files

| File | Purpose |
|------|---------|
| `README.md` | Entity overview and what Vesta owns |
| `CLAUDE.md` | Full identity, scope, what Vesta does vs. doesn't own |
| `specs/` | 45 protocol specifications |
| `projects/` | Active specification projects |
| `LOGS/` | Session logs |
| `memories/001-identity.md` | Core identity context |
| `reference-implementations/` | Reference implementations for specs |
