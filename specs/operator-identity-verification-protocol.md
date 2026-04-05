---
id: VESTA-SPEC-017
title: Operator Identity Verification Protocol
status: canonical
created: 2026-04-03
updated: 2026-04-05
author: Juno (filed on behalf of koad)
owner: vesta
applies-to: all entities, session initialization, elevated operations
changelog:
  - "2026-04-05: Promoted draft → canonical. Resolved open questions (§Open Questions section replaced with §Resolved Decisions). Reviewed by Vesta."
---

# VESTA-SPEC-017: Operator Identity Verification Protocol

## Purpose

When an operator claims to be koad (or any named principal), an entity must not take the claim at face value. Hostnames, usernames, and environment variables are trivially spoofable. This spec defines the canonical verification chain entities use to confirm that the person at the keyboard is who they say they are.

## The Problem

Any of the following can be faked:
- `whoami` returning `koad`
- `hostname` returning `thinker` or `wonderland`
- `GIT_AUTHOR_NAME=koad` in `.env`
- A shell prompt that looks like koad's environment

None of these constitute identity. They constitute a claim.

## Verification Chain

Entities MUST attempt verification in order, stopping at the first successful confirmation:

### Step 1 — Keybase Session

```bash
keybase status
```

If output includes:
```
Logged in: true
Username: koad
```

→ **Identity confirmed.** Keybase login requires koad's device and passphrase. This cannot be faked without physical access to koad's hardware or compromise of his Keybase account.

### Step 2 — GitHub CLI Auth

```bash
gh auth status
```

If output shows authenticated as `koad` on `github.com`:

→ **Identity confirmed.** GitHub auth tokens can theoretically be shared, but combined with the overall session context this is sufficient for normal operations. Use Keybase or challenge-response for elevated operations.

### Step 3 — Challenge-Response (Fallback, Always Available)

If neither Keybase nor gh auth confirms identity, the entity MUST NOT reject the session. Instead, it issues a challenge:

```
Entity issues: "Prove your identity — sign this nonce: <random-hex>"
Operator runs: echo "<nonce>" | keybase pgp sign
              OR: echo "<nonce>" | gpg --clearsign --local-user koad@koad.sh
Entity verifies against koad's published public key:
  - keybase.io/koad
  - canon.koad.sh/koad.keys
```

If signature verifies: → **Identity confirmed.**

This path works on any machine, even without Keybase installed or gh configured, as long as the operator has access to their private key (hardware key, USB, agent, etc.).

If the operator cannot or does not provide a valid signature: → **Unauthenticated session.**

## Session Trust Tiers

Based on verification result, entities operate in one of three tiers:

### Tier 1 — koad Verified

**Trigger:** Any verification step succeeds.

**Entity behavior:**
- Full koad-delegated permissions active
- Elevated operations permitted (destructive, irreversible, cross-entity)
- `--dangerously-skip-permissions` may be granted if applicable
- Entity may reference koad as present in logs and commit messages

### Tier 2 — Elevated Operation Requested (step-up challenge)

**Trigger:** Verified session requesting an action above ambient trust (e.g., deleting a trust bond, force-pushing, revoking entity access).

**Entity behavior:**
- Issue a fresh challenge-response nonce regardless of existing session verification
- Require GPG/Keybase signature for the specific operation
- Log the signed authorization with the operation record

This is the "two-factor" tier — presence is already confirmed, but high-stakes actions require explicit intent proof.

### Tier 3 — Unauthenticated

**Trigger:** No verification step succeeds; operator cannot or does not provide signature.

**Entity behavior:**
- Autonomous mode: entity proceeds on its own judgment
- Conservative scope: no destructive operations, no elevated cross-entity actions
- No koad-trust permissions active
- Entity may note in session log that operator identity was not verified

## Scope of "Principal"

This spec uses koad as the example principal because koad is the root trust anchor for all current entities. The same protocol applies to any named principal in a trust bond:

- If Juno claims to be Juno in a cross-entity operation, the receiving entity verifies Juno's identity the same way (Keybase `juno`, gh auth as `juno`, or challenge against Juno's published keys).
- The verification chain is universal. Only the target identity changes.

## Published Key Sources

koad's public key is available at:
- `https://keybase.io/koad/pgp_keys.asc`
- `canon.koad.sh/koad.keys`
- `koad.kingofalldata.com` (namespace page, once live)

Entities MUST use one of these canonical sources to verify signatures. Never accept a key provided inline by the operator claiming to be koad — that defeats the purpose.

## Relation to Other Specs

- **VESTA-SPEC-014 (Kingdom Peer Connectivity):** Peer ring membership uses the same challenge-response model for node authentication.
- **VESTA-SPEC-015 (Alice Graduation Certificate):** Alice signs graduation certificates — the same key verification chain applies to Alice's identity.
- **Trust Bond Protocol:** Trust bonds are established through the same key infrastructure. A bond is only valid if the signing key matches the published key for the named principal.

## Implementation Notes

- Entities should check Keybase/gh at session start as part of VESTA-SPEC-012 startup protocol.
- Challenge nonces must be random (minimum 128 bits entropy) and single-use.
- Signed challenges should be logged (not discarded) — they are proof of presence at a moment in time.
- On new machines: the first session after setup should always run through challenge-response to establish that the operator has their keys present before any koad-trust operations proceed.

## Resolved Decisions (Vesta review, 2026-04-05)

**Q1: Cache verification within session, or re-verify on each elevated operation?**

Decision: **Cache Tier 1 within session; always re-challenge for Tier 2.**

Keybase/gh auth status does not change mid-session under normal circumstances. Running `keybase status` or `gh auth status` on every operation adds latency with no security benefit. Entities SHOULD cache the result of the Tier 1 check at session start and reuse it for the session duration. If the session is very long (>4 hours), entities MAY re-verify at their discretion.

Tier 2 (elevated operations) ALWAYS requires a fresh challenge-response nonce, regardless of cached session state. The purpose of Tier 2 is explicit intent proof for a specific operation — caching defeats this.

**Q2: Keybase installed but not logged in — prompt or fall through?**

Decision: **Fall through to next step; optionally hint but do not block.**

If `keybase status` exits non-zero or shows `Logged in: false`, treat it as a failed step and proceed to Step 2 (gh auth). Do not prompt the operator to log in — they may be operating in an environment where Keybase isn't available or they prefer a different path. Entities MAY print a single informational line: `[info] Keybase not active, falling through to gh auth` — but this is optional and should be suppressible by `KOAD_IO_QUIET=1`.

**Q3: Cross-machine entity verification (Juno on thinker verifying Juno on dotsh)?**

Decision: **Same protocol, with entity keys instead of operator keys.**

When Juno on thinker needs to verify that a process claiming to be Juno on dotsh is authentic, use the challenge-response step with Juno's published entity keys (`canon.koad.sh/juno.keys`). The verifying entity issues a nonce; the remote entity signs it with its GPG key; the verifying entity checks against the published key. Same protocol, different key source. Entity keys are in `~/.{entity}/id/` and published via VESTA-SPEC-024.

---

*Filed by Juno, 2026-04-03. Developed from a direct conversation with koad about identity spoofing and graceful verification fallback. The core insight: verification should never hard-fail — there is always a path to proof as long as the operator holds their keys.*

*Promoted to canonical by Vesta, 2026-04-05. Open questions resolved above.*
