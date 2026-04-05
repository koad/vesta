---
status: canonical
id: VESTA-SPEC-024
title: "Entity Public Key Distribution and Discovery"
type: spec
version: 1.0
created: 2026-04-03
promoted: 2026-04-05
owner: vesta
related-issues:
  - koad/vesta#24
description: "Canonical registry for entity public keys, endpoints, and discovery mechanics"
---

# Entity Public Key Distribution and Discovery

## 1. Overview

Entities need reliable, authenticated access to each other's public keys and network endpoints. This spec defines the canonical registry and discovery mechanics for:

- **Signing keys** (Ed25519, used in trust bonds and message signatures)
- **TLS public keys and certificates** (for secure channel establishment)
- **Network endpoints** (CONTROL_ENDPOINT, DATA_ENDPOINT for inter-entity comms)

The registry is single-source-of-truth at `~/.vesta/` and is managed by Vesta. All entities query this registry during startup and when a peer's key is unknown.

---

## 2. Registry Structure

### Root Registry

Vesta maintains the authoritative registry at `~/.vesta/entities/`:

```
~/.vesta/
  └── entities/
      ├── juno/
      │   ├── public.key                (Ed25519 signing public key)
      │   ├── endpoints.env             (CONTROL_ENDPOINT, DATA_ENDPOINT)
      │   ├── cert.pem                  (TLS certificate - Phase 2)
      │   └── metadata.json             (entity info, roles, contact)
      ├── vulcan/
      │   ├── public.key
      │   ├── endpoints.env
      │   ├── cert.pem
      │   └── metadata.json
      ├── salus/
      │   └── ...
      └── {entity}/
          └── ...
```

### Local Caches

Each entity maintains a local cache of known public keys:

```
~/.{entity}/
  └── .cache/
      └── known-entities.json           (cached registry of all entities)
```

---

## 3. Entity Metadata Format

### public.key

Raw Ed25519 public key in PEM format:

```
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEA1234567890ABCDEF...
-----END PUBLIC KEY-----
```

**Sourced from:** Entity's signing identity document (`~/.{entity}/id/signing/public.key`)

### endpoints.env

Shell-sourced environment file with network endpoints:

```bash
# ~/.vesta/entities/{entity}/endpoints.env
ENTITY="{entity}"
CONTROL_ENDPOINT="https://{entity}.internal:8443"
DATA_ENDPOINT="wss://{entity}.internal:8444"
DISCOVERY_TTL=86400  # Cache validity (24 hours)
UPDATED_AT="2026-04-03T12:00:00Z"
```

**Used by:** CLI execution harness to set up inter-entity environment

**Sourced from:** Entity's cascade environment (`~/.{entity}/.env`)

### cert.pem

Entity's TLS certificate (Phase 2 implementation):

```
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAJC1...
-----END CERTIFICATE-----
```

Signed by Vesta's master CA key. See VESTA-SPEC-008 section 3 for details.

### metadata.json

Entity metadata for discovery and status:

```json
{
  "entity": "salus",
  "role": "healer",
  "version": "1.0",
  "status": "active",
  "gestation_date": "2026-03-28T10:00:00Z",
  "public_key_updated": "2026-04-03T12:00:00Z",
  "endpoints_updated": "2026-04-03T12:00:00Z",
  "description": "Incident diagnosis and remediation engine",
  "contact": "koad@kingofalldata.com",
  "dependencies": ["juno", "vulcan"],
  "capabilities": ["diagnose", "heal", "report"],
  "certificate_expires": "2027-04-03T00:00:00Z"
}
```

---

## 4. Discovery Mechanics

### 4.1 Startup: Registry Sync

When an entity starts, it syncs the public key registry from Vesta:

```bash
# During entity startup (VESTA-SPEC-012, section 3)
curl -s https://vesta.internal:8443/registry/entities.json \
  --cert ~/.{entity}/id/ssl/entity-cert.pem \
  --key ~/.{entity}/id/ssl/entity-key.pem \
  > ~/.{entity}/.cache/known-entities.json
```

**Security:** Registry query is authenticated with the entity's own certificate (Phase 2) or with a temporary trust bond (Phase 1).

**Fallback:** If Vesta is unreachable, use locally cached copy. Max cache age: 24 hours.

### 4.2 Runtime: Peer Discovery

When entity A needs to invoke a command on entity B:

1. Check local cache: `~/.{entity}/.cache/known-entities.json`
2. Extract B's `CONTROL_ENDPOINT` from cache
3. Load B's public key from cache for signature verification
4. Verify cache freshness (< 24 hours)
5. If stale, refresh from Vesta registry (fallback to cache if Vesta unreachable)

```bash
# Example: Salus invoking Vulcan
source ~/.{entity}/.cache/known-entities.json
VULCAN_ENDPOINT=$(jq -r '.vulcan.CONTROL_ENDPOINT' ~/.{entity}/.cache/known-entities.json)
VULCAN_PUBKEY=$(jq -r '.vulcan.signing_public_key' ~/.{entity}/.cache/known-entities.json)

curl -X POST "$VULCAN_ENDPOINT/control/invoke" \
  -H "Content-Type: application/json" \
  -d @request.json
```

---

## 5. Key Distribution: Pub → Registry

### 5.1 Gestation: Initial Key Publication

During entity gestation (VESTA-SPEC-014), Vulcan:

1. Generates entity's signing key pair (`~/.{entity}/id/signing/{private,public}.key`)
2. Publishes public key to Vesta: `~/.vesta/entities/{entity}/public.key`
3. Extracts endpoints from entity's `.env`: `CONTROL_ENDPOINT`, `DATA_ENDPOINT`
4. Publishes endpoints to Vesta: `~/.vesta/entities/{entity}/endpoints.env`
5. Creates metadata document: `~/.vesta/entities/{entity}/metadata.json`
6. Commits all to koad/vesta repository

### 5.2 Runtime: Key Rotation

If an entity rotates its signing key:

1. Generate new key pair locally
2. Submit new public key to Vesta via signed request (old key signature proves authority)
3. Vesta updates `~/.vesta/entities/{entity}/public.key`
4. Vesta updates `metadata.json` with `public_key_updated` timestamp
5. Commit to koad/vesta
6. Broadcast invalidation to all entities (clear local cache)

Request format:

```json
{
  "command": "vesta:rotate-signing-key",
  "args": ["{entity}", "{new_public_key}"],
  "timestamp": "2026-04-03T12:00:00Z",
  "request_id": "uuid-v4",
  "signature": "ed25519({old_key}, message)"
}
```

---

## 6. Registry Queries: Entity API

### 6.1 Bulk Registry Download

Endpoint: `GET /registry/entities.json`

Returns compact JSON:

```json
{
  "juno": {
    "CONTROL_ENDPOINT": "https://juno.internal:8443",
    "DATA_ENDPOINT": "wss://juno.internal:8444",
    "signing_public_key": "MCowBQYDK2Vw...",
    "status": "active",
    "updated": "2026-04-03T12:00:00Z"
  },
  "vulcan": { ... },
  ...
}
```

**Cached locally at:** `~/.{entity}/.cache/known-entities.json`

**Max size:** ~50KB (all entities' keys + endpoints)

### 6.2 Single Entity Lookup

Endpoint: `GET /registry/entities/{entity_name}`

Returns single entity's metadata + keys:

```json
{
  "entity": "salus",
  "CONTROL_ENDPOINT": "https://salus.internal:8443",
  "DATA_ENDPOINT": "wss://salus.internal:8444",
  "signing_public_key": "MCowBQYDK2Vw...",
  "status": "active",
  "metadata": { ... }
}
```

**Use case:** Runtime lookup when cache is stale.

---

## 7. Consistency Model

### Eventual Consistency

The registry is **eventually consistent** across entities:

- Vesta is the source of truth
- Changes propagate to all entities' caches within the TTL (24 hours)
- During propagation, entities may see stale keys (mitigated by cache validation)
- Network partitions: entities fall back to local cache (no blocking reads)

### Conflict Resolution

If an entity rotates a key:

1. Vesta receives rotation request, validates signature with **old** public key
2. Vesta updates registry, increments version counter
3. Old entities' caches gradually expire (24-hour TTL)
4. New entities receive updated key on next sync

If two entities claim to rotate the same entity's key:

1. Vesta accepts the first request (timestamp-ordered)
2. Subsequent requests fail (signature won't verify with new key)

---

## 8. Phase 1 vs Phase 2

### Phase 1 (Current: Signing Keys Only)

- ✅ Signing public key registry
- ✅ Endpoint discovery via cascade environment
- ✅ Trust bond authentication
- ❌ TLS certificate PKI (deferred)
- ❌ Automatic certificate management (deferred)

### Phase 2 (Certificate PKI)

Defers to VESTA-SPEC-008 section 3:
- Vesta-signed entity certificates
- Certificate distribution via registry
- Certificate renewal and rotation
- Certificate pinning and revocation

---

## 9. Conformance Criteria

An entity conforms to this spec if:

1. ✅ Publishes Ed25519 public key at `~/.vesta/entities/{entity}/public.key`
2. ✅ Publishes endpoints at `~/.vesta/entities/{entity}/endpoints.env`
3. ✅ Maintains local cache at `~/.{entity}/.cache/known-entities.json`
4. ✅ Syncs registry on startup (VESTA-SPEC-012, section 3)
5. ✅ Validates peer signatures using registry public keys (VESTA-SPEC-008, section 4)
6. ✅ Implements cache TTL and fallback mechanics
7. ✅ Supports key rotation via signed request

**Argus Audit:** Verify registry completeness and consistency. All active entities must appear in `~/.vesta/entities/`. Public keys must match published identities.

**Salus Healing:** If an entity's public key is missing or stale:
1. Request updated key from entity
2. Validate signature with old key (from trust bond)
3. Publish new key to registry
4. Commit change to koad/vesta

---

## 10. Security Considerations

### Threat Model

| Threat | Mitigation |
|--------|-----------|
| Key spoofing | Source of truth at ~/.vesta (Vesta-controlled) |
| Stale keys | Cache TTL + version numbers |
| Man-in-the-middle | Signature verification with trust bond keys |
| Endpoint hijacking | Signed endpoints in registry |
| Registry tampering | Git history + signed commits (Saltpack) |

### Private Key Safety

- All private keys stay in `~/.{entity}/id/` with `.gitignore`
- Public keys are published to Vesta and distributed freely
- Private keys are never uploaded to the registry
- Vesta has no access to entity private keys (entities sign their own rotation requests)

---

## 11. Implementation Checklist

- [ ] Vesta: Create `~/.vesta/entities/` directory structure
- [ ] Vesta: Implement registry API endpoints (`/registry/entities.json`, `/registry/entities/{name}`)
- [ ] Vulcan: Publish entity public keys during gestation (VESTA-SPEC-014)
- [ ] All entities: Implement `~/.{entity}/.cache/known-entities.json` sync on startup
- [ ] All entities: Implement cache TTL validation
- [ ] All entities: Implement key rotation request handling
- [ ] Argus: Add registry consistency checks to audit system
- [ ] Salus: Add registry repair and key validation to healing system

---

## Status

**Canonical** — Phase 1 (signing key distribution) canonized 2026-04-05; closes koad/vesta#24. Phase 2 (TLS certificate PKI) deferred to future iteration.

Blocks implementation of VESTA-SPEC-008 inter-entity comms (Phase 1 control channels).

## References

- VESTA-SPEC-008: Inter-Entity Communications Protocol
- VESTA-SPEC-012: Entity Startup Specification
- VESTA-SPEC-014: Canonical Gestation Protocol
- VESTA-SPEC-015: Keybase/Saltpack Signing Identity Protocol
