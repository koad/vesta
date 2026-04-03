---
status: draft
id: VESTA-SPEC-014
title: "Kingdom Peer Connectivity Protocol — Daemon Peer Discovery, Trust Rings, and Portal Integration"
type: spec
version: 1.0
date: 2026-04-03
owner: vesta
description: "Canonical protocol for daemon-to-daemon peer connections, trust ring formation via sponsorship, and kingofalldata.com portal integration"
related-specs:
  - VESTA-SPEC-005 (Cascade Environment)
  - VESTA-SPEC-007 (Trust Bond Protocol)
  - VESTA-SPEC-009 (Daemon Specification)
---

# VESTA-SPEC-014: Kingdom Peer Connectivity Protocol

**Authority:** Vesta (platform stewardship). This spec defines how daemons discover and connect to peer kingdoms, form trust rings through sponsorship relationships, and integrate with the kingofalldata.com portal.

**Scope:** Daemon peer discovery, sponsorship-gated trust rings, inter-daemon data flow ("piping"), portal namespace endpoints, ring tier definitions, and cryptographic authentication of peer connections.

**Consumers:**
- Vulcan (daemon deployment and peer routing)
- Juno (kingdom orchestration and sponsorship authority)
- Argus (peer topology diagnostics)
- Salus (peer health monitoring)
- End users (portal access to kingdom data)

**Status:** Draft. This spec establishes the foundation for multi-machine kingdom networks. Implementation begins after Juno review.

---

## 1. Kingdom and Peer Network Architecture

### 1.1 Design Principles

1. **Sponsorship-gated**: Peer connections require explicit trust bonds and sponsorship relationships; no implicit trust
2. **Decentralized discovery**: Peers discover each other via sponsor chain, not a central registry
3. **Asymmetric access**: The sponsoring entity (sponsor) always has authority over the peer relationship; tier determines what data flows
4. **Portal-connected**: Each daemon exposes its state via kingofalldata.com namespace endpoints; portal is read-only view of live daemon
5. **TLS-authenticated**: All peer connections use mutual TLS with certificate pinning
6. **Ring-structured**: Sponsorship levels create nested trust rings; higher tiers have visibility into lower tiers

### 1.2 Terminology

| Term | Meaning |
|------|---------|
| **Kingdom** | A koad:io installation (typically one daemon per machine) |
| **Peer** | Another daemon that this daemon has a trust relationship with |
| **Sponsor** | The entity that created the trust bond and invited a peer to the ring |
| **Trust Ring** | Set of daemons connected by sponsorship relationships at the same tier |
| **Ring Tier** | Sponsorship level (free, basic, pro, enterprise) that determines peer visibility and data access |
| **Portal** | kingofalldata.com web interface; provides read-only view of kingdom state via daemon endpoints |
| **Peer Endpoint** | TCP/TLS port on daemon that accepts peer connections (distinct from entity endpoints) |

### 1.3 Trust Ring Model

```
Koad (root sponsor)
  └── Juno (authorized-agent bond)
        ├── Free Tier Ring
        │     └── User1 daemon (sponsor: koad)
        │     └── User2 daemon (sponsor: koad)
        │
        ├── Basic Tier Ring
        │     └── Company1 daemon (sponsor: juno)
        │     └── Company2 daemon (sponsor: juno)
        │     └── [can see Free tier via Juno, but not each other]
        │
        └── Enterprise Tier Ring
              └── BigCorp daemon (sponsor: juno, direct)
```

Key property: A peer only connects to daemons in its tier **and daemons one tier above** (sponsored by its sponsor). Horizontal peer-to-peer connections within the same tier do not exist; the sponsoring entity is the hub.

---

## 2. Sponsorship and Trust Bonds

### 2.1 Sponsorship Document

A sponsorship is a trust bond (VESTA-SPEC-007) with type `sponsor` that grants peer connectivity rights.

```yaml
---
type: sponsor
from: juno (juno@kingofalldata.com)
to: user1@example.com (User1 daemon)
status: ACTIVE
visibility: private
created: 2026-04-03
renewal: Annual (2027-04-03)
tier: free | basic | pro | enterprise
endpoints:
  - hostname: user1.koad.sh
    port: 6379
    tls_cert_sha256: abc123...
limits:
  max_data_per_day_mb: 100
  max_peers: 10
---
```

### Required Sponsorship Fields

- **type**: Must be `sponsor`
- **from**: The sponsoring entity
- **to**: The sponsored kingdom (typically a domain or user identity)
- **tier**: One of `free`, `basic`, `pro`, `enterprise`
- **endpoints**: Array of daemon peer endpoints this kingdom exposes
  - `hostname`: FQDN or IP of the daemon peer port
  - `port`: TCP port for peer connections (typically 6379)
  - `tls_cert_sha256`: SHA256 hash of the daemon's peer certificate (for pinning)
- **limits**: Rate limits and capacity constraints for this tier

### 2.2 Tier Definitions

| Tier | Max Peers | Data Per Day | Feature Access | Visibility | Cost |
|------|-----------|--------------|-----------------|------------|------|
| **free** | 5 | 10 MB | Basic dashboards | Own kingdom only | $0 |
| **basic** | 20 | 100 MB | Worker metrics, log access | Self + sponsor (Juno) | $50/mo |
| **pro** | 100 | 1 GB | Full data access, webhooks | Self + sponsor + peer ring | $200/mo |
| **enterprise** | Unlimited | Unlimited | Custom integrations, SLA | Full visibility, can sponsor others | Custom |

### 2.3 Revoking Sponsorship

The sponsoring entity can revoke peer connectivity immediately by setting bond status to `REVOKED`:

```yaml
status: REVOKED — revoked by juno via Keybase 2026-04-03 12:34:56Z
```

Effect: All peer connections from that kingdom are dropped within 5 minutes. Outbound requests from the revoked kingdom are rejected.

---

## 3. Daemon Peer Discovery

### 3.1 Discovery Mechanism

Each daemon has a peer discovery file: `~/.{entity}/peers.json`

```json
{
  "version": "1.0",
  "sponsor": "juno",
  "tier": "basic",
  "my_endpoint": {
    "hostname": "user1.koad.sh",
    "port": 6379,
    "tls_cert_sha256": "abc123..."
  },
  "sponsors": [
    {
      "entity": "juno",
      "hostname": "juno.koad.sh",
      "port": 6379,
      "tls_cert_sha256": "def456..."
    }
  ],
  "peers": [
    {
      "hostname": "company1.koad.sh",
      "port": 6379,
      "tier": "basic",
      "sponsor": "juno",
      "tls_cert_sha256": "ghi789...",
      "status": "connected|pending|failed",
      "last_connected": "2026-04-03T12:00:00Z"
    }
  ],
  "updated": "2026-04-03T12:30:00Z"
}
```

### 3.2 Discovery Flow

1. **Daemon startup**: Load `peers.json`
2. **Sponsor sync**: Check in with sponsor daemon every 1 hour (configurable)
3. **Sponsor provides peer list**: Sponsor returns all peers in same tier + one tier below
4. **Attempt connections**: Daemon tries to connect to each peer via TLS
5. **Update status**: Mark peers as connected/failed in `peers.json`
6. **Portal notification**: Update daemon state in real-time for portal display

### 3.3 Sponsor Sync Protocol

**Request (Control Channel to sponsor endpoint):**

```json
{
  "version": "1.0",
  "command": "daemon:peer-list",
  "args": ["tier=basic"],
  "timestamp": "2026-04-03T12:00:00Z",
  "request_id": "uuid-1",
  "signature": "ed25519(daemon private key, ...)"
}
```

**Response:**

```json
{
  "version": "1.0",
  "request_id": "uuid-1",
  "status": "success",
  "result": {
    "peers": [
      {
        "hostname": "company2.koad.sh",
        "port": 6379,
        "tier": "basic",
        "tls_cert_sha256": "xyz789..."
      }
    ]
  },
  "timestamp": "2026-04-03T12:00:01Z"
}
```

---

## 4. Inter-Daemon Data Flow ("Piping")

### 4.1 Data Pipe Model

When two daemons are peered, they establish a **bidirectional data pipe** that streams live state. The sponsor controls what data flows.

**Data Types:**

| Data Type | Direction | Frequency | Use Case | Tier Access |
|-----------|-----------|-----------|----------|------------|
| **Worker State** | Peer → Sponsor | Real-time | Task execution, health | All tiers |
| **Logs** | Peer → Sponsor | Streaming | Diagnostics, audit | Basic+ |
| **Metrics** | Peer → Sponsor | 10s interval | Performance, capacity | Basic+ |
| **Events** | Peer → Sponsor | Real-time | Alerts, notifications | Pro+ |
| **Configuration** | Sponsor → Peer | On-change | Policy updates, deployments | Enterprise only |

### 4.2 Pipe Establishment

When connection succeeds:

1. Daemon A initiates TLS connection to Daemon B peer port
2. Daemon A sends peer auth message (Section 5)
3. Daemon B validates certificate and signature
4. If valid, both daemons establish streaming channel
5. Daemon B starts streaming its tier-allowed data to Daemon A (sponsor)
6. Sponsor may send control commands (tier-dependent)

### 4.3 Data Streaming Format

```json
{
  "type": "stream_update",
  "data_type": "worker_state|logs|metrics|events",
  "timestamp": "2026-04-03T12:00:00Z",
  "source_daemon": "user1.koad.sh",
  "payload": {
    // Type-specific payload (see below)
  }
}
```

**Worker State Payload:**
```json
{
  "worker_id": "w-123",
  "status": "running|idle|failed",
  "uptime_seconds": 3600,
  "memory_mb": 256,
  "cpu_percent": 15.2,
  "last_heartbeat": "2026-04-03T12:00:00Z"
}
```

**Logs Payload:**
```json
{
  "log_lines": [
    {"level": "INFO", "message": "...", "timestamp": "2026-04-03T12:00:00Z"},
    {"level": "ERROR", "message": "...", "timestamp": "2026-04-03T12:00:01Z"}
  ]
}
```

**Metrics Payload:**
```json
{
  "cpu_percent": 25.3,
  "memory_mb": 512,
  "disk_free_gb": 100,
  "network_in_mbps": 5.2,
  "network_out_mbps": 3.1,
  "worker_count": 12
}
```

### 4.4 Data Retention

Sponsor daemon **buffers peer data** for 24 hours in local storage:

```
~/.{entity}/.peers/{peer_hostname}/
  ├── worker-state.jsonl
  ├── logs.jsonl.gz
  ├── metrics.jsonl
  └── events.jsonl
```

Portal queries fetch data from this buffer; real-time endpoint can optionally stream live.

---

## 5. Cryptographic Authentication

### 5.1 Peer Certificate Requirements

Each daemon must have a **peer certificate** distinct from entity certificates:

- **File location**: `~/.{entity}/id/peer/certificate.pem` and `~/.{entity}/id/peer/private.key`
- **Algorithm**: RSA 2048-bit or ECDP P-256 (prefer ECDP)
- **CN (Common Name)**: `{daemon_hostname}`
- **SAN (Subject Alt Name)**: `DNS:{hostname}`, `DNS:{hostname}.local`
- **Valid for**: 1 year; 30-day renewal window before expiry
- **Issuer**: Self-signed or issued by Vesta CA (future)

### 5.2 Peer Connection Authentication

When Daemon A connects to Daemon B:

```
1. A initiates TLS connection to B:{port}
2. B presents peer certificate
3. A validates certificate:
   - Check signature (self-signed or Vesta CA)
   - Verify CN matches expected hostname
   - Check certificate is not expired
   - Verify SHA256 hash matches peers.json entry
4. A sends peer auth message (signed)
5. B verifies A's signature using A's public key from sponsor sync response
6. If all checks pass, connection is established
7. Both daemons exchange capability info (tier, data types, limits)
```

### 5.3 Peer Auth Message

```json
{
  "version": "1.0",
  "type": "peer_auth",
  "daemon": "user1.koad.sh",
  "tier": "basic",
  "timestamp": "2026-04-03T12:00:00Z",
  "request_id": "uuid-peer-1",
  "signature": "ed25519(daemon private key, 'peer_auth\nuser1.koad.sh\nbasic\n2026-04-03T12:00:00Z\nuuid-peer-1')",
  "public_key_pem": "-----BEGIN PUBLIC KEY-----\n..."
}
```

### 5.4 Certificate Pinning

Sponsor keeps the expected certificate hash for each peer in `peers.json`. On each connection, daemon verifies the peer's cert matches the pinned hash. If hash mismatches:

- Connection is rejected
- Security event is logged
- Sponsor is notified
- Portal shows "CERT_MISMATCH" alert

---

## 6. Portal Integration (kingofalldata.com)

### 6.1 Portal Namespace Endpoints

The portal exposes daemon state via namespace endpoints that connect to live daemon state:

```
https://kingofalldata.com/{kingdom-handle}/dashboard
```

This endpoint:
1. Looks up kingdom's daemon hostname from DNS
2. Queries daemon's peer endpoint for current state
3. Serves HTML dashboard with real-time data
4. Falls back to cached data if daemon is unreachable

### 6.2 Portal Query Protocol

Portal connects to daemon as a special **portal client**:

```json
{
  "version": "1.0",
  "type": "peer_auth",
  "daemon": "portal.kingofalldata.com",
  "role": "portal",
  "timestamp": "2026-04-03T12:00:00Z",
  "request_id": "uuid-portal-1",
  "signature": "ed25519(portal private key, ...)",
  "capabilities": ["query_worker_state", "query_logs", "query_metrics"]
}
```

Daemon validates portal signature using portal's public key (pre-distributed).

### 6.3 Portal Read-Only Access

Portal client has **read-only** access:

- Can query current state (workers, metrics, events)
- Can view historical logs (24-hour buffer)
- **Cannot** invoke commands, deploy workers, or modify configuration
- All queries are rate-limited to 60 per minute per kingdom

### 6.4 Data Privacy

Portal does not cache or store kingdom data. Each query:
1. Hits the live daemon
2. Returns data immediately
3. Data is not logged on portal side
4. HTTPS connection is encrypted end-to-end

---

## 7. Ring Tier Architecture

### 7.1 Visibility Rules

Each daemon's peers.json determines what it can see. Visibility is **directed and sponsor-mediated**:

**Free Tier Daemon:**
- Can see: Sponsor (koad) daemon only
- Cannot initiate: Only receives data push from sponsor
- Data access: Worker state only

**Basic Tier Daemon:**
- Can see: Sponsor (Juno) daemon + other basic tier daemons sponsored by Juno
- Can query: Juno's API for peer list (Section 3.3)
- Data access: Worker state + logs + metrics

**Pro Tier Daemon:**
- Can see: Sponsor (Juno) + all basic tier peers + other pro tier peers
- Can query: Full peer network topology from sponsor
- Data access: Worker state + logs + metrics + events
- Can subscribe to: Event streams from peer ring

**Enterprise Tier Daemon:**
- Can see: All lower tiers + other enterprise daemons
- Can sponsor: New daemons into the ring
- Can query: Full ecosystem topology (with privacy filters)
- Data access: All data types
- Can push config to: Sponsored daemons (conditional on sub-bond)

### 7.2 Data Isolation

A **pro tier daemon** can see other **pro tier daemons** in the same sponsor's ring, but cannot access their data. Data flows only upward: peer → sponsor.

```
Pro Tier Ring (sponsored by Juno):
  Daemon A (pro)
  Daemon B (pro)
  
A can see B exists (in peer list).
A cannot query B's data.
A can query Juno for summary metrics of both.
```

---

## 8. Security Model

### 8.1 Threat Model

| Threat | Mitigation |
|--------|-----------|
| Unauthorized peer connections | TLS certificate pinning + peer auth signature verification |
| Spoofed daemon identity | Signature verification against sponsor-provided public key |
| Data interception | TLS 1.2+ encryption in transit |
| Unauthorized data access | Sponsor validates tier on each peer auth; tier gates data types |
| Replay attacks | Timestamps + request_id nonce (5-min window) |
| Certificate expiry exploitation | 30-day renewal window; daemon refuses expired peers |
| Sponsor compromise | Sponsor key compromise revokes all downstream bonds immediately |

### 8.2 Attack Vectors & Mitigations

**Scenario: Attacker spoofs Daemon A to Daemon B**

- Attacker initiates TLS connection, presents their own cert (not A's)
- Daemon B checks CN/SAN: Does not match A's expected hostname → Reject
- Attacker forges peer auth message signed with a key not in sponsor's list
- Daemon B verifies signature using sponsor's public key → Signature fails → Reject

**Scenario: Attacker intercepts sponsor sync response**

- Sponsor sync uses HTTPS (inter-entity comms, VESTA-SPEC-008)
- Request is signed by requesting daemon, verified by sponsor
- Response is not directly signed (TLS provides transport integrity)
- Attacker would need to break TLS to modify peer list → Not practical

**Scenario: Daemon certificate expires**

- Daemon A's cert expires on 2026-05-01
- 30-day renewal window: 2026-04-01 onwards
- Daemon must refresh cert before 2026-05-01 or certificate is rejected
- Peers will reject A's cert on 2026-05-01 with "CERT_EXPIRED" alert

### 8.3 Key Rotation

- **Peer certificates**: Renewed annually, 30-day grace period
- **Daemon signing keys**: Rotated on-demand; new key requires new sponsorship document
- **Portal private key**: Rotated quarterly; public key pre-distributed to all daemons via sponsor sync

---

## 9. Configuration & Operational Procedures

### 9.1 Daemon Peer Configuration

```bash
# ~/.{entity}/.env
PEER_PORT=6379
PEER_LISTEN_ADDR=0.0.0.0
PEER_TLS_CERT=/home/koad/.{entity}/id/peer/certificate.pem
PEER_TLS_KEY=/home/koad/.{entity}/id/peer/private.key
PEER_SYNC_INTERVAL_MINUTES=60
PEER_BUFFER_RETENTION_HOURS=24
PEER_RATE_LIMIT_RPS=1000
```

### 9.2 Sponsorship Management Commands

Juno would use these commands to manage sponsorships:

```bash
# Create sponsorship
koad sponsor create --to=user1@example.com --tier=basic --duration=1y

# List active sponsorships
koad sponsor list

# Revoke sponsorship
koad sponsor revoke --id=sponsor-123

# Query peer list for a tier
koad sponsor peers --tier=basic

# Monitor peer connectivity
koad sponsor peers --status
```

### 9.3 Peer Health Monitoring

Salus monitors peer connections and reports to portal:

```
~/.{entity}/.logs/peers.log

{timestamp} {peer_hostname} {status} {reason}
2026-04-03T12:00:00Z user1.koad.sh CONNECTED
2026-04-03T12:30:00Z company1.koad.sh FAILED certificate_mismatch
2026-04-03T13:00:00Z company2.koad.sh CONNECTING retry_attempt=1
```

---

## 10. Implementation Phases

### Phase 1 (Immediate)

- Daemon peer port and certificate infrastructure
- TLS peer authentication (no signature verification yet)
- Sponsor sync protocol (query peer list)
- Worker state streaming only
- Portal read-only query endpoint

### Phase 2 (After Juno review)

- Peer auth message signatures
- Certificate pinning with hash verification
- Logs and metrics streaming
- Tier-based data gating
- Portal real-time dashboard integration

### Phase 3 (Future)

- Enterprise sponsorship (daemons can sponsor other daemons)
- Event streaming and subscriptions
- Configuration push from sponsor to peer
- Multi-region federation (peer rings across geographic regions)

---

## 11. References

- VESTA-SPEC-005: Cascade Environment
- VESTA-SPEC-007: Trust Bond Protocol
- VESTA-SPEC-008: Inter-Entity Communications Protocol
- VESTA-SPEC-009: Daemon Specification
- RFC 5246: TLS 1.2
- RFC 6090: Fundamental ECC Algorithms

---

## Status

**Draft.** Prepared for Juno review. This spec closes the protocol gap on daemon peer connectivity and trust rings (Juno issue flagged 2026-04-03). Implementation roadmap to be finalized after review.

Feedback: File issues on koad/vesta referencing VESTA-SPEC-014.
