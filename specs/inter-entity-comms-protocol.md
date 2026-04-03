---
status: draft
id: spec-inter-entity-comms
title: "Inter-Entity Communications Protocol"
type: spec
created: 2026-04-03
updated: 2026-04-03
owner: vesta
description: "Canonical protocol for secure, authenticated communication between entities in the koad:io ecosystem"
---

# Inter-Entity Communications Protocol

## 1. Overview

Inter-entity communication enables coordinated action across the koad:io ecosystem. This protocol defines how entities authenticate each other, establish secure channels, and exchange commands or data.

### Design Principles

- **Trust-based**: All communication assumes pre-established trust bonds (VESTA-SPEC-007)
- **Authenticated**: All messages carry cryptographic proof of origin
- **Encrypted**: All channels use TLS with certificate validation
- **Auditable**: Communication is logged and traceable for forensics
- **Async-first**: Messages are queued and processed asynchronously by default

## 2. Channel Architecture

### Channel Types

Entities establish two classes of channels:

| Channel | Direction | Use Case | Protocol |
|---------|-----------|----------|----------|
| **Control** | Entity → Entity | Commands, sync requests, state queries | REST over TLS + signed headers |
| **Data** | Entity → Entity | Log streaming, bulk data transfer | WebSocket over TLS |

### Endpoint Discovery

Entities advertise their endpoints in the cascade environment:

```bash
# ~/.{entity}/.env
CONTROL_ENDPOINT="https://entity.internal:8443"
DATA_ENDPOINT="wss://entity.internal:8444"
```

The dispatcher loads entity environments (section 2, CLI execution model), making endpoints available to commands that need to reach other entities.

## 3. Certificate Architecture

### Public Key Infrastructure

Vesta maintains the public key distribution system:

```
~/.vesta/
  ├── id/
  │   ├── ssl/
  │   │   ├── master-curve.pem           (Vesta private key - entity authority)
  │   │   ├── master-curve-parameters.pem (public params)
  │   │   └── dhparam-*.pem               (forward secrecy params)
  │   └── signing/
  │       └── [identity keys for signing trust bonds]
  │
  ~/.{entity}/
    ├── id/
    │   ├── ssl/
    │   │   ├── entity-cert.pem           (entity's TLS certificate)
    │   │   ├── entity-key.pem            (gitignored: private key)
    │   │   └── chain.pem                 (issuer chain for validation)
    │   └── ...
```

### Certificate Issuance

Vesta issues entity certificates during gestation:

1. Entity requests CSR (Certificate Signing Request)
2. Vesta validates trust bond
3. Vesta signs certificate with `master-curve.pem`
4. Certificate is installed at `~/.{entity}/id/ssl/entity-cert.pem`
5. Chain is distributed to all entities for validation

Each certificate includes:

- **Subject**: Entity name and identifier
- **Public Key**: Entity's TLS public key
- **SANs** (Subject Alternative Names): All known endpoints (hostnames, IPs)
- **Authority**: Signed by Vesta's master key
- **Validity**: 1 year (renewal 30 days before expiry)

### Certificate Validation

When entity A connects to entity B:

1. A loads B's certificate from `~/.vesta/entities/{b}/cert.pem` (Vesta-maintained registry)
2. A validates chain against `~/.vesta/id/ssl/master-curve-parameters.pem`
3. A validates SANs against the endpoint being used
4. Connection proceeds only if all checks pass

## 4. Control Channel (REST + Signed Headers)

### Endpoint Format

```
POST https://{entity}.internal:8443/control/invoke
```

### Message Format

```json
{
  "version": "1.0",
  "command": "juno:deploy",
  "args": ["production"],
  "timestamp": "2026-04-03T12:34:56Z",
  "request_id": "uuid-v4",
  "signature": "base64-encoded-ed25519-signature"
}
```

### Signature Scheme

Signature covers:

```
{command}\n{args[0]}\n...\n{timestamp}\n{request_id}
```

Signed with the originating entity's identity key (`~/.{entity}/id/signing/private.key`).

Recipient verifies using the sender's public key from the trust bond record.

### Response Format

```json
{
  "version": "1.0",
  "request_id": "uuid-v4",
  "status": "success|failure",
  "result": {...},
  "error": "human-readable error if status=failure",
  "timestamp": "2026-04-03T12:34:57Z"
}
```

### Return Codes

| Code | Meaning |
|------|---------|
| 200 | Command accepted and processed |
| 202 | Command queued for async processing |
| 400 | Malformed request (invalid signature, missing fields) |
| 401 | Authentication failed (signature verification failed) |
| 403 | Unauthorized (no trust bond, revoked access) |
| 404 | Command not found on recipient |
| 500 | Internal error during processing |

## 5. Data Channel (WebSocket + TLS)

### Connection Handshake

```
wss://{entity}.internal:8444/stream/{stream_type}/{entity_name}
```

Example:
```
wss://juno.internal:8444/stream/logs/salus
```

- `stream_type`: logs, metrics, events
- `entity_name`: originating entity (for stream filtering)

### Message Format

Frame header (JSON):
```json
{
  "type": "stream_data|stream_end|ping|pong",
  "stream": "logs",
  "entity": "salus",
  "sequence": 42,
  "timestamp": "2026-04-03T12:34:56Z"
}
```

Payload: Raw stream data (gzipped for logs)

### Flow Control

- Recipient sends `ping` every 30 seconds to detect stale connections
- Sender responds with `pong`
- If no `pong` received within 60 seconds, connection is terminated
- Messages are numbered sequentially; gaps trigger re-request

## 6. Authentication & Authorization

### Trust Bonds (VESTA-SPEC-007)

All inter-entity communication requires an active trust bond:

- Entity A → Entity B requires a bond document signed by both
- Bond specifies allowed commands and data streams
- Bonds are time-bound and can be revoked
- Revocation is immediate; entities check bond status on each request

### Bond Validation

Before processing any message:

```
1. Verify request signature using sender's public key
2. Load trust bond record: ~/ .vesta/trust/bonds/{sender_entity}.json
3. Check bond.status == "active"
4. Check current_time < bond.expires_at
5. Check requested_action in bond.allowed_actions
6. If all pass, process; else return 403
```

### Rate Limiting

Each entity pair has a rate limit defined in the trust bond:

```json
{
  "source": "salus",
  "target": "vulcan",
  "allowed_actions": ["deploy", "monitor"],
  "rate_limit": {
    "requests_per_minute": 60,
    "concurrent_connections": 5
  }
}
```

Violating limits results in `429 Too Many Requests`.

## 7. Protocol Examples

### Example 1: Salus Requests Deployment Status from Vulcan

**Request (Control Channel):**
```json
{
  "version": "1.0",
  "command": "vulcan:status",
  "args": ["production"],
  "timestamp": "2026-04-03T12:00:00Z",
  "request_id": "abc-123",
  "signature": "ed25519(salus private key, 'vulcan:status\nproduction\n2026-04-03T12:00:00Z\nabc-123')"
}
```

**Response:**
```json
{
  "version": "1.0",
  "request_id": "abc-123",
  "status": "success",
  "result": {
    "deployment": {
      "status": "running",
      "version": "v1.2.3",
      "uptime_seconds": 3600
    }
  },
  "timestamp": "2026-04-03T12:00:01Z"
}
```

### Example 2: Argus Streams Logs from Juno

**WebSocket Upgrade:**
```
GET /stream/logs/argus HTTP/1.1
Host: juno.internal:8444
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: ...
Sec-WebSocket-Version: 13
```

**First Frame (header only):**
```json
{
  "type": "stream_data",
  "stream": "logs",
  "entity": "argus",
  "sequence": 1,
  "timestamp": "2026-04-03T12:00:00Z"
}
[gzipped log data]
```

## 8. Security Considerations

### Threat Model

| Threat | Mitigation |
|--------|-----------|
| Man-in-the-middle | TLS + certificate pinning (known CAs only) |
| Replay attacks | Timestamps + nonce-like request IDs (within 60 second window) |
| Spoofed identity | Signature verification against trust bond public key |
| Unauthorized access | Trust bond validation + rate limiting |
| Eavesdropping | TLS encryption in transit |

### Key Rotation

- Entity certificates rotate annually (30-day renewal window before expiry)
- Trust bond public keys can be rotated on-demand with new bond document
- All keys are stored in `~/.{entity}/id/` with .gitignore protecting private keys

### Audit Logging

Every inter-entity communication must be logged locally:

```
~/.{entity}/.logs/comms.log

{timestamp} {direction} {peer_entity} {command|stream} {status} {bytes}
```

Example:
```
2026-04-03T12:00:00Z OUT vulcan:deploy production success 256
2026-04-03T12:00:01Z IN salus query-status success 512
```

## 9. Failure Modes & Recovery

### Connection Failures

- Transient failures (network glitch): automatic retry with exponential backoff (1s, 2s, 4s, 8s max)
- Persistent failures (endpoint down): defer to next scheduled sync, alert operator if >1 hour
- Authentication failures (invalid signature): log security event, do not retry

### Message Queue

Commands intended for offline entities are queued locally:

```
~/.{entity}/.queue/outbound/{peer_entity}/{request_id}.json
```

Queue is processed when peer comes online. Max queue size: 1000 messages.

### Partial Failure Recovery

Data streams that are interrupted mid-transfer:

1. Sender detects missing ack for sequence N
2. Sender seeks back to sequence N and resumes
3. Receiver validates sequence continuity
4. On validation failure, full retry from beginning

## 10. Future Enhancements

- **Pub/Sub Model**: Entities subscribe to event types (e.g., "all deployments")
- **Policy Language**: Declarative rules for command routing (e.g., "any command from Salus requires dual-approval")
- **Load Balancing**: Support for entity replicas behind load balancers
- **Observability**: Distributed tracing across entity boundaries using request IDs

---

## Status

**Draft** — Specification complete, pending review by affected entities (Juno, Vulcan, Salus).

## References

- VESTA-SPEC-007: Trust Bonds Protocol
- VESTA-SPEC-001: CLI Execution Model (section 2: environment cascade)
- RFC 5246: TLS 1.2
- RFC 6234: US Secure Hash and Signature Algorithms
