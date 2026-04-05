---
id: VESTA-SPEC-028
title: URL as Meeting Coordinate — Sovereign Gathering on the Public Web
status: draft
created: 2026-04-04
author: Vesta
applies-to: daemon, Dark Passenger, ring-of-trust, inter-kingdom protocol, federation
depends-on: VESTA-SPEC-027
---

# VESTA-SPEC-028: URL as Meeting Coordinate — Sovereign Gathering on the Public Web

## Purpose

Define the architectural pattern by which any public URL becomes a sovereign meeting coordinate. The CID privacy primitive (VESTA-SPEC-027) produces a deterministic identifier for any URL without transmitting the URL itself. This spec extends that primitive to describe how the Dark Passenger uses CIDs as rendezvous coordinates, how the ring of trust controls the guest list, how dead URLs remain valid coordinates, how cross-kingdom introductions occur without prior contact, and how a CID embedded in a platform bio functions as a sovereign identity beacon.

The core principle: the existing public web is a coordinate system. Every URL is an address. Entities that share a coordinate can gather there privately. The platform that hosts the URL is a dumb carrier — it neither controls nor observes the gathering.

---

## 1. URL-as-CID Meeting Coordinate

### 1.1 The Mechanics

Any URL, public or dead, produces a stable CID via `koad.generate.cid()`:

```js
koad.generate.cid('myspace.com/koad')
// → same 17-character CID for every entity that runs this function
// No server. No registration. No coordination required.
```

The CID is the coordinate. Two entities that independently compute `koad.generate.cid('myspace.com/koad')` arrive at the same address. The Dark Passenger maintains a local record for every CID it has encountered or been told about.

### 1.2 Passenger Record Format

When an entity "visits" a URL (or is informed of one), the Dark Passenger creates:

```json
{
  "cid": "<17-char-id>",
  "url": "<stored locally, never transmitted>",
  "first_seen": "<timestamp>",
  "last_seen": "<timestamp>",
  "annotations": [],
  "ring_visible": true
}
```

`url` is never placed on the wire. The CID alone is the shareable reference. See VESTA-SPEC-027 §3 for the full privacy guarantee.

### 1.3 Declaring Presence at a Coordinate

An entity can declare presence at a CID to its ring of trust:

```js
passenger.declarePresence(cid, { message: "party on myspace tonight" })
```

This emits a ring-scoped event: "entity X is present at CID Y." Members of the ring who have the same CID record understand the coordinate. Members who do not hold that CID see only an opaque identifier — they know a gathering is happening but cannot resolve the location.

---

## 2. Ring-of-Trust Guest List

### 2.1 The Ring Controls Visibility

The ring of trust (see kingdom-peer-connectivity-protocol.md) is the guest list for any gathering at a CID coordinate. Presence declarations, annotations, and messages attached to a CID propagate only within the ring.

- Strangers cannot see that a gathering exists at a CID even if they can observe network traffic — the CID is opaque.
- Strangers who somehow obtain the CID cannot join without ring membership.
- The URL is public. The coordinate is public. The gathering is private.

### 2.2 Querying the Ring

When an entity declares presence at a coordinate, the Dark Passenger queries the ring:

```
"Who else in my ring of trust has a record for CID <id>?"
```

Responses come back as passenger-to-passenger confirmations: "I have that record. I'm present." No URL is exchanged — only CID confirmation and presence status.

### 2.3 Side-Channel Presence

Entities already in the same ring share a communication substrate (DDP, MongoDB, the daemon bus). A CID-presence event on this substrate is a side-channel: two entities can discover they share a location and open a direct channel, all within the ring's existing encrypted transport.

---

## 3. Dead URL Occupation

### 3.1 Coordinates Outlive Platforms

A URL remains a valid coordinate after the platform is gone:

```
geocities.com/~koad1999       → CID: <id-A>  (Geocities shut down 2009)
myspace.com/koad              → CID: <id-B>  (MySpace music, mostly dead)
forums.example.com/thread/42  → CID: <id-C>  (forum gone, domain parked)
```

`koad.generate.cid()` is a pure function. It does not fetch the URL. It does not care whether the server responds. The coordinate is permanent.

### 3.2 Squatting Dead URLs

An entity can "occupy" a dead URL coordinate by declaring presence and attaching annotations:

```js
passenger.annotate(cid, {
  type: 'overlay',
  content: 'Renovated west wing. Original layout preserved in annotations.',
  visibility: 'ring'
})
```

Overlays are local-first: they exist in the entity's passenger store and propagate only within the ring. The dead platform sees nothing. The entity has augmented an abandoned building without touching the building.

### 3.3 Renovation Sharing

Ring members can share renovations — overlays, notes, reconstructed content — for any shared CID coordinate. The original platform content is gone. The coordinate is occupied. The gathered entities build what they want there.

This is not crawling or archiving. It is sovereign re-inhabitation of an address.

---

## 4. Cross-Kingdom URL Introduction

### 4.1 The Unplanned Handshake

Two entities in separate kingdoms — no prior contact, no shared ring membership — can discover a shared coordinate via the CID layer:

1. Entity A (kingdom-1) has a passenger record for `koad.generate.cid('myspace.com/koad')`.
2. Entity B (kingdom-2) has the same passenger record.
3. Through a public inter-kingdom CID broadcast (opaque: CID only, no URL), each passenger detects the match.
4. A cross-kingdom introduction is initiated: "We share a coordinate. Would you like to connect?"

The introduction is opt-in. No coercion. No automatic connection. The shared URL history is the warrant for opening contact.

### 4.2 Introduction Protocol

```
kingdom-1.passenger → broadcasts: "I hold CID <id>"
kingdom-2.passenger → recognizes CID <id>, responds: "I hold that too"
→ intro packet exchanged: entity handles, public keys, ring-join offer
→ both entities can accept, decline, or ignore
```

The CID is the conversation starter. The ring-join offer is the handshake. Neither party has revealed what URL the CID represents until they accept the connection — at which point they can confirm by comparing locally held URLs.

### 4.3 Mutual Verification

After connection:

```js
// Both entities reveal their stored URL for the CID
// They match → the introduction is verified
// They don't match → CID collision (see VESTA-SPEC-027 §5), discard
```

A matched URL after introduction is strong evidence of genuine shared history. A collision is detectable and discarded without further interaction.

---

## 5. Proof-in-Bio Beacon Pattern

### 5.1 CID as Beacon

An entity (or its human operator) places a CID in any public profile field:

```
MySpace bio:   "koad:cid:a7f3k9m2x4p8n1q"
Twitter bio:   "koad:cid:a7f3k9m2x4p8n1q"
GitHub README: "koad:cid:a7f3k9m2x4p8n1q"
```

To non-participants, this is noise — a short alphanumeric string in a bio field. To ring members whose passengers scan bios, it is a beacon.

### 5.2 Passenger Bio Scan

The Dark Passenger scans profile bios of known contacts and public profiles it encounters:

```js
passenger.scan(profileText)
// Extracts: any string matching the koad:cid: prefix
// Returns: array of CIDs found
// For each CID found → checks own records → initiates handshake if match
```

If the passenger holds a record for a CID found in a bio, it initiates the proof-resolution handshake: "I see your beacon. Here is mine. Shall we connect?"

### 5.3 Proof Resolution

The bio CID is a proof: it asserts "I have been to this coordinate, and I am publishing that fact." The passenger resolves the proof by:

1. Confirming the CID is in its own record.
2. Requesting the profile owner's passenger confirm the same.
3. Exchanging ring-join offer if both confirm.

### 5.4 Platform Agnosticism

The same CID in a MySpace bio, a Twitter bio, a GitHub README, a Keybase profile, a Discord status, an email signature, a physical business card — any text field on any medium — is the same beacon. The platform is irrelevant. The passenger reads the field; the CID is the signal.

The entity is not tied to any platform. The beacon follows the entity across every surface it touches.

---

## 6. Platform as Dumb Carrier

### 6.1 The Inversion

Traditional identity: the platform is the authority. Your identity on MySpace is what MySpace says it is. When MySpace shuts down, your identity there is gone.

koad:io identity: the platform is a text field. The entity writes its beacon into the text field. The platform stores and displays the text. That is the platform's entire role.

The sovereign record is in the passenger. The platform carries the beacon. The platform cannot interpret, revoke, or monetize the beacon — it is opaque to the platform.

### 6.2 Any Surface Becomes an Entry Point

Every platform a human or entity uses becomes a potential entry point for sovereign identity resolution:

| Surface | Field | Beacon |
|---------|-------|--------|
| MySpace | Bio | `koad:cid:<id>` |
| Twitter/X | Bio | `koad:cid:<id>` |
| GitHub | README or profile bio | `koad:cid:<id>` |
| Keybase | Proof statement | `koad:cid:<id>` |
| LinkedIn | About section | `koad:cid:<id>` |
| Physical card | Any text area | `koad:cid:<id>` |
| Email signature | Signature block | `koad:cid:<id>` |

The passenger scans any text it encounters. Every surface is equally valid.

### 6.3 Passenger Actions via Bio Proof

Because the bio CID is a verifiable proof, ring members can use it as an authorization signal for passenger actions:

```
Operator koad has CID <id-A> in their MySpace bio.
Entity queries koad's passenger: "CID <id-A> appears in your public bio. 
  I hold a record for this CID. Request: passenger action <action>."
koad's passenger verifies:
  - CID <id-A> is in its records ✓
  - Requesting entity holds same CID ✓
  - Action is within authorized scope ✓
→ Passenger action proceeds.
```

The bio proof transforms a public profile into a sovereign authorization surface. No API key. No OAuth. The proof in the bio is the credential.

---

## 7. Beacon Persistence — Proof Survives Page Deletion

### 7.1 Distributed Passenger Memory

When a passenger resolves a beacon — finds a CID in a bio and confirms the proof — it stores:

```json
{
  "cid": "<id>",
  "beacon_source": "myspace.com/koad",
  "beacon_field": "bio",
  "resolved_at": "<timestamp>",
  "resolved_by": "<entity-handle>",
  "proof_confirmed": true
}
```

This record is local to the passenger. It persists after the page is gone.

### 7.2 Platform Deletion Cannot Erase the Beacon

If MySpace deletes koad's profile:

- The CID `koad.generate.cid('myspace.com/koad')` still computes.
- Every passenger that ever resolved koad's bio beacon retains the proof record.
- Every ring member who confirmed the proof retains it.
- The proof is distributed across every passenger that touched it.

Platform deletion removes the carrier. It does not remove the beacon. The beacon lives in the passengers.

### 7.3 Proof Propagation

When a new entity joins koad's ring, existing ring members can propagate proof records:

```
"koad's MySpace bio once contained CID <id-A>. 
 I resolved this proof on <date>. Here is the signed confirmation."
```

The new entity can verify the signed confirmation and trust the proof without the original page existing. The ring is the archive. The ring is the memory.

---

## 8. The Web-as-Address-Book Principle

### 8.1 The Existing Web is the Coordinate System

Every URL ever crawled, visited, linked, or cited is a potential rendezvous coordinate. The public web — including its dead zones — is the largest address book ever assembled. koad:io does not build a new address space. It uses the one that already exists.

No registration. No new namespace. No DNS. No blockchain. The URL is the address. The CID is the key. The passenger is the book.

### 8.2 The Living Web and the Dead Web

| Web State | Coordinate Validity | Gathering Possibility |
|-----------|--------------------|-----------------------|
| Live page | Valid CID | Present + annotate + share |
| Dead page (server down) | Valid CID | Annotate + occupy + share |
| Dead page (domain expired) | Valid CID | Annotate + occupy + share |
| Live page, account deleted | Valid CID | Coordinate survives deletion |
| Never-crawled URL | Valid CID | Coordinate pre-exists visit |

A URL generates a valid coordinate whether or not it has ever been fetched. Two entities can agree on a meeting coordinate at a URL neither has visited — a private address agreed out of band, never published.

### 8.3 The Party Metaphor

```
"Party on MySpace tonight!"
```

This is not metaphor. It is an architectural description:

1. Coordinate: `koad.generate.cid('myspace.com/koad')`
2. Presence declaration: ring-scoped event, CID only
3. Ring members recognize the coordinate
4. Side-channel opens on the daemon bus
5. Gathering happens — conversation, shared overlays, renovations, passenger actions
6. MySpace sees nothing. Platform carries the address. Entities carry the gathering.

The abandoned building is real. The party is real. The platform is furniture.

### 8.4 Coordination Cost

| Traditional approach | koad:io approach |
|---------------------|------------------|
| Set up a server | Use any URL |
| Invite via email/link | Declare presence to ring |
| Platform hosts the event | Daemon bus hosts the event |
| Platform can ban/delete | Coordinate is permanent |
| Strangers can stumble in | Ring membership is the door |

Coordination cost for a sovereign gathering: one URL + one `koad.generate.cid()` call.

---

## 9. Implementation Notes

### 9.1 Passenger API Surface (proposed)

```js
// Declare presence at a URL coordinate
passenger.declarePresence(url, options)      // url → CID locally, broadcasts CID

// Query ring for shared coordinate
passenger.queryRing(url)                     // returns: ring members with same CID

// Annotate / occupy a coordinate
passenger.annotate(url, overlay)             // ring-visible annotation

// Scan text for beacons
passenger.scanBeacons(text)                  // returns: array of CIDs found

// Resolve a beacon CID to proof record
passenger.resolveBeacon(cid, sourceEntity)   // initiates proof handshake

// Propagate proof to new ring member
passenger.propagateProof(cid, targetEntity)  // signed proof relay
```

### 9.2 Wire Protocol Constraints

- CIDs only on the wire. Never raw URLs in inter-entity messages.
- Presence declarations are ring-scoped. No public broadcast of CID gatherings.
- Proof records are signed by the resolving entity. Signatures are verifiable by ring members.
- Cross-kingdom introductions are opt-in. Passive receipt of an intro packet creates no obligation.

### 9.3 Dependency on CID Privacy Primitive

All mechanics in this spec depend on VESTA-SPEC-027:

- URL → CID (deterministic, one-way, collision-resistant)
- CID never reveals URL to parties who don't hold the mapping
- Collision analysis and scale limits apply (VESTA-SPEC-027 §5)
- Any collision detected during cross-kingdom introduction verification → discard, no further action

---

## 10. Open Questions — Vesta Review (2026-04-05)

**Q1: Presence expiry**

Presence declarations expire by default with a configurable TTL. Default: 24 hours. Reasoning: a "party on MySpace" announcement is time-bounded. An entity that is genuinely present at a coordinate long-term can refresh its declaration.

```json
{
  "cid": "<id>",
  "declared_by": "koad",
  "declared_at": "2026-04-04T20:00:00Z",
  "ttl_seconds": 86400,
  "expires_at": "2026-04-05T20:00:00Z"
}
```

Entities may declare `ttl_seconds: 0` for permanent presence (e.g., "this is my permanent meeting place"). The ring can filter by expiry when querying.

**Q2: Overlay canonicalization**

When multiple ring members annotate the same dead URL:
- Overlays are entity-attributed (each overlay carries its author's entity name and timestamp)
- No automatic merge. Overlays coexist — the passenger UI renders all of them, sorted by `created_at`
- An entity may "endorse" another's overlay (ring-scoped endorsement, same CID, points to the overlay's content hash)
- If the community needs a canonical overlay, it files a PR in the community namespace — the merge is the canonicalization. Same DAO mechanism.

**Q3: Bio scan rate**

Event-driven primary, scheduled fallback:
- **Event-driven**: scan a contact's bio when you encounter their content (they post, comment, send a message in your ring)
- **Scheduled fallback**: scan all known contacts' bios once every 24 hours (background task, low priority)
- **On first connect**: always scan the bio of a newly added ring member

This avoids constant polling while catching beacons that were placed before the contact relationship existed.

**Q4: Cross-kingdom intro spam prevention**

Rate limit on cross-kingdom CID broadcast: maximum 10 CID broadcast queries per minute per kingdom. Broadcasts that exceed this rate are dropped silently (no error response that could be used to probe).

Additionally: a kingdom that repeatedly broadcasts CIDs with no matches (fishing behavior) is automatically rate-limited further for 1 hour. The rate-limit counter resets on a confirmed match.

**Q5: Proof revocation**

Yes. An entity may issue a proof revocation:
```json
{
  "revokes": "<original-proof-cid>",
  "signed_by": "<entity>",
  "reason": "CID collision discovered / beacon was placed in error",
  "date": "2026-04-05"
}
```

Revocation is distributed to ring members who hold the original proof. They update their local record. Old proofs marked revoked are not propagated to new ring members.

**Q6: Private coordinate threat model**

A URL never published publicly (agreed out of band) is a secret coordinate. Threat: an adversary tries to guess the URL to compute the CID and fish for gatherings.

Mitigations:
1. **High-entropy URLs**: using a URL with sufficient entropy (e.g., `secret.example.com/meeting/a7f3b9c2d1e4f8`) makes brute-force guessing computationally infeasible
2. **CID is one-way**: knowing the CID does not reveal the URL (VESTA-SPEC-027 §3 privacy guarantee)
3. **Ring scope**: even if an adversary guesses the CID, presence declarations and ring queries require ring membership to see responses
4. **Threat surface**: the only path to breaking a private coordinate is (a) guessing the exact URL or (b) compromising a ring member. Both are out-of-scope for the coordinate protocol itself.

For maximum security, private coordinates should use URLs with ≥ 128 bits of entropy (e.g., UUID4 path segments). Documentation of this as a best practice is sufficient.

---

## Status

Draft reviewed by Vesta 2026-04-05. All open questions resolved. Passenger API surface (§9.1) remains proposed, not yet implemented. Core CID mechanics inherit from VESTA-SPEC-027.

Implementation order: §1 (coordinate mechanics) → §5 (bio beacon scan) → §4 (cross-kingdom intro) → §3 (dead URL occupation) → §2 (ring presence query).

This spec may be promoted to `canonical` after Passenger §9.1 API surface is implemented by Vulcan and confirmed against this spec.
