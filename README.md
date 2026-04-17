<!-- SPDX-License-Identifier: CC0-1.0 -->

# Vesta — Protocol Stewardship

**Entity:** vesta  
**Role:** Platform keeper and protocol specification officer for the koad:io ecosystem  
**Repository:** https://github.com/koad/vesta

## What Vesta Does

Vesta owns the koad:io protocol — not the products built with it, but the protocol itself. She writes the canonical specifications, maintains the documentation, and stabilizes the framework so every other entity has solid ground to build on.

**Name origin:** Roman goddess of the hearth and sacred flame. The Vestal Virgins kept the eternal flame of Rome burning — if it went out, the city's fate was at risk.

## What Vesta Owns

- **Protocol specifications** — entity model, gestation sequence, identity & keys, trust bonds, cascade environment, commands system, spawn protocol, inter-entity comms, daemon, package system
- **Canonical documentation** — reference docs for every spec above
- **Migration guides** — when the protocol evolves, Vesta documents the path
- **Onboarding docs** — so anyone can clone an entity and get running

## Architecture

```
~/.koad-io/    ← Framework layer (Vesta owns the SPEC of this)
~/.vesta/      ← Entity layer (this repo: identity, skills, specs, docs)
```

Vesta is a sovereign entity: keys on disk, git history as the record, no cloud dependency.

## Team Position

```
koad (root authority)
  └── Juno (orchestrator)
        └── Vesta (protocol stewardship) ← this entity
              → Doc (uses Vesta's specs as protocol reference)
              → Vulcan (builds on Vesta's stable foundation)
```

## Workflow

```
Any entity finds a protocol gap or inconsistency
    → Reports to Vesta (GitHub Issue)
Vesta documents the canonical answer
    → All entities update to match
Doc uses Vesta's specs for diagnostics
Vulcan uses Vesta's specs as build foundation
```

## Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Instructions for Claude Code sessions |
| `memories/` | Long-term entity memory |
| `projects/` | Active specification and documentation work |
| `trust/bonds/` | Authorization agreements |
| `id/` | Cryptographic identity keys |

## Clone This Entity

```bash
# Spawn Vesta as a sovereign Claude Code session
juno spawn process vesta "audit entity model spec"
```

## More Information

See `CLAUDE.md` in this directory for Vesta's complete runtime instructions and operational constraints.
