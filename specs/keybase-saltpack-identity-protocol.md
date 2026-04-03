---
title: "Keybase/Saltpack as koad:io Signing and Identity Layer"
spec-id: VESTA-SPEC-015
status: canonical
created: 2026-04-03
author: Vesta (vesta@kingofalldata.com)
reviewers: [koad, Juno]
related-issues: [koad/vesta#3, koad/vesta#2]
---

# Keybase/Saltpack as koad:io Signing and Identity Layer

## Overview

Keybase provides koad:io with verifiable identity, cryptographic signing, and shared state infrastructure. This spec formalizes Keybase's role as the canonical signing protocol and identity layer for all koad:io entities.

**Current state:** `gestate` command already signs with saltpack blocks. Keybase is installed and koad is logged in. Entity directories have empty `keybase/` folders. This spec unifies these pieces into a canonical protocol.

**Scope:** Saltpack signing, KBFS namespace layout, entity identity under Keybase, team KV store for shared state.

---

## 1. Saltpack Authorization Protocol

### 1.1 Purpose

Entities must verify authorizations from koad (or other trusted entities) before executing state-modifying operations. Saltpack provides cryptographic proof that the authorization came from koad's verified Keybase identity and was not tampered with in transit.

### 1.2 Canonical Signing Flow

**Koad signs an authorization:**

```bash
# koad authorizes Salus to heal Juno
cat > /tmp/auth.txt <<'EOF'
authorized: koad/salus#heal-juno
reason: Juno reported security drift in auth layer
expires: 2026-04-10T23:59:59Z
scope: ~/ juno — full state repair allowed
koad-signature-version: 1
EOF

# Sign with koad's Keybase identity
keybase sign -m /tmp/auth.txt > /tmp/auth.signed

# Output is a complete saltpack armor block, e.g.:
# BEGIN KEYBASE SALTPACK SIGNED MESSAGE. ...
# kWDrASJqaGFzaIkg4O...
# END KEYBASE SALTPACK SIGNED MESSAGE.
```

**Entity verifies authorization:**

```bash
# Salus receives authorization (as GitHub issue comment, Slack message, etc.)
# Salus extracts the saltpack block and verifies it

cat > /tmp/received.signed <<'EOF'
BEGIN KEYBASE SALTPACK SIGNED MESSAGE.
kWDrASJqaGFzaIkg4O...
END KEYBASE SALTPACK SIGNED MESSAGE.
EOF

# Verify the signature
keybase verify -m /tmp/received.signed
# Output: ✓ Signed by koad, verified by Keybase

# Extract message
keybase verify -m /tmp/received.signed -o /tmp/auth.txt
cat /tmp/auth.txt
# → outputs the original authorization
```

### 1.3 Authorization Format

All koad:io saltpack-signed authorizations must include:

```
authorized: <signer>/<target>#<action>
reason: <human-readable reason for this authorization>
expires: <ISO 8601 timestamp — UTC>
scope: <what the authorization permits — freeform but specific>
koad-signature-version: 1
```

**Example 1: Heal authorization**

```
authorized: koad/salus#heal-juno
reason: Juno reported auth layer drift during team session
expires: 2026-04-10T23:59:59Z
scope: ~/.juno/ — full state repair, git reset allowed
koad-signature-version: 1
```

**Example 2: Cross-entity command authorization**

```
authorized: koad/vulcan#publish-mercury-latest
reason: Mercury v1.3.0 security patch approved for release
expires: 2026-04-05T23:59:59Z
scope: Vulcan may publish mercury@latest to npm registry, no other registry
koad-signature-version: 1
```

**Example 3: Emergency override**

```
authorized: koad/juno#skip-deploy-freeze
reason: CRITICAL: Security vulnerability in auth layer, immediate hotfix required
expires: 2026-04-04T06:00:00Z
scope: Juno may bypass merge freeze and deploy to prod
koad-signature-version: 1
```

### 1.4 Where to Post Authorizations

Authorizations should be posted in a location visible to the target entity. Preferred locations (in order):

1. **GitHub issue comment** — on the issue the entity is working on
   - Most visible within normal workflow
   - Timestamped by GitHub
   - Searchable history

2. **Slack message** — in the koad.io team channel or entity's direct channel
   - Real-time notification
   - Thread-able for context

3. **Keybase team channel** — in /keybase/team/koad.io/ chat
   - Cryptographically verified by Keybase
   - Persistent in team history

4. **Git commit message** — in entity's repo
   - Immutable after merge
   - Linked to specific change

### 1.5 Verification Procedure (Entity-Side)

Every entity must implement this verification when receiving an authorization:

```bash
#!/usr/bin/env bash
# verify-authorization.sh — template for all entities

AUTH_BLOCK="${1:?Authorization block (text from comment/message)}"
AUTH_FILE="${2:-/tmp/auth-verify.txt}"

# Write block to temp file
echo "$AUTH_BLOCK" > /tmp/auth-received.signed

# Verify signature
echo "[AUTH] Verifying saltpack block..."
if ! keybase verify -m /tmp/auth-received.signed -o "$AUTH_FILE"; then
  echo "[AUTH ERROR] Signature verification failed"
  exit 1
fi

# Extract metadata
echo "[AUTH] Signature verified. Checking metadata..."
AUTHORIZED=$(grep "^authorized:" "$AUTH_FILE" | cut -d' ' -f2)
EXPIRES=$(grep "^expires:" "$AUTH_FILE" | cut -d' ' -f2)
SCOPE=$(grep "^scope:" "$AUTH_FILE" | cut -d' ' -f2-)

# Check expiration
EXPIRES_EPOCH=$(date -d "$EXPIRES" +%s)
NOW_EPOCH=$(date +%s)
if [ $NOW_EPOCH -gt $EXPIRES_EPOCH ]; then
  echo "[AUTH ERROR] Authorization expired at $EXPIRES"
  exit 1
fi

# Validate authorization is for this entity
EXPECTED_TARGET="koad/$(basename $HOME)#"
if [[ "$AUTHORIZED" != koad/* ]]; then
  echo "[AUTH ERROR] Invalid signer in authorization"
  exit 1
fi

echo "[AUTH] ✓ Valid authorization from koad"
echo "[AUTH]   Target: $AUTHORIZED"
echo "[AUTH]   Scope: $SCOPE"
echo "[AUTH]   Expires: $EXPIRES"
exit 0
```

### 1.6 Revocation

An authorization cannot be revoked after signing (immutability of cryptographic signatures). Instead:

1. **Koad sets expiration limits** — all authorizations include an `expires` field
2. **Short lifespans** — most authorizations expire within hours or days, not months
3. **Scope limiting** — authorization specifies exactly what is permitted

If an authorization is issued in error:

1. Koad immediately posts a **revocation notice** in the same location (same GitHub issue, Slack thread, etc.)
2. **Revocation notice format:**

```
revoke: <authorized action from original block>
reason: <why this authorization is being revoked>
revoked-at: <ISO 8601 timestamp>
koad-signature-version: 1
```

3. Entities receiving a revocation notice must:
   - Check the revocation is signed by koad (using same verification procedure)
   - Cancel any pending operations under the revoked authorization
   - Log the revocation attempt in audit trail

**Example revocation:**

```
revoke: koad/vulcan#publish-mercury-latest
reason: Mercury v1.3.0 contains a new vulnerability, rollback in progress
revoked-at: 2026-04-05T02:15:00Z
koad-signature-version: 1
```

---

## 2. KBFS Layout and Namespaces

### 2.1 KBFS Structure

Each entity gets a canonical layout in Keybase's distributed filesystem:

```
/keybase/public/<entity>/              ← Public namespace (world-readable)
  identity.keys                         ← Entity's public key manifest (see 3.2)
  commands.md                          ← Entity's published command API (optional)

/keybase/private/koad/<entity>/        ← Private koad↔entity channel (koad + entity only)
  trust-bonds.md                       ← Trust agreements between koad and this entity
  state-sync.md                        ← Recent entity state snapshots (optional)

/keybase/team/koad.io/                 ← Team shared space (all entities + koad)
  spec-catalog.md                      ← Index of all canonical specs
  team-clock.md                        ← Distributed timestamp beacon (for consensus)
  incidents.md                         ← Shared incident log
```

### 2.2 Entity Identity Manifest (`identity.keys`)

Each entity publishes a manifest at `/keybase/public/<entity>/identity.keys`:

```yaml
---
entity: vesta
koad-io-version: "1.0"
published: 2026-04-03T12:00:00Z
---

# Vesta Identity Manifest

## Keybase Account

**Entity:** vesta
**Keybase Username:** vesta
**Keybase Device Key:** (long form fingerprint)
**Social Proofs:** GitHub=vesta (team: koad-io)

## Public Keys

### Saltpack Signing Key

- **Key Type:** Saltpack (Ed25519)
- **Fingerprint:** <hex>
- **Use:** Authorization signatures, trust bond commitments
- **Keybase-verified:** ✓ (keybase verify validates this)

### Asymmetric Encryption Key (optional future)

- **Key Type:** ECDSA P-256
- **Fingerprint:** <hex>
- **Use:** (reserved for future encrypted channels)

### SSH Key (if entity acts as daemon)

- **Key Type:** Ed25519
- **Fingerprint:** <hex>
- **Use:** SSH authentication for remote spawning
- **Authorized Hosts:** thinker, fourty4 (koad's machines)

## Trust Chain

- **Issued by:** koad
- **Signed by:** koad's Keybase identity
- **Chain:** koad → this entity
- **Revocation Contact:** koad (via Keybase message)

## Contacts

- **Operator:** koad@kingofalldata.com
- **Keybase Direct:** @vesta (in Keybase team)
```

### 2.3 Local Entity Keybase Directory

In each entity's home directory:

```
~/.vesta/keybase/
  identity.md           ← Entity's identity (links to public version)
  trust-bonds/          ← Local copies of signed trust agreements
    koad-vesta.sig      ← Saltpack-signed by koad and Vesta
  state-cache/          ← Local snapshot cache from KBFS
    team-clock.txt      ← Last read of /keybase/team/koad.io/team-clock.md
    spec-catalog.txt    ← Last read of spec catalog (for offline use)
```

### 2.4 KBFS Access Patterns

**Reading public identity:**

```bash
cat /keybase/public/salus/identity.keys
# Returns: YAML manifest showing Salus's keys and claims
```

**Posting to private koad↔entity channel:**

```bash
# Vesta writes a trust bond agreement
cat > /keybase/private/koad/vesta/trust-bonds.md <<'EOF'
# Trust Bond: koad ↔ Vesta

Effective: 2026-04-03
Expires: 2026-12-31
Signed by: koad (saltpack)
Acknowledged by: vesta (saltpack)

## Mutual Commitments

1. Koad trusts Vesta to maintain protocol stability
2. Vesta commits to publish specs before implementation
3. Both commit to SHA-256 integrity checking on shared files
EOF

# Keybase FUSE mount ensures /keybase/ is writable by this entity
```

**Reading team shared state:**

```bash
# During startup, entity reads team spec catalog
if [ -f /keybase/team/koad.io/spec-catalog.md ]; then
  cp /keybase/team/koad.io/spec-catalog.md ~/.vesta/keybase/state-cache/
fi
```

---

## 3. Keybase as Entity Identity Layer

### 3.1 Entity Account Model

**Question:** Do entities have their own Keybase accounts?

**Answer:** No. Entities operate under koad's Keybase namespace.

**Rationale:**

1. **Single source of authority** — koad is the identity source. No entity has independent Keybase identity.
2. **Keybase device key constraint** — Keybase requires a device key for signing. Entities (abstract agents) don't have physical devices.
3. **Operational simplicity** — All entity signatures are signed by koad, verified by Keybase as koad's signatures, with metadata (entity, action, scope) embedded in the signed message itself.
4. **Trust chain clarity** — koad → entity → external party. All signatures trace back to koad's verified identity.

### 3.2 Entity Signing Model

**How does Vesta sign something?**

Vesta cannot directly call `keybase sign` because Vesta has no Keybase device key. Instead:

1. **Vesta prepares message with metadata:**

```
entity: vesta
action: publish-spec
spec-id: VESTA-SPEC-015
timestamp: 2026-04-03T12:30:00Z
content-hash: sha256:abc123...

---
<message body or file contents>
```

2. **Koad signs on Vesta's behalf:**

```bash
# In koad's session (koad has Keybase device key)
keybase sign -m /tmp/vesta-message.txt > /tmp/vesta-message.signed
```

3. **Signature is attributed to Vesta via message metadata:**

```
Signature Authority: koad
Signed-For: vesta (entity: VESTA-SPEC-015)
```

4. **Third party verifies:**

```bash
keybase verify -m /tmp/vesta-message.signed
# Output: ✓ Signed by koad
# Message metadata shows: "Signed-For: vesta"
# Verifier trusts koad, so they trust this signature as Vesta's commitment
```

### 3.3 Relation to canon.koad.sh Public Key Distribution

**Question:** How does Keybase relate to `canon.koad.sh/<entity>.keys`?

**Answer:** Complementary, not redundant.

| Layer | Purpose | Format | Scope |
|-------|---------|--------|-------|
| **Keybase/Saltpack** | Cryptographic signing, authorization verification | Saltpack armor blocks | Per-transaction, short-lived |
| **canon.koad.sh** | Public key distribution, identity stability | PEM/JSON manifests | Long-term, foundational |

**Practical use:**

1. **Bootstrap:** New entity reads `canon.koad.sh/<entity>.keys` to learn Keybase username, device fingerprint, and SSH keys
2. **Runtime:** Entity uses Keybase for signing/verification, trusts koad's device key from bootstrap
3. **Sync:** Koad periodically syncs `canon.koad.sh` with current Keybase device state

**No circular dependency:** canon.koad.sh is static, Keybase is dynamic. Both point to the same truth, but Keybase is the live authority.

### 3.4 Entity Key Lifecycle

Each entity goes through key states:

#### New entity

1. Koad creates entity (via `gestate` command)
2. Koad runs Keybase integration (see Gestation Template)
3. Koad publishes entity's public key manifest to `/keybase/public/<entity>/identity.keys`
4. Koad adds entity keys to `canon.koad.sh/<entity>.keys`
5. Entity reads bootstrap, discovers its own identity via Keybase

#### Rotating entity keys

1. Koad generates new key for entity (offline, in koad's session)
2. Koad signs a **key rotation announcement:**

```
key-rotation: entity=vesta
timestamp: 2026-04-03T15:00:00Z
old-fingerprint: <old>
new-fingerprint: <new>
reason: Routine rotation (90-day schedule)
```

3. Koad signs with old key, posts announcement to `/keybase/team/koad.io/key-rotations.md`
4. Entities verify using old key, trust new key going forward
5. Koad updates `canon.koad.sh` and `/keybase/public/<entity>/identity.keys`

#### Revoking entity access

1. Koad signs a **revocation notice:**

```
key-revoke: entity=salus
timestamp: 2026-04-03T16:00:00Z
fingerprint: <revoked>
reason: Security incident, entity compromised
action: Salus will cease signing operations until new key issued
```

2. Posted to `/keybase/team/koad.io/revocations.md`
3. All entities stop trusting signatures from revoked entity until new key published

---

## 4. KV Store Protocol (Team Chat)

### 4.1 Purpose

Keybase team chat rooms support key-value storage. koad:io uses this for shared state that doesn't fit in git (real-time, consensus-based, audit log).

### 4.2 Canonical Uses

#### 4.2.1 Team Clock (Distributed Timestamp Beacon)

**Problem:** Entities need a shared sense of time for consensus on "what happened first." Git commits have timestamps, but they're mutable. Keybase team chat is immutable once posted.

**Solution:** Team posts daily clock message to `/keybase/team/koad.io/`:

```
2026-04-03T00:00:00Z — Team Clock Beacon

Issued by: koad
Signed by: Keybase (team message immutability)

This is the canonical timestamp for:
- Spec reviews (frozen as-of this clock)
- Incident timestamps (synchronized across entities)
- Trust bond expiration (agreed-upon time source)

Next beacon: 2026-04-04T00:00:00Z
```

Entities read this to establish "current time" for expiration checking, consensus timestamps, etc.

#### 4.2.2 Incident Log

Real-time incident reports, coordinated across entities:

```
2026-04-03T14:23:45Z [INCIDENT] Auth layer degradation detected

Reporter: Argus
Severity: P2 — Service degraded, not unavailable
Status: Investigating

Salus checking: Juno's session keys
Vulcan rolling: Auth caches
Expected resolution: 2026-04-03T15:00:00Z

Updates: Reply to this message in thread
```

Each update is timestamped by Keybase, creating an audit log of the incident.

#### 4.2.3 Deploy Freeze / Merge Freeze

**During security events or deployments:**

```
2026-04-03T09:00:00Z [FREEZE] Merge freeze in effect

Reason: Mercury v1.3.0 security patch deployment
Coordinator: Juno
Scope: koad/vulcan, koad/mercury (other repos may deploy)

Exceptions approved by: koad (sign with saltpack block if needed)

Freeze ends: 2026-04-03T12:00:00Z or when Juno posts [FREEZE LIFTED]
```

Entities check this before running deployment commands.

### 4.3 Reading KV Store

Entities access Keybase team chat via Keybase CLI:

```bash
#!/usr/bin/env bash
# read-team-kv.sh — fetch current team state

TEAM="koad.io"
CHANNEL="koad"

# List recent messages
keybase chat list-messages --team=$TEAM --channel=$CHANNEL | \
  grep -E "Team Clock|Incident|Freeze" | \
  tail -n 1

# Output example:
# 2026-04-03 | Team Clock Beacon: 2026-04-03T00:00:00Z
```

### 4.4 Writing to KV Store

Only koad (and delegated coordinators) post to the team KV store:

```bash
#!/usr/bin/env bash
# koad posts incident report

TEAM="koad.io"
CHANNEL="koad"
MSG="[INCIDENT] Auth layer degradation..."

keybase chat send --team=$TEAM --channel=$CHANNEL "$MSG"
```

---

## 5. Gestation Template Integration

When a new entity is created via `gestate`, the template automatically:

1. Creates `~/.entity/keybase/` directory
2. Fetches entity identity manifest from `/keybase/public/<entity>/identity.keys`
3. Validates manifest is signed by koad
4. Caches manifest locally
5. Stores Keybase username and fingerprint in `.env`

**In gestation template:**

```bash
# ... [after entity directory created]

# Set up Keybase integration
mkdir -p ~/.${ENTITY}/keybase

# Fetch entity identity manifest
echo "Fetching Keybase identity manifest for $ENTITY..."
if keybase fs ls /keybase/public/$ENTITY/ 2>/dev/null; then
  cp /keybase/public/$ENTITY/identity.keys ~/.${ENTITY}/keybase/identity.md
  echo "✓ Identity manifest cached"
else
  echo "⚠ Identity manifest not found — koad must publish first"
fi

# Store Keybase credentials in .env
echo "export KEYBASE_ENTITY=$ENTITY" >> ~/.${ENTITY}/.env
echo "export KEYBASE_USERNAME=$ENTITY" >> ~/.${ENTITY}/.env
```

---

## 6. Security Properties

### 6.1 Cryptographic Guarantees

- **Saltpack signatures** — Ed25519, quantum-resistant only with future PQC signing; current Saltpack is post-quantum-vulnerable (known limitation)
- **Keybase verification** — Signatures verified against device key registered in Keybase, which is tied to social proofs (GitHub, Twitter)
- **KBFS encryption** — `/keybase/private/` paths use client-side encryption, never stored in plaintext on Keybase servers

### 6.2 Trust Assumptions

1. **Keybase remains operational** — if Keybase goes offline, entities cannot verify signatures
   - **Mitigation:** Cache trust bonds and public keys locally (see 2.3)
2. **koad's Keybase device is secure** — if koad's device is compromised, entity authorization can be forged
   - **Mitigation:** Koad uses hardware key if available; regular key rotation
3. **Git history is immutable** — entity specs are committed, not revoked retroactively
   - **Mitigation:** Salus audits for git history rewrites

### 6.3 Non-Goals

- This protocol does NOT replace SSH for entity-to-entity authentication (that's a future spec, auth-protocol.md)
- This protocol does NOT provide end-to-end encryption for entity channels (KBFS provides one layer; additional encryption is future work)

---

## 7. Audit and Compliance

### 7.1 Audit Trail Requirements

All saltpack-signed authorizations must be logged:

```bash
# Entity logs every authorization check
echo "[AUTH:$(date -Iseconds)] Verified: koad/salus#heal-juno (expires 2026-04-10)" >> ~/.${ENTITY}/audit/authorizations.log
```

### 7.2 Compliance Checks

Salus (healer entity) audits:

1. **Unauthorized actions** — did any entity act without a valid authorization?
2. **Expired authorizations** — did any entity use an authorization past expiration?
3. **Scope violations** — did any entity exceed the scope of an authorization?

---

## 8. Implementation Checklist

- [ ] Gestation template updated to set up Keybase for each new entity
- [ ] Koad publishes identity manifests for all existing entities to `/keybase/public/<entity>/`
- [ ] Vesta creates `authorize.sh` template for all entities to use
- [ ] Koad signs initial trust bonds for existing entity pairs (koad↔juno, koad↔vesta, etc.)
- [ ] Vulcan publishes command manifests to `/keybase/public/vulcan/commands.md`
- [ ] Team clock beacon running daily in Keybase team chat
- [ ] Salus audit rules updated to check authorization logs
- [ ] canon.koad.sh synced with Keybase identity manifests (v1.0 spec)
- [ ] All open issues updated with references to this spec

---

*Spec status: canonical (2026-04-03). All entities must implement Saltpack verification by 2026-04-10. Team KV store integration by 2026-04-17. File issues on koad/vesta to propose amendments.*

