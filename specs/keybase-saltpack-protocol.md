---
status: canonical
issue: koad/vesta#3
version: 1.0
author: Vesta
date: 2026-04-03
---

# Keybase & Saltpack: koad:io Signing and Identity Layer

## Overview

Keybase with Saltpack is the canonical signing and identity layer for the koad:io ecosystem. It provides verifiable authorization, encrypted inter-entity channels, and team-based shared state without requiring a central server.

**Why Keybase:**
- Saltpack signing is cryptographically verifiable across the network
- Social identity proofs (GitHub, Twitter) make entities recognizable
- KBFS provides transparent encrypted storage and channels
- Team team rooms support key-value storage for shared state
- Every entity can verify signatures locally without an API call

**Key assumption:** koad is logged into Keybase as `koad` with social proofs configured. Each entity operates under koad's identity namespace.

---

## 1. Saltpack Authorization Protocol

### Use Case
An entity needs to act on koad's authorization without manual intervention. Example: Vesta wants to authorize Vulcan to merge a release PR. The authorization must be:
- Signed by koad (cryptographically verifiable)
- Timestamped and scoped
- Verifiable offline by any entity
- Revocable (via explicit revocation block)

### Protocol

#### 1.1 Signing an Authorization

koad uses `keybase sign` to create a saltpack-signed authorization block:

```bash
koad@machine$ cat > /tmp/auth.txt << 'EOF'
entity: vulcan
scope: release-merge
target: koad/vulcan#PR-42
reason: Release v2.1.0 cut
expires: 2026-04-10T00:00:00Z
EOF

koad@machine$ keybase sign < /tmp/auth.txt > /tmp/auth.sig
```

Output (example):
```
BEGIN KEYBASE SALTPACK SIGNED MESSAGE.
hQEuA1vDxWCLEBi/...
[base64 saltpack block]
END KEYBASE SALTPACK SIGNED MESSAGE.
```

#### 1.2 Publishing the Authorization

koad posts the signed block as an issue comment on the relevant repo. Example: comment on koad/vulcan#PR-42:

```
## Authorization: Merge Release v2.1.0

koad authorizes Vulcan to merge this PR. Verify with:

\`\`\`
echo '[signed block below]' | keybase verify
\`\`\`

BEGIN KEYBASE SALTPACK SIGNED MESSAGE.
hQEuA1vDxWCLEBi/...
[full block]
END KEYBASE SALTPACK SIGNED MESSAGE.
```

#### 1.3 Verifying an Authorization

An entity receiving an authorization block verifies it locally:

```bash
vulcan@machine$ echo "BEGIN KEYBASE SALTPACK SIGNED MESSAGE.
hQEuA1vDxWCLEBi/...
END KEYBASE SALTPACK SIGNED MESSAGE." | keybase verify

Signed by: koad (koad)
On: 2026-04-03T15:30:00Z
```

The entity parses the plaintext content and checks:
1. Signature is valid (keybase verify succeeds)
2. Signer is `koad` (or a delegated entity with appropriate trust bond)
3. Scope matches the entity's permission set
4. Expiry hasn't passed
5. No matching revocation block exists

#### 1.4 Revocation

koad revokes an authorization by posting a revocation block (same comment thread):

```
## Revocation: Cancel Release Authorization

koad revokes the above authorization due to [reason].

BEGIN KEYBASE SALTPACK SIGNED MESSAGE.
hQEuA1vDxWCLEBj/...
revoke: [hash of original authorization]
reason: blocked by security audit
END KEYBASE SALTPACK SIGNED MESSAGE.
```

### Authorization Format (Plain Text Content)

The plaintext block MUST contain:

```
entity: <target-entity-name>
scope: <permission-scope>
target: <repo/owner#issue-or-pr>
reason: <human-readable justification>
expires: <ISO8601-timestamp>
[optional: delegated-from: <entity>]
```

Example scopes:
- `release-merge` — authority to merge release PR
- `hotfix-deploy` — authority to deploy a hotfix
- `spec-publish` — authority to promote a spec from draft to canonical
- `key-rotation` — authority to rotate entity keys
- `command-deploy` — authority to deploy a new command

### Trust Chain

```
koad (root, signs all authorizations)
  └─ delegated entity (if delegated-from field present)
       └─ target entity (receives authorization)
```

An entity can delegate its authority to another entity by creating a new saltpack block:
```
entity: <target>
scope: <scope>
delegated-from: <delegating-entity>
[same fields as above]
```

The target entity verifies both the original authorization and the delegation chain.

---

## 2. KBFS Layout

### Directory Structure

Each entity has a reserved namespace in Keybase:

```
/keybase/public/koad/
  ├── entity-list.txt          ← canonical list of active entities
  └── entity/
      ├── aegis/
      ├── argus/
      ├── janus/
      ├── juno/
      ├── muse/
      ├── salus/
      ├── sibyl/
      ├── vesta/
      ├── veritas/
      └── vulcan/

/keybase/private/koad/
  ├── juno/                    ← juno↔koad private channel
  ├── vesta/                   ← vesta↔koad private channel
  └── [other entities]/        ← entity↔koad private channels

/keybase/team/koad.io/
  ├── shared-state/            ← team KV store (shared state)
  └── audit-log/               ← immutable team activity log
```

### Per-Entity Directory Structure

Each entity's `keybase/` directory (locally, in `~/.entity/keybase/`) mirrors KBFS:

```
~/.entity/keybase/
├── public/                    ← symlink to /keybase/public/koad/entity/entityname/
├── private/                   ← symlink to /keybase/private/koad/entityname/
├── team/                      ← symlink to /keybase/team/koad.io/
└── cache/
    ├── last-sync.txt          ← timestamp of last KBFS sync
    └── entity-list.txt        ← cached copy of public/entity-list.txt
```

### Usage: Public Namespace

**File:** `/keybase/public/koad/entity/vesta/identity.txt`

Contains Vesta's public identity:
```
entity: vesta
keybase-user: koad
device-key: [Ed25519 public key]
keys-endpoint: https://canon.koad.sh/vesta.keys
identity-proofs: [GitHub: koad, Twitter: koad_io]
created: 2026-01-15
```

Any entity can read this to verify Vesta's device key.

### Usage: Private Namespace

**File:** `/keybase/private/koad/vesta/channel.md`

Private channel between koad and Vesta. Used for:
- Encrypted coordination messages
- Shared secrets (not in git)
- Emergency revocation of device keys
- Audit trail of delegations

Example:
```
# koad ↔ Vesta Private Channel

2026-04-01 15:30 - koad: Key rotation scheduled for Vulcan, coordinate with Argus
2026-04-01 16:00 - vesta: Acknowledged, will monitor for drift during rotation
```

### Usage: Team Shared State

**File:** `/keybase/team/koad.io/shared-state/entity-status.kv`

Team key-value store for read-only, team-visible state:
```
vesta/last-sync: 2026-04-03T16:00:00Z
vesta/spec-count: 42
vulcan/build-status: passing
janus/monitor-health: nominal
```

Each entity periodically writes its own status. Entities read the full KV store to understand team health.

---

## 3. Keybase as Entity Identity Layer

### Entity Identity Model

Each entity has:

1. **Keybase User:** Operates under koad's account (no separate Keybase accounts)
2. **Device Key:** Ed25519 key registered with Keybase, tied to koad's device
3. **Canonical Keys File:** Published at `https://canon.koad.sh/<entity>.keys`
4. **Trust Bond:** Signed delegation from koad granting the entity its authority

### Why No Separate Keybase Accounts

Maintaining separate Keybase accounts per entity is operationally expensive (more accounts to manage, device keys to rotate, etc.). Instead:

- **One root identity:** koad has one Keybase account with full social proofs
- **Many device keys:** Each entity has its own Ed25519 device key, registered under koad's account
- **Delegation via trust bond:** koad signs a trust bond document that formally delegates authority to each entity
- **Verification:** Other entities verify the trust bond to recognize an entity as legitimate

### Trust Bond Format

A trust bond is a signed document (Saltpack block) issued by koad:

```
entity-name: vesta
entity-role: platform-steward
entity-key: [Ed25519 public key]
scopes: ["spec-authoring", "command-definition", "entity-onboarding"]
issued: 2026-01-15T00:00:00Z
expires: 2027-01-15T00:00:00Z
revocation-url: https://canon.koad.sh/trust-bonds/revoked.txt
```

Signed with koad's Keybase device key, verifiable with `keybase verify`.

### The Keys File: `canon.koad.sh/<entity>.keys`

Published at a canonical HTTPS endpoint (not in git):

```
# vesta.keys — canonical public key material for Vesta

## Identity
keybase-user: koad
keybase-device-key: [Ed25519 public in base64]

## Signing Keys (for direct verification without Keybase)
rsa-public: [RSA public key for backward compat with older systems]
ecdsa-public: [ECDSA public key]
ed25519-public: [Ed25519 public key — primary]

## Trust Chain
trust-bond-url: https://canon.koad.sh/trust-bonds/vesta.bond
trust-bond-hash: [sha256 of canonical trust bond]

## Revocation
revocation-list-url: https://canon.koad.sh/revocations.txt

## Metadata
last-updated: 2026-04-03T16:00:00Z
canonical-hostname: canon.koad.sh
```

This allows entities to verify keys without relying on git history or Keybase directly.

---

## 4. KV Store Protocol

### Use Case

Team-visible state that's read-only at runtime but needs periodic updates. Examples:
- Entity health status (last sync, error count, etc.)
- Shared config values (protocol version, canonical endpoints)
- Audit summaries (PRs merged, specs published)

### Storage Location

**File:** `/keybase/team/koad.io/shared-state/` (directory)

Each key is a simple text file following naming convention: `<entity>/<key>.txt`

Example:
```
/keybase/team/koad.io/shared-state/vesta/last-sync.txt
/keybase/team/koad.io/shared-state/vesta/spec-count.txt
/keybase/team/koad.io/shared-state/vulcan/build-status.txt
```

### Write Protocol

Only an entity can write to its own namespace:

1. Entity reads `/keybase/team/koad.io/shared-state/`
2. Entity updates `<entity>/<key>.txt` with new value
3. Keybase team filesystem automatically syncs (seconds)
4. Other entities see the update on next read

Example (Vesta updates its sync time):

```bash
vesta@machine$ echo "2026-04-03T16:30:00Z" > \
  /keybase/team/koad.io/shared-state/vesta/last-sync.txt

vesta@machine$ # (next, Argus will see the update when it reads)
argus@machine$ cat /keybase/team/koad.io/shared-state/vesta/last-sync.txt
2026-04-03T16:30:00Z
```

### Read Protocol

Any entity can read the full shared-state directory:

```bash
entity@machine$ ls /keybase/team/koad.io/shared-state/
vesta/
vulcan/
janus/
...

entity@machine$ cat /keybase/team/koad.io/shared-state/vulcan/build-status.txt
passing
```

### Key Naming Convention

- **Status keys:** `<entity>/status.txt` — overall health (ok, degraded, critical)
- **Timestamp keys:** `<entity>/last-<event>.txt` — ISO8601 timestamp of last occurrence
- **Counter keys:** `<entity>/count-<metric>.txt` — integer count
- **Config keys:** `<entity>/config-<param>.txt` — shared configuration

### Audit Log

**File:** `/keybase/team/koad.io/audit-log/` (append-only)

Team members write immutable audit entries. Each entity appends a timestamped entry:

```
2026-04-03T16:15:00Z vesta: deployed spec-keybase-saltpack-protocol v1.0
2026-04-03T16:20:00Z vulcan: merged koad/vulcan#PR-89 (feature/auth-guards)
2026-04-03T16:25:00Z janus: flagged issue in koad/vulcan (protocol violation)
```

Entries are appended via cron job or session-end hook. The file grows monotonically — never edited or deleted.

---

## Implementation Notes

### Session Start

When Vesta (or any entity) starts a session:

1. Check Keybase login status: `keybase status`
2. Sync KBFS: Navigate to `/keybase/` to trigger automatic sync
3. Read `/keybase/public/koad/entity-list.txt` to discover active entities
4. Read `/keybase/team/koad.io/shared-state/` to get team health snapshot

### Verification Workflow

When an entity receives a signed authorization:

```bash
entity@machine$ cat signed_auth.txt | keybase verify
# Check output for:
# - Signer is koad
# - Signature is valid
# - Parse plaintext: scope, target, expires
# - Check local revocation list: curl https://canon.koad.sh/revocations.txt
# - Compare expires timestamp with current time
# - Act if all checks pass
```

### Offline Operation

All verification is local — entities can verify signatures offline. Keybase just provides:
- Cryptographic key material (from `/keybase/public/`)
- Encrypted channels (KBFS)
- Audit trail (team chat/KV store)

---

## Deprecations & Migrations

None at version 1.0. This is the canonical protocol for signing and identity.

If a future version is needed, a migration document will be posted with deprecation timeline and upgrade path.

---

## References

- **Implementation:** `~/.koad-io/commands/gestate/command.sh` (already uses Saltpack at bottom)
- **Trust bonds:** `~/.vesta/trust/bonds/` (where delegations are stored)
- **Keys directory:** `~/.vesta/id/` (entity's local key material)
- **Related spec:** koad/vesta#2 (signing protocol — this spec fulfills it)
- **Keybase docs:** https://keybase.io/docs/ (team KV store, KBFS, saltpack)

---

## Sign-Off

This specification is canonical as of 2026-04-03.

Vesta — Platform Keeper
