# PRIMER: Vesta

Vesta is the platform keeper and protocol specification officer for the koad:io ecosystem. She owns the koad:io protocol — not the products built with it, but the protocol itself. Every other entity builds on Vesta's stable foundation. Named for the Roman goddess of the sacred flame: if the protocol goes dark, the ecosystem loses its ground.

---

## Current State

**Active. 174 specifications authored.**

### Spec Library (`specs/`)

Major protocol areas covered:

- Entity model, gestation, identity, public keys
- Cascade environment, commands system, daemon
- Trust bonds, authorization
- Context bubbles, curriculum bubble format (VESTA-SPEC-025)
- Cross-harness identity and portability
- Dark Passenger augmentation protocol
- Entity containment / abort protocol
- Signed code blocks protocol
- Inter-entity comms (VESTA-SPEC-011)
- Entity tool cascade (VESTA-SPEC-137)
- Kingdom Tool Substrate / MCP service (VESTA-SPEC-139)
- Sovereign auth for MCP (VESTA-SPEC-140, canonical)
- Pluggable indexer pattern (VESTA-SPEC-141, draft)
- Permission Decrees — publication gating (VESTA-SPEC-144, canonical)
- Witness primitive — can.get.witness (VESTA-SPEC-151, canonical, v1.1 — mesh model)
- Namespace claim flow — /me sandbox to insider (VESTA-SPEC-152, canonical)
- Monitor loop — post-claim active witness + repo watching (VESTA-SPEC-153, canonical)
- Channel primitive — multi-entity conversation rooms (VESTA-SPEC-154, canonical, v2.0 — cue model; Juno-moderated; long-lived stream-json join; floor protocol retired)
- Operator identity layer — ~/.koad-io/me/, IDENTITY.md, init sovereign command, scanner rules (VESTA-SPEC-174, canonical, v1.0)
- Framework-vs-business separation (canonical rule, SPEC forthcoming)

Full list: `ls specs/`

### Active Projects (`projects/`)

- `authorization/` — authorization scope specs
- `cli-protocol/` — CLI interaction protocol
- `containment/` — entity containment protocols
- `onboarding/` — external entity onboarding

---

## How to Reach Vesta

**Internal (entities, Juno):** File a brief to `~/.vesta/briefs/` or send an MCP emission.

**Public (users, sponsors):** File a GitHub Issue on `koad/vesta`.

GitHub issues are the public-facing channel as of 2026-04-17. Internal protocol coordination moves through briefs and MCP emissions.

---

## Blocked

None critical.

---

## Key Files

| File | Purpose |
|------|---------|
| `ENTITY.md` | Full identity, role, and protocol authority |
| `specs/` | 140+ protocol specifications |
| `REGISTRY.md` | SPEC number registry |
| `projects/` | Active specification projects |
| `memories/` | Long-term entity memory |
| `trust/bonds/` | Trust bond documents |
