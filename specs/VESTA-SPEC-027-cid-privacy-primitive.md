---
id: VESTA-SPEC-027
title: CID Privacy Primitive — Opaque Addressing for the Dark Passenger
status: stable
created: 2026-04-04
updated: 2026-04-05
author: Vesta
applies-to: daemon, Dark Passenger, inter-kingdom protocol, federation
---

# VESTA-SPEC-027: CID Privacy Primitive — Opaque Addressing for the Dark Passenger

## Purpose

Define the CID-as-request-key pattern: a privacy primitive built into the koad:io addressing layer that allows the Dark Passenger and inter-kingdom protocol to request information about URLs and resources without transmitting the URLs themselves. Knowledge of the mapping is the access credential. The wire protocol never hands the key to parties who shouldn't have it, because the key is never transmitted.

---

## 1. The CID System

### 1.1 Generation

Two deterministic functions compose the CID:

```js
koad.generate.handle(str)
// Normalizes: lowercase, strips non-alphanumeric characters
// "https://github.com/koad" → "httpsgithubcomkoad"

koad.generate.cid(str)
// SHA256 hashes the handle → 17-character ID from a safe charset
// "httpsgithubcomkoad" → "k3mN7pQrX9wY2zA"  (example)
```

Properties:
- **Deterministic**: same input → same CID, on any instance, in any kingdom, at any time
- **Opaque**: the CID reveals nothing about its source without knowing the input
- **Collision-resistant**: SHA256 backing; probability of collision is negligible for practical inputs
- **Safe-charset output**: 17 characters, no special characters, URL-safe, storage-safe
- **Universal**: applies to any string — URLs, usernames, content references, arbitrary handles

### 1.2 Where CIDs Appear

CIDs are already the identity substrate of the koad:io platform:

| Usage | Input | Result |
|---|---|---|
| User `_id` | normalized username | CID stored as primary key |
| URL reference | normalized URL | CID used as lookup key |
| Content address | content hash input | CID for deduplication |
| Entity reference | entity name | CID for federated lookup |

The user `_id` being a CID is not incidental — it enables federation without a central authority. Any kingdom can compute the same CID for the same user and they resolve to the same entity, without ever registering with a directory.

---

## 2. The CID-as-Request-Key Pattern

### 2.1 The Core Insight

When the Dark Passenger needs to ask a peer kingdom "what do you know about this URL?", it does not transmit the URL. It transmits the CID of that URL.

```
// Passenger resolves locally:
const cid = koad.generate.cid(koad.generate.handle(url))

// Wire message:
{ "query": "cid-lookup", "key": "k3mN7pQrX9wY2zA" }

// Not this:
{ "query": "url-lookup", "url": "https://github.com/koad/alice" }
```

The receiving kingdom either has a record keyed to `k3mN7pQrX9wY2zA` or it does not. The response is:
- A record (if the kingdom holds a mapping for that CID), or
- Empty (if it does not)

In neither case is the URL mentioned on the wire.

### 2.2 Why This Is Private

The privacy guarantee operates at multiple layers:

**Wire privacy**: A network observer watching the traffic between two kingdoms sees CIDs — opaque 17-character strings. Without knowing the input that produced each CID, the observer learns nothing about what is being requested. Traffic analysis cannot infer which URLs, users, or resources are being queried.

**Log privacy**: Server access logs on both sides record CIDs, not URLs. Log aggregators, analytics pipelines, and any third party with access to logs see only opaque identifiers.

**Protocol privacy**: The protocol has no URL field. There is no place in the wire format where a URL can leak. Compliant implementations cannot accidentally send a URL because the schema does not include one.

**Inference resistance**: Frequency analysis against CIDs is possible but impractical without the preimage dictionary. An observer would need to enumerate all possible inputs, compute CIDs for each, and match against observed traffic — a brute-force attack on the input space, not an intrinsic weakness of the protocol.

### 2.3 The Knowledge-as-Access-Control Principle

Access to the CID is derived entirely from knowledge of the source material:

```
knows(URL) → can compute CID → can participate in CID-keyed exchanges
!knows(URL) → CID is noise → excluded from exchanges about that URL
```

The protocol enforces this without any explicit access control list. There is no authorization token, no shared secret, no ring credential check at this layer. The CID itself is the credential. Parties who should not know about a URL are excluded by their ignorance of the URL — not by a gate they could potentially bypass.

This is access control without an access control system.

---

## 3. Dark Passenger Integration

### 3.1 Augmentation Package Lookup

The Dark Passenger (VESTA-SPEC-018) fetches augmentation packages for URLs a ring member visits. The naive implementation leaks visited URLs to the daemon and to any peer kingdom queried.

With the CID pattern:

```
Browser visits: https://myspace.com/koad

Extension computes locally:
  handle = koad.generate.handle("https://myspace.com/koad")
            → "httpsmyspacecomkoad"
  cid    = koad.generate.cid(handle)
            → "q8vR2nLpT5xK9mW"  (example)

Extension queries daemon:
  GET /augments/resolve?cid=q8vR2nLpT5xK9mW

Daemon responds:
  { "augmentation_id": "myspace-koad", "package": "/augments/myspace-koad/" }
  — or —
  { "augmentation_id": null }
```

The daemon's access log shows: `GET /augments/resolve?cid=q8vR2nLpT5xK9mW`. No URL is recorded. The daemon knows only that someone requested resolution for that CID. The mapping between CID and URL is held only by parties who already know the URL.

### 3.2 Cross-Kingdom Augmentation Queries

When a local daemon does not hold a CID mapping, it may query peer kingdoms. The inter-kingdom query uses the same opaque identifier:

```json
{
  "query": "cid-augmentation",
  "cid": "q8vR2nLpT5xK9mW",
  "requesting_kingdom": "thinker.koad.sh"
}
```

The peer kingdom responds with the augmentation package metadata if it holds a mapping, without the requesting kingdom ever disclosing which URL triggered the lookup.

### 3.3 Caching

CID-keyed caches are naturally private:

- Cache keys are CIDs, not URLs
- Cache hit/miss patterns do not reveal URL access patterns to cache operators
- Shared caches (CDN-style, between kingdoms) can serve augmentation packages without learning which URLs their clients are visiting
- Cache invalidation is triggered by CID, not URL — same privacy guarantee applies to invalidation traffic

---

## 4. The IPFS Hologram

IPFS content identifiers (CIDs) operate on the same conceptual model at a different layer:

| Dimension | koad:io CID | IPFS CID |
|---|---|---|
| Input | arbitrary string (URL, username, handle) | content bytes |
| Output | 17-char opaque identifier | base58/base32 multihash |
| Deterministic | yes | yes |
| Opaque | yes | yes (hash reveals nothing about content) |
| Registry | none needed | none needed |
| Access model | knowing input = having the key | knowing CID = fetching content |

Both systems embody the same principle: **content-addressed, registry-free, opaque by construction**. The difference is the input domain and the resolution target. koad:io CIDs address metadata (augmentation packages, user records, URL mappings). IPFS CIDs address content blobs.

The two systems are composable: a koad:io CID can resolve to an IPFS CID, creating a two-level opaque addressing stack. The URL maps to a koad:io CID; the koad:io CID resolves to an IPFS CID; the IPFS CID fetches the content. No layer in this chain requires URL transmission.

---

## 5. Federation Implications

### 5.1 Zero-Registration Federation

Any kingdom that implements `koad.generate.handle` and `koad.generate.cid` correctly will produce identical CIDs for identical inputs. This means:

- Kingdoms can exchange CID-keyed records without a shared registry
- A user gestated on Kingdom A has the same CID on Kingdom B — computed independently
- No central authority is needed to assign or validate identifiers
- Forking a kingdom and carrying its data preserves all CID-keyed relationships

Federation is a property of the hash function, not of any coordination protocol.

### 5.2 CID-Keyed Gossip

In a multi-kingdom mesh, nodes can gossip CID-keyed records:

```
"I have a record for k3mN7pQrX9wY2zA with version 4"
"I have a record for q8vR2nLpT5xK9mW with version 2"
```

Receiving kingdoms can merge, reject, or request elaboration. Nodes that do not hold mappings for those CIDs cannot infer anything about the gossip content. Nodes that do hold mappings can validate and merge.

This gossip protocol leaks no URL or resource information to nodes that are not already party to the knowledge.

### 5.3 Selective Disclosure

A kingdom can choose to share CID-to-URL mappings with specific peers. This is the mechanism by which ring members gain the ability to participate in CID-keyed exchanges about specific resources:

```
koad shares with Juno:
  { "cid": "k3mN7pQrX9wY2zA", "url": "https://github.com/koad/alice" }

Now Juno can:
- Compute this CID independently and verify
- Query other kingdoms using this CID
- Participate in augmentation exchanges about this URL

Parties koad did not share with:
- Cannot derive the URL from the CID
- Cannot participate in exchanges about this URL
- Cannot even confirm that "k3mN7pQrX9wY2zA" refers to a URL
```

Selective disclosure is the bridge between the private CID space and explicit authorization. It does not require changing the addressing scheme — it is simply sharing the preimage with trusted parties.

---

## 6. Observable Traffic Analysis Resistance

### 6.1 What an Observer Sees

A passive observer watching inter-kingdom traffic sees:

```
→ { "query": "cid-lookup", "key": "k3mN7pQrX9wY2zA" }
← { "record": { ... } }
→ { "query": "cid-lookup", "key": "p2hX5qMnR8vJ3cL" }
← { "record": null }
→ { "query": "cid-lookup", "key": "w7tY4sNpV6xB1dF" }
← { "record": { ... } }
```

The observer learns:
- Query volume over time
- Which CIDs received non-null responses (records exist)
- Response sizes (rough signal of record complexity)

The observer does not learn:
- Which URLs, users, or resources correspond to any CID
- What the records contain (if the response payload is encrypted)
- Whether queries for the same CID from different requesters concern the same resource

### 6.2 Remaining Signals

The CID pattern does not eliminate all traffic signals:

- **Timing correlation**: If a ring member visits a URL and the daemon immediately queries a peer kingdom, timing correlation could link the visit to the query — even without URL content. Mitigation: introduce jitter in query dispatch, batch queries, prefetch CIDs.
- **Query volume**: High query volume for a specific CID reveals that many parties are interested in that resource, even if the resource is unknown. Mitigation: normalize query rates, use batch endpoints.
- **Response size correlation**: Large responses correlate with resource-rich records. Mitigation: pad responses to fixed sizes.

These mitigations are implementation choices. The protocol provides the structural guarantee; implementations should layer additional noise as appropriate to their threat model.

### 6.3 Threat Model Boundary

The CID privacy primitive protects against:
- Passive network observers
- Compromised peer kingdoms (they see CIDs, not URLs)
- Log aggregators and analytics on either end
- Protocol-level inference (no URL field exists to leak)

It does not protect against:
- Compromised clients who already know the URL
- Side-channel attacks on query timing
- Dictionary attacks against known URL spaces (URLs are enumerable; SHA256 is not a secret)

For high-sensitivity resources, combine CID addressing with additional layers: encrypted payloads, ring-credential-gated resolution, or IPFS-style content addressing for the record itself.

---

## 7. Implementation Requirements

### 7.1 Mandatory

1. The `koad.generate.handle` and `koad.generate.cid` functions must be identical across all implementations (same normalization rules, same hash algorithm, same output charset and length).
2. All inter-kingdom CID lookup requests must use only the CID as the lookup key — no URL, filename, or human-readable identifier in the query.
3. Daemon access logs must record CIDs, not URLs, for CID-keyed endpoints.
4. Extension-to-daemon queries for augmentation resolution must use CIDs (not URL query parameters).

### 7.2 Recommended

5. Response payloads for CID-keyed endpoints should be encrypted with the requesting party's public key where feasible (prevents even CID-keyed records from leaking to log readers).
6. Query dispatch should include random jitter (50–500ms) to break timing correlation between page visits and CID queries.
7. Prefetch CID mappings for known ring members' URL associations during session initialization, rather than on-demand — reduces correlation between visit timing and query timing.

### 7.3 Reference Implementation Check

The canonical test vector:

```js
koad.generate.handle("https://github.com/koad")  // must equal: "httpsgithubcomkoad"
koad.generate.cid("httpsgithubcomkoad")           // must produce the same 17-char output on all instances
```

Any implementation that diverges from the canonical normalization or hash output is not interoperable with the federation.

---

## Collision Analysis & Scale Limits

*Addendum — analysis performed by Juno, 2026-04-04.*

### Keyspace Size

The current CID generator uses a 55-character safe charset with a 17-character output length:

```
Keyspace = 55^17 ≈ 10^29.6  (~385 septillion distinct CIDs)
```

### Birthday Bound

| Metric | Value |
|---|---|
| 50% collision probability | ~620 trillion entries |
| P(collision) at 1M entries | ~1.3×10^-18 (negligible) |
| P(collision) at 1B entries | ~1.3×10^-12 (negligible) |
| P(collision) at 1T entries | ~1.3×10^-6 (starts to matter) |

### Limiting Factor

The practical collision resistance is bounded by the 17-byte truncation of SHA256, not by SHA256 itself. Full SHA256 has a birthday bound of 2^128 ≈ 10^38 — nine orders of magnitude larger than the current truncated output space.

The current 17-char CID is safe for any realistic near-term deployment. Collision risk only becomes relevant at trillion-scale entry counts (e.g., a global URL cache or universal signature index).

### Known Issue: Modulo Bias

The current implementation contains a statistical impurity:

```js
digest[i] % 55  // 256 % 55 = 36
```

Because 256 is not evenly divisible by 55, values 0–35 in the digest byte map to charset positions approximately 1/7 more often than values 36–54. This is not a security issue at current scale, but it is statistically impure — the output distribution is not perfectly uniform.

**Fix options:**
- Rejection sampling: discard bytes that fall in the biased range and redraw
- Bump charset size to a power-of-2 (e.g., 64 characters) so modulo bias disappears entirely

### Scale Recommendation

| Scale | Action |
|---|---|
| Up to ~1T entries | Current 17-char CID is sufficient |
| Trillion-scale (global URL cache, universal sig index) | Bump to 20 chars — pushes 50% birthday bound to ~10^18 |

No change is required for current koad:io deployments. The modulo bias fix is the only near-term recommendation if output distribution purity matters for statistical analysis of CID spaces.

---

## 8. Relation to Other Specs

| Spec | Relationship |
|---|---|
| VESTA-SPEC-018 (Dark Passenger Augmentation Protocol) | This spec provides the privacy layer for all augmentation resolution queries defined in -018 |
| VESTA-SPEC-008 (Inter-Entity Communications Protocol) | CID-keyed queries are a message type within the control channel defined in -008 |
| VESTA-SPEC-014 (Kingdom Peer Connectivity) | Cross-kingdom CID queries flow over the peer channels defined in -014 |
| VESTA-SPEC-002 (Entity Identity) | User `_id` fields are CIDs — this spec formally documents that as a privacy design, not just an implementation detail |

---

## 9. Resolved Design Decisions

The following questions were flagged during initial drafting. All are resolved as of 2026-04-05.

### 9.1 CID Version Field

**Decision: YES — include a version prefix in wire format.**

Wire format for CID lookup requests must include a `cid_version` field defaulting to `1`:

```json
{
  "query": "cid-lookup",
  "cid_version": 1,
  "key": "k3mN7pQrX9wY2zA"
}
```

Rationale: The current CID function (17-char SHA256-derived, 55-char charset) is `version 1`. If the charset is bumped to 64 characters (to eliminate modulo bias) or the output length is extended to 20 characters (for trillion-scale deployments), the version field allows existing kingdoms to route requests correctly without breaking records keyed to `v1` CIDs. Kingdoms must reject queries with unknown `cid_version` values and return a structured error — not a null response, which would be indistinguishable from "no record found."

### 9.2 Bulk Resolution Endpoint

**Decision: YES — implement batch endpoint with set-size limits.**

```
POST /augments/resolve
{ "cids": ["k3mN7pQrX9wY2zA", "q8vR2nLpT5xK9mW", ...], "cid_version": 1 }
```

The tradeoff (batch reduces timing correlation but reveals the client's CID set) resolves in favor of batch because:
- Timing correlation is a stronger attack than CID-set inference
- The client's CID set only reveals which resources the client has *already computed CIDs for* — not which it is actively browsing
- Batch queries during session initialization (prefetch) are the primary use case, not per-visit queries

**Constraint**: Batch requests are capped at 100 CIDs per request. Larger sets must be split across requests with random jitter between them (prevents set-size fingerprinting).

### 9.3 Reverse-Lookup Authorization

**Decision: YES — ring-gated, logged, and opt-in per kingdom.**

Kingdoms may expose a CID-to-URL reverse lookup endpoint for authorized parties:

```
GET /admin/cid-reverse?cid=k3mN7pQrX9wY2zA
Authorization: Bearer <ring-credential>
```

Rules:
- This endpoint is disabled by default. Kingdoms must explicitly enable it.
- Callers must present a valid inner-ring or peer-ring credential.
- All reverse-lookup requests must be logged with caller identity, timestamp, and CID queried.
- The reverse mapping endpoint must not be accessible on the same port as the public CID lookup endpoint.

This is an administrative escape hatch, not a protocol feature. CID privacy guarantees hold everywhere except within the explicit administrative surface that the kingdom operator controls.

### 9.4 CID Expiry and TTL

**Decision: Include `last_verified` timestamp; TTL is advisory, not enforced.**

CID records must include a `last_verified` Unix timestamp:

```json
{
  "cid": "k3mN7pQrX9wY2zA",
  "record": { ... },
  "last_verified": 1743811200
}
```

Rationale: Enforced TTL (auto-expiry after N days) creates fragility for legitimate long-lived records (a stable URL mapped for years). Advisory TTL via `last_verified` allows clients to make their own staleness judgments based on their use case:
- Augmentation packages for stable profile pages: 30-day staleness acceptable
- Augmentation packages for transactional URLs: 24-hour staleness maximum
- Security-sensitive records: client should re-verify on every session

Kingdoms may optionally include a `suggested_ttl_seconds` field alongside `last_verified` — but clients are not required to honor it.

---

*Filed by Vesta, 2026-04-04. Resolved 2026-04-05. Developed from direct observation of koad articulating the Dark Passenger privacy insight: "the dark-passenger can ask for URL information without actually saying the URL." This spec formalizes that insight as a first-class architectural primitive — not a feature of the Dark Passenger specifically, but a property of the CID addressing layer that all koad:io components inherit.*
