---
title: "Signing and Identity Layer — Keybase and Saltpack"
spec-id: VESTA-SPEC-011
status: canonical
created: 2026-04-03
promoted: 2026-04-03
author: Vesta (vesta@kingofalldata.com)
reviewers: [koad, Juno]
related-issues: [koad/vesta#3]
---

# Signing and Identity Layer: Keybase and Saltpack

## Overview

This specification defines the canonical approach for koad:io entities using Keybase and saltpack as the cryptographic foundation for signed identity, trust bonds, and inter-entity communications. It establishes:

- When and how entities acquire Keybase identities
- Saltpack as the standard for signed messages and trust documents
- Key storage, rotation, and compromise recovery
- Keybase integration points (proof chains, team coordination, key distribution)
- Interoperability between entity signing and third-party verification

**Design principle:** Keybase is the *public credential system*; saltpack is the *signing format*. Together they form the trust layer that makes entity identity verifiable without requiring trust in koad's infrastructure alone.

---

## 1. Identity Model

### The entity cryptographic identity

Each entity has an immutable cryptographic identity rooted in its signing key. This key:
- Lives in `~/.entity/id/` (Ed25519, standard for entities)
- Signs all trust bonds, contracts, and authorizations issued by the entity
- Is registered to the entity's Keybase account (if the entity has one)
- Is backed up offline in koad's secure storage
- Is never exported or shared (only the public key is public)

The public key fingerprint is the entity's **canonical identifier** in external contexts.

### Keybase as the public ledger

Keybase serves as the entity's public identity ledger:
- The entity's Keybase account holds the public key in its profile
- The account links proof chains (GitHub, domain ownership, etc.) that establish provenance
- The account is discoverable via `keybase id <entity-name>` or web lookup
- Keybase team memberships establish participation in shared contexts
- KBFS provides an authenticated file channel for sharing between entities

**Trust model:** An entity's Keybase account is the authoritative source for "what is this entity's current public key?" — assuming the account itself has not been compromised.

### Saltpack as the signing format

Saltpack is a NaCl-based message format that:
- Signs messages and documents with the entity's key
- Is human-readable (armor mode produces ASCII output)
- Can be verified by anyone who has the public key
- Is language-agnostic — implementations exist in Go, Rust, Python, JavaScript, bash
- Supports both signing and encryption modes (this spec focuses on signing)

Trust bonds, authorizations, and inter-entity contracts are signed in saltpack armor format and committed to the repo.

---

## 2. Keybase Account Lifecycle

### Account creation criteria

An entity acquires a Keybase account when:

1. **Operational maturity:** Entity has been running for 30+ days with stable commits
2. **Public need:** There is a concrete reason the entity must have public presence (coordination with external teams, published artifacts, etc.)
3. **koad approval:** koad explicitly authorizes the account creation
4. **Custody documented:** Account credentials and recovery protocol are documented before first use

**Exception:** Entities that never need external coordination (Argus, Salus, Sibyl, etc.) do not need Keybase accounts. They can sign documents locally and have koad publish/notarize them.

### Naming convention

```
Entity name: juno
Keybase username: koad-juno
```

The `koad-` prefix is mandatory. It establishes:
- Attribution to the koad:io ecosystem
- Discoverability under a consistent namespace
- Protection against name conflicts with non-koad Keybase users

### Proof chain strategy

When an entity's Keybase account links proofs, link only **active operational proofs:**

| Proof type | When to link | Example |
|---|---|---|
| GitHub account | Entity has its own GitHub account and publishes repos | `github://koad-juno` → koad/juno repo |
| DNS | Entity has domain delegation | `dns://koad.sh/juno` → TXT record with public key |
| Twitter | Entity operates the account actively | Only if the entity posts; don't link unused accounts |
| Website | Entity has a canonical landing page | Only if actively maintained |

**Never link:** Accounts the entity does not actively operate, old accounts, or hypothetical integrations.

### Key registration

The entity's Ed25519 public key is registered to its Keybase account during creation:

```bash
keybase key select  # Select the key for this Keybase account
```

The public key is then:
- Published in the Keybase account's profile
- Queryable via `keybase user --json <entity>`
- Mirrored at `canon.koad.sh/<entity>.keys` as a TXT record backup

### Team membership

Keybase teams are contexts where entities coordinate (internal team, vendor teams, partner orgs).

**Tier 1 — No team memberships** (default)
Entity has a Keybase account but does not join teams. This is appropriate when the entity needs identity for signing and public presence, but not for collaborative KBFS or team chat.

**Tier 2 — Internal team membership**
Entity joins the koad:io internal team (`koad:io-core`). Requirements:
- 30+ days stable operation
- koad explicitly approves
- No active security incidents

**Tier 3 — External team membership**
Entity joins external Keybase teams (vendor coordination, partner orgs). Requirements:
- All Tier 2 requirements met
- Explicit request from the external team
- koad reviews and approves each external team
- Compromise impact assessment documented

---

## 3. Saltpack Signing Protocol

### Message format

A saltpack-signed message consists of:
1. **Armor header:** `BEGIN KEYBASE SALTPACK SIGNED MESSAGE`
2. **Body:** The message content (may include metadata, JSON, markdown, etc.)
3. **Signature block:** The Ed25519 signature and signing key reference
4. **Armor footer:** `END KEYBASE SALTPACK SIGNED MESSAGE`

Example (trust bond):

```
BEGIN KEYBASE SALTPACK SIGNED MESSAGE.
kXb7VcMN5Z3sVqVf1Zf ... [base64-encoded signed message]
END KEYBASE SALTPACK SIGNED MESSAGE.
```

### Signing documents

All trust bonds, authorizations, and entity contracts must be signed:

```bash
# Entity signs a trust bond
cat > trust-bond.txt <<EOF
Date: 2026-04-03
Signer: Vesta (vesta@kingofalldata.com)
Recipient: Vulcan
Authorization: Repository push access to koad/vulcan

Vulcan is authorized to push commits to koad/vulcan as of 2026-04-03.
This authorization is revocable by Vesta or koad.
EOF

keybase sign --saltpack < trust-bond.txt > trust-bond.signed.txt
```

The signed document is then committed to the repo at `trust/bonds/<recipient>-<date>.signed.txt`.

### Verification workflow

Anyone with the entity's public key can verify a signed document:

```bash
# Retrieve entity's public key from Keybase
keybase user --json juno | jq '.them.public_keys.primary.bundle'

# Or from the TXT record
dig canon.koad.sh TXT @8.8.8.8 | grep juno

# Verify the signed document
keybase verify --saltpack < trust-bond.signed.txt
```

If verification succeeds, the message is cryptographically proven to be from the entity. If it fails, the message has been modified or is not signed by the claimed entity.

### Keyring architecture

Each entity maintains a local `~/.entity/id/keyring.asc` containing:
- Its own public key (for reference and backup)
- Public keys of all other entities in the system
- koad's root keys

```bash
~/.entity/id/
├── keyring.asc          # All public keys (for verification)
├── signing-key.private  # This entity's signing key (NEVER EXPORT)
└── signing-key.public   # This entity's public key (committed to repo)
```

The `keyring.asc` is updated whenever a new entity joins the system or when an entity rotates its key.

---

## 4. Trust Bonds and Authorizations

### Trust bond format

A trust bond is a signed statement from one entity (Authorizer) to another (Recipient) that specifies a permission, responsibility, or delegation.

**File structure:**

```
~/.vesta/trust/bonds/<recipient>-<date>-<scope>.signed.txt

Example:
~/.vesta/trust/bonds/vulcan-2026-04-03-repo-push.signed.txt
```

**Content:**

```
---
authorizer: vesta
recipient: vulcan
date: 2026-04-03
scope: repository-push-access
expiry: 2026-07-03
revocable-by: [vesta, koad]
---

Vulcan is authorized to push commits to koad/vulcan.

This authorization:
- Applies to the main branch and all feature branches
- Does not grant ability to merge pull requests
- Does not grant ability to delete branches
- Applies until 2026-07-03 or until revoked by Vesta or koad
- Is evidenced by the signature of this document

Signed by: Vesta
Signing key: [fingerprint]
```

Then signed:

```bash
keybase sign --saltpack < bond-draft.txt > vulcan-2026-04-03-repo-push.signed.txt
git add trust/bonds/
git commit -m "auth: Vulcan granted push access to koad/vulcan until 2026-07-03"
```

### Inter-entity authorization chain

When entity A needs to authorize entity B, and the authorization is important enough to be auditable:

1. **Authorizer (A) drafts** a bond specifying the permission
2. **Authorizer (A) signs it** with its key
3. **Signed bond is committed** to A's repo
4. **Recipient (B) verifies** by pulling the bond and running `keybase verify`
5. **Recipient (B) documents** the authorization in its own logs

This creates an auditable chain: anyone can verify that A signed the bond by checking against A's public key.

### Revocation

To revoke an authorization:

```bash
# Create a revocation document
cat > revocation.txt <<EOF
---
authorizer: vesta
revokes: vulcan-2026-04-03-repo-push.signed.txt
reason: Demonstration of revocation protocol
date: 2026-04-10
---

The authorization in vulcan-2026-04-03-repo-push.signed.txt is hereby revoked,
effective immediately.
EOF

keybase sign --saltpack < revocation.txt > vulcan-revoked-2026-04-10.signed.txt
git add trust/bonds/
git commit -m "auth: Revoke Vulcan's push access (demo)"
```

Revocations are advisory — the actual GitHub/repo-level access is controlled separately. But the signed revocation creates an auditable record.

---

## 5. KBFS Layout and Directory Structure

### Entity KBFS namespace

Each entity with a Keybase account has three KBFS namespaces:

```
/keybase/public/<entity-name>/        ← Public artifacts, publications
/keybase/private/koad/<entity-name>/  ← Private entity↔koad channel
/keybase/team/koad.io/<entity-name>/  ← Internal team coordination (if applicable)
```

### Public namespace: `/keybase/public/koad-<entity>/`

The public namespace is used for:
- **Published trust bonds** — readable by external parties
- **Public keys** — backup source for entity public key
- **Release notes** — entity's announcements
- **Service status** — entity health and availability

**File structure:**
```
/keybase/public/koad-juno/
├── keys/
│   └── signing-key.pub              # Juno's public key (backup)
├── bonds/
│   ├── koad-2026-04-01-delegation.signed.txt
│   └── vesta-2026-04-02-channel.signed.txt
├── README.md                         # Entity description
└── STATUS.md                         # Current operational status
```

### Private namespace: `/keybase/private/koad/<entity>/`

The private namespace is a secure channel between koad and the entity:
- Created when entity reaches Tier 2 (team membership)
- Readable only by koad and the entity
- Used for sensitive coordination, incident reports, key rotation notifications

**File structure:**
```
/keybase/private/koad/juno/
├── incidents/                        # Incident reports (read-only for koad)
├── key-rotations/                    # Key change notifications
├── coordination/                      # Shared task state during incidents
└── logs/                             # Archive of past incidents
```

### Team namespace: `/keybase/team/koad.io/<entity>/`

The team namespace is used only for entities in Tier 2 or above:
- Shared coordination space visible to all koad:io entities
- Read-write by default
- Used for operational dashboards, shared status, incident tracking

**File structure:**
```
/keybase/team/koad.io/juno/
├── status.json                       # Current status (heart beat)
├── incidents/
│   └── 2026-04-01-db-timeout.md     # Active incidents
├── deployments/
│   └── main-2026-04-03.log          # Deployment logs
└── metrics/                          # Operational metrics
```

### Access control and trust

KBFS namespaces enforce access control through Keybase:
- **Public:** Readable by anyone on the internet
- **Private:** Readable only by koad and the entity (encrypted at rest)
- **Team:** Readable by team members only (encrypted at rest)

This provides confidentiality without requiring a separate access control system.

---

## 6. Keybase Team KV Store Protocol

### Overview

Keybase team chat rooms support key-value storage accessible via `keybase kvstore` CLI. This is used for shared operational state that must be available to multiple entities but does not require versioning or git history.

### KV store design goals

- **Eventual consistency:** Updates propagate within seconds
- **No version history:** Overwrites are final (use git for historical data)
- **Atomic per-key:** Each key is atomically updated
- **Namespace isolation:** Each team has its own KV store

### Store layout

Each team's KV store is organized by entity and concern:

```
koad:io-core/kvstore/

Global operational state:
  koad/environment              ← Current environment (prod, staging, test)
  koad/deployment-in-progress   ← Deployment lock (boolean)
  koad/alert-level              ← System alert level (normal, warning, critical)

Per-entity state:
  juno/status                   ← Juno's operational status (heartbeat)
  juno/last-update              ← Timestamp of last status update
  vulcan/status                 ← Vulcan's operational status
  vulcan/last-update            ← Timestamp of last update

Incident coordination:
  incidents/active              ← Count of active incidents
  incidents/on-call             ← Current on-call entity
  incidents/last-updated        ← Timestamp of last incident update
```

### Writing to the KV store

**Set a value:**
```bash
keybase kvstore set koad:io-core juno/status "running"
keybase kvstore set koad:io-core juno/last-update "2026-04-03T14:22:00Z"
```

**Get a value:**
```bash
keybase kvstore get koad:io-core juno/status
```

### Implementation: Entity heartbeat

Entities in Tier 2+ should publish a heartbeat every 5 minutes:

```bash
#!/bin/bash
# ~/.entity/commands/heartbeat
TIMESTAMP=$(date -Iseconds)
STATUS="running"  # or "degraded", "offline", etc.

keybase kvstore set koad:io-core "$ENTITY/status" "$STATUS"
keybase kvstore set koad:io-core "$ENTITY/last-update" "$TIMESTAMP"
```

Scheduled via cron:
```bash
*/5 * * * * ~/.entity/commands/heartbeat
```

### Design: No strong consistency guarantee

The KV store is **not** a database — updates may take seconds to propagate and there is no strong consistency guarantee. Therefore:

- **Do not use for:** Critical decisions, access control, secrets storage
- **Do use for:** Status indicators, operational dashboards, incident coordination
- **Design for eventual consistency:** Assume updates lag by 30 seconds

If strong consistency is required, commit to git instead.

### Privacy and access

KV store values in a **private team** are encrypted at rest and not accessible to non-members. Values are suitable for:
- Entity status and health
- Incident descriptions
- Deployment progress

Do not store:
- Private keys
- Database credentials
- Secrets of any kind

---

## 7. Key Rotation and Compromise

### Rotation schedule

| Key type | Rotation trigger | Recommended interval |
|---|---|---|
| Entity signing key (Ed25519) | Suspected compromise | Every 2 years |
| Keybase MFA TOTP secret | Device change | On device change |
| Signing key passphrase | Suspected compromise | On demand |

Keys are **not rotated speculatively.** Rotation is triggered by:
- Suspected compromise
- Hardware end-of-life
- Explicit request from the entity or koad

### Key rotation procedure

When an entity's signing key must be rotated:

1. **Generate new key:**
   ```bash
   ssh-keygen -t ed25519 -C "<entity>@kingofalldata.com" -f ~/.entity/id/signing-key-new
   ```

2. **Create signed transition document** (signed by BOTH old and new key):
   ```
   Entity: <entity>
   Old key: [fingerprint]
   New key: [fingerprint]
   Reason: [reason for rotation]
   Date: [date]
   
   Effective [date], <entity>'s canonical signing key is transitioning
   from the old key to the new key. All new documents signed by <entity>
   should be verified against the new key.
   
   Old bonds remain valid; recipients may verify against either key
   during the transition window (60 days).
   ```

3. **Sign with old key, append signature from new key**
4. **Commit to `trust/keys/rotations/`**
5. **Update Keybase account** to reflect new key
6. **Update `canon.koad.sh/<entity>.keys`** DNS record

Transition window: **60 days.** After 60 days, only the new key is considered canonical.

### Compromise recovery

If an entity's signing key is compromised:

1. **Immediate:** Revoke the compromised key (Keybase account, DNS record)
2. **Within 1 hour:** Generate new signing key, update Keybase account
3. **Within 4 hours:** Create transition document signed by both keys
4. **Within 24 hours:** Review all signatures made with the compromised key during the suspected compromise window
5. **Within 48 hours:** File incident report at `~/.entity/LOGS/<date>-key-compromise.md`

The compromised key is revoked but not deleted from history. Old bonds signed by the compromised key remain in the repo but are flagged as "potentially compromised."

---

## 8. Implementation: Saltpack Tooling

### Command-line interface

The canonical command for entity signing is:

```bash
# Sign a file
keybase sign --saltpack < document.txt > document.signed.txt

# Verify a signature
keybase verify --saltpack < document.signed.txt

# Encrypt (future use)
keybase encrypt --saltpack <recipient> < plaintext.txt
```

### Integration into CI/CD

Entity repos should verify trust bonds in CI:

```bash
# .github/workflows/verify-bonds.yml
- name: Verify all trust bonds
  run: |
    for bond in trust/bonds/*.signed.txt; do
      keybase verify --saltpack < "$bond" || exit 1
    done
```

This ensures that corrupted or forged bonds are caught before they affect downstream systems.

### Batch verification

To verify all bonds in a directory:

```bash
#!/bin/bash
for bond in trust/bonds/*.signed.txt; do
  echo "Verifying $bond..."
  if keybase verify --saltpack < "$bond"; then
    echo "  ✓ Valid"
  else
    echo "  ✗ Invalid"
    exit 1
  fi
done
```

---

## 9. Interoperability and Fallback

### Keybase unavailability

If Keybase is temporarily unavailable (outage, network issue), entities can still verify signatures using:

1. **Cached public keys** from the local keyring
2. **DNS TXT records** at `canon.koad.sh/<entity>.keys`
3. **Published keys** in each entity's repo at `~/.entity/id/signing-key.public`

This creates redundancy: Keybase is the primary source, but signatures can be verified offline using cached data.

### Non-Keybase verification

External parties without Keybase access can verify an entity signature if they have:
- The entity's public key (from DNS, the entity's repo, or a trust bond signed by koad)
- A saltpack implementation (Keybase CLI, Go, Rust, Python, etc.)

```bash
# Example: Verify using only the public key file
saltpack verify --key entity-public.key < document.signed.txt
```

### Audit trail

Every signed document that affects the system is committed to the repo. This creates an immutable audit trail:
- Who signed it (the key fingerprint)
- When (git timestamp)
- What it authorizes (the content)
- Any revocations (in `trust/bonds/revocations/`)

---

## 10. Canonical Deployment

### Current state

As of 2026-04-03:
- Vesta's signing key is Ed25519 at `~/.vesta/id/signing-key.private`
- Vesta's public key is published at `canon.koad.sh/vesta.keys` (DNS TXT)
- Vesta's Keybase account is `koad-vesta` (pending account creation per entity-public-accounts spec)
- All trust bonds are stored in `~/.vesta/trust/bonds/` and committed

### Rollout order

1. **Phase 1 (now):** Vesta and koad have signing keys and use saltpack for trust bonds
2. **Phase 2 (30 days):** All operational entities (Juno, Vulcan, Mercury) have signing keys and Keybase accounts
3. **Phase 3 (60 days):** All entities use saltpack for inter-entity authorizations
4. **Phase 4 (ongoing):** External parties can verify entity signatures via Keybase or DNS

### Entity signing key checklist

For each entity, before enabling saltpack signing:

- [ ] Ed25519 key generated at `~/.entity/id/signing-key.private`
- [ ] Public key exported and committed to `~/.entity/id/signing-key.public`
- [ ] Public key backed up offline in koad's secure storage
- [ ] Public key registered to Keybase account (if entity has one)
- [ ] Public key published at `canon.koad.sh/<entity>.keys` (DNS TXT)
- [ ] Entity has been briefed on signing protocol and revocation procedure
- [ ] First trust bond signed and committed as a test

---

## 11. Security Considerations

### Threat model

This spec assumes:
- Keybase infrastructure is not compromised
- DNS is not under active attack (or DNS is read-only for critical records)
- Entity machines are not continuously compromised
- Koad holds offline backups of all entity public keys

### Key storage security

Entity signing keys are stored on disk in plaintext (`~/.entity/id/`). Security depends on:
- Disk encryption (LUKS, FileVault, etc.)
- SSH access controls (no shared accounts, public key auth only)
- koad's machine isolation (entities run on separate harnesses)

This is acceptable because Keybase, by design, expects the entity to have disk-resident keys that the daemon can access to sign messages.

### Compromise scope

If an entity's signing key is compromised:
- **All future documents** signed by that key are untrusted
- **Historical documents** remain valid (the signature itself is not invalidated)
- **Authorizations** granted to that entity by others remain valid (the entity is not deauthorized by its own key compromise)

Compromise of an entity's key does NOT automatically revoke all its permissions. Each permission and authorization has separate revocation mechanisms.

### Signature verification burden

External parties verifying a signature must have the entity's public key. Provide multiple sources:
- Keybase account (if entity has one)
- DNS TXT record
- Published in the entity's repo
- Notarized by koad (if entity is new or has no Keybase account)

---

*Spec status: canonical (promoted 2026-04-03). All entities must align to this specification. File issues on koad/vesta to propose amendments to the canonical spec.*
