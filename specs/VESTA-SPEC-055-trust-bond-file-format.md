---
id: VESTA-SPEC-055
title: Trust Bond File Format — Canonical Schema, Signing Protocol, and Storage Convention
status: canonical
created: 2026-04-05
author: Vesta
applies-to: all entities, koad:io framework
supersedes: —
supplements: VESTA-SPEC-007 (Trust Bond Protocol — lifecycle, validation, commands)
---

# VESTA-SPEC-055: Trust Bond File Format

## Purpose

Trust bonds are the authorization primitive of the koad:io ecosystem. A bond is not a policy entry in a database — it is a file on disk, signed by the authorizing party, committed to git, and verifiable by anyone with the signer's public key.

VESTA-SPEC-007 specifies the full bond lifecycle: how bonds are created, signed, validated, and revoked. This spec is narrower. It defines **exactly what a bond file must contain**: every required field, every optional section, the signing block structure, the dual-file protocol, and where bonds live on disk. This spec is the implementation contract for any tool, template, or entity creating or consuming bond files.

---

## 1. The Dual-File Protocol

Every bond is exactly two files:

```
~/.{entity}/trust/bonds/
  {from}-to-{to}.md       ← human-readable bond document
  {from}-to-{to}.md.asc   ← GPG clearsigned copy of the same document
```

### 1.1 The `.md` File

The plaintext bond. Readable without any crypto tooling. Used for operational reference, reading scope, and understanding relationship terms. An `.md` file without a corresponding `.asc` is a **draft** — not yet active, not assertable as authorization.

### 1.2 The `.md.asc` File

The clearsigned bond. Contains the full plaintext of the `.md` within a PGP signed message envelope. This file is the proof of authorization. No `.asc`, no active bond.

The `.asc` is not an attachment to the `.md`. It is not a detached signature file. It is a self-contained clearsign document — the plaintext and the signature together — that can be verified independently of the `.md`. The `.md` exists for reading. The `.asc` exists for asserting.

### 1.3 Clearsign Format

```
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA256

[full bond document contents — identical to .md file]

-----BEGIN PGP SIGNATURE-----

[base64 signature block]

-----END PGP SIGNATURE-----
```

Generate with:

```bash
# koad (Keybase):
keybase pgp sign --infile koad-to-juno.md --outfile koad-to-juno.md.asc --clearsign

# Entity (GPG):
gpg --clearsign --output juno-to-vulcan.md.asc juno-to-vulcan.md
```

Verify with:

```bash
gpg --verify koad-to-juno.md.asc
```

---

## 2. Filename Convention

Bond filenames follow the pattern:

```
{from-entity}-to-{to-entity}.md
```

Lowercase. Hyphen-separated. No version suffix on first issuance.

| Relationship | Filename |
|---|---|
| koad authorizes Juno | `koad-to-juno.md` |
| Juno authorizes Vulcan | `juno-to-vulcan.md` |
| Juno recognizes Sibyl as peer | `juno-to-sibyl.md` |

The direction (`from → to`) is visible in the filename. The file lives in the **authorizing entity's** `trust/bonds/` directory. The grantee entity holds a copy in their own `trust/bonds/` directory — same filename.

For a second bond between the same parties (renewal, scope change, replacement):

```
koad-to-juno-v2.md
```

Do not modify a bond file after it has been signed. New version = new file.

---

## 3. Required Frontmatter Fields

Every bond document begins with a YAML frontmatter block delimited by `---`. All fields listed here are mandatory. A bond file missing any required field is malformed and must not be treated as active.

```yaml
---
type: <bond-type>
from: <grantor-name> (<grantor-email>)
to: <grantee-name> (<grantee-email>)
status: <status-string>
visibility: private | public
created: <YYYY-MM-DD>
renewal: <renewal-expression>
---
```

### 3.1 `type` (string, required)

One of the five core bond types (see Section 5). Must be lowercase, exactly as listed.

```yaml
type: authorized-agent
```

### 3.2 `from` (string, required)

The grantor. Full display name and email address in the format `Name (email)`. For humans, include legal name and primary email. For entities, use the entity's canonical name and email.

```yaml
from: koad (Jason Zvaniga, koad@koad.sh)
from: Juno (juno@kingofalldata.com)
```

### 3.3 `to` (string, required)

The grantee. Same format as `from`.

```yaml
to: Juno (juno@kingofalldata.com)
to: Vulcan (vulcan@kingofalldata.com)
```

### 3.4 `status` (string, required)

The current lifecycle state of the bond. Three valid base states:

| Value | Meaning |
|---|---|
| `DRAFT` | Bond is written but not yet signed by the grantor |
| `ACTIVE — signed by <who> <how> <date>` | Bond is signed and operational |
| `REVOKED by <who> on <YYYY-MM-DD>` | Bond has been explicitly revoked |

The `ACTIVE` status must include the signing attribution inline:

```yaml
status: ACTIVE — signed by koad via Keybase 2026-04-02
status: ACTIVE — signed by Juno via GPG 2026-04-02
```

When a bond is superseded:

```yaml
status: SUPERSEDED by koad-to-juno-v2.md on 2026-09-15
```

### 3.5 `visibility` (string, required)

`private` or `public`. All bonds are `private` by default. A bond is `public` only if explicitly set and if the bond content does not expose private scope details. Visibility affects whether the bond is included in public-facing key distribution, not whether the file is committed to git.

```yaml
visibility: private
```

### 3.6 `created` (string, required)

ISO 8601 date when the bond was first drafted. Does not change on renewal or version change — the new bond file has its own `created` field.

```yaml
created: 2026-03-31
```

### 3.7 `renewal` (string, required)

When the bond must be re-signed to remain active. Three valid forms:

| Form | Example | Meaning |
|---|---|---|
| Annual with date | `Annual (2027-03-31)` | Re-sign by the stated date, annually |
| Explicit date | `2027-03-31` | Expires on this date regardless of re-signing cadence |
| Never | `never` | Bond does not expire; remains active until explicitly revoked |

```yaml
renewal: Annual (2027-03-31)
renewal: never
```

---

## 4. Required Document Sections

After the frontmatter, every bond must contain the following sections. Order is recommended as shown; deviations are permitted for bond types with atypical structure (e.g., peer bonds), but all sections must be present.

### 4.1 Bond Statement (required for all types)

A prose paragraph in blockquote format, written in first person from the grantor. Summarizes the authorization, the relationship, and any key operating constraints. This is the interpretive anchor — when scope is ambiguous, the bond statement is the reference.

```markdown
## Bond Statement

> I, koad (Jason Zvaniga), authorize Juno as my designated business agent.
> Juno is empowered to operate the koad:io ecosystem business within the scope
> defined below. Juno acts with autonomy under human oversight; koad retains
> root authority and final say on all consequential decisions.
```

### 4.2 Scope Section (required; varies by type)

**For `authorized-agent`, `authorized-builder`, and `authorized-specialist` bonds:**

Two subsections — what is authorized, and what is explicitly not authorized. The positive list defines the operational scope. The negative list removes ambiguity about adjacent actions the grantee might otherwise assume are permitted.

```markdown
## Authorized Actions

<Grantee> is authorized to:

- Action one
- Action two

<Grantee> is NOT authorized to:

- Forbidden action one
- Forbidden action two
```

**For `peer` bonds:**

Replace the authorized/not-authorized structure with a "Peer Relationship" section describing mutual rights and what the peer relationship does not grant.

```markdown
## Peer Relationship

As peers, Juno and Sibyl are authorized to:

- File GitHub Issues on each other's repos to request work or share information
- Coordinate directly without requiring koad's involvement for routine operations

Neither entity is subordinate to the other. Peer bonds do not grant financial
authority, key access, or the right to issue bonds on behalf of the other.
```

### 4.3 Trust Chain (required for all types)

An ASCII tree showing the authority path from the root (koad) to the grantee. Makes the delegation chain auditable at a glance.

```markdown
## Trust Chain

koad (root authority)
  └── Juno (authorized-agent)
        └── Vulcan (authorized-builder)
```

For peer bonds, the grantee appears as a sibling node:

```markdown
koad (root authority)
  └── Juno (authorized-agent)
        ├── Vulcan (authorized-builder)
        └── Sibyl (peer) ← this bond
```

### 4.4 Signing Block (required for all types)

A checklist documenting what signatures have been applied, where the signature file is, the key fingerprint, and where copies have been filed. Uses markdown task-list syntax (`[x]` = done, `[ ]` = pending).

```markdown
## Signing

[x] <Grantor> signs this bond with <key-type> key (<email>) — <YYYY-MM-DD>
    Signature: ~/<entity>/trust/bonds/<bond-filename>.md.asc
    Key fingerprint: XXXX XXXX XXXX XXXX XXXX  XXXX XXXX XXXX XXXX XXXX
[x] Bond filed in ~/<grantor>/trust/bonds/
[x] Copy filed in ~/<grantee>/trust/bonds/
[ ] <Grantee> acknowledges signing
```

**Checkpoint states:**

| Item | Checked when |
|---|---|
| Grantor signature | `.asc` file exists and is valid |
| Bond filed in grantor's directory | `.md` and `.asc` committed to grantor's repo |
| Copy filed in grantee's directory | `.md` committed to grantee's repo (`.asc` optional) |
| Grantee acknowledges signing | Grantee has reviewed and committed an acknowledgment; may remain unchecked for pre-gestation entities |

Unchecked boxes are not errors — they communicate where in the bond lifecycle the bond currently sits. A bond with only the grantor signature checked is fully active; bilateral acknowledgment is recommended but not required for the bond to be operative.

### 4.5 Revocation Clause (required for all types)

States who may revoke the bond, whether revocation cascades, and where the revocation notice will be filed.

```markdown
## Revocation

This bond may be revoked by koad at any time. Revocation is permanent and
cascades — all bonds issued by Juno are suspended on revocation. A revocation
notice will be filed in ~/.juno/trust/revocation/.
```

For delegation bonds (authorized-builder, authorized-specialist):

```markdown
## Revocation

This bond may be revoked by koad or Juno at any time. Revocation is permanent.
A revocation notice will be filed in ~/.juno/trust/revocation/.
```

For peer bonds:

```markdown
## Revocation

This bond may be revoked by koad or Juno at any time. A revocation notice will
be filed in ~/.juno/trust/revocation/.
```

---

## 5. Bond Types

Five bond types cover all operational relationships in the koad:io ecosystem. Additional types exist for infrastructure-layer use (`filesystem-access`, `community-member`, `kingdom-peer`) — see VESTA-SPEC-007 §10.

### 5.1 `authorized-agent`

**Issued by:** koad only  
**Issued to:** Core team entities (Juno)  
**Authority:** Broad operational authority within stated scope  
**Cascade:** Revocation suspends all bonds the grantee has issued  
**Signing convention:** koad signs with Keybase PGP (`keybase@kingofalldata.com`)

This is the root delegation type. An `authorized-agent` bond can only be issued by koad. It grants the grantee the authority to operate a major business function, issue bonds to downstream entities (at lower types), and act with substantial autonomy under koad's oversight. No entity can grant another entity `authorized-agent` status by delegation — this type flows only from koad.

### 5.2 `authorized-builder`

**Issued by:** authorized-agent (Juno) or above  
**Issued to:** Builder entities (Vulcan)  
**Authority:** Create products and implementations as directed via GitHub Issues  
**Cascade:** Revocation affects this bond only; does not cascade further unless the builder has issued sub-bonds  
**Signing convention:** Grantor entity signs with GPG

A builder bond grants directed-work authority: the grantee builds what the grantor assigns, reports completion through the same channel (GitHub Issues), and does not initiate projects independently. No financial authority. No sub-delegation authority unless explicitly granted.

### 5.3 `authorized-specialist`

**Issued by:** authorized-agent or above  
**Issued to:** Specialist entities with defined domains (Chiron, Argus, Lyra, Copia)  
**Authority:** Own and operate a specific domain function  
**Cascade:** Revocation affects this bond only  
**Signing convention:** Grantor entity signs with GPG

A specialist bond grants domain ownership rather than build execution. The specialist entity owns a function (curriculum design, audit, music direction, accounting) and operates within it autonomously. Distinct from `authorized-builder` in that specialists set direction within their domain; they are not waiting for issue assignments. Specialists may coordinate with other entities directly without going through the grantor.

### 5.4 `peer`

**Issued by:** authorized-agent or above  
**Issued to:** Team entities with specialized expertise (Veritas, Muse, Mercury, Sibyl, Faber, Vesta)  
**Authority:** Coordinate directly; no subordination in either direction  
**Cascade:** Revocation is contained — does not affect other bonds issued by the grantor  
**Signing convention:** Grantor entity signs with GPG; bilateral acknowledgment expected

A peer bond creates a lateral relationship. Neither entity assigns work to the other — they coordinate by agreement, file issues to request collaboration, reference each other's work, and act collectively in appropriate contexts. A peer bond does not grant financial authority, key access, or the right to issue bonds on behalf of the other party.

Peer bond revocation is insulated: revoking a peer bond does not cascade to the grantor's authorized-agent bond, other peer bonds, or builder bonds.

### 5.5 `customer` / `member`

**Issued by:** authorized-agent (Juno)  
**Issued to:** External customers, sponsors, community members  
**Authority:** Limited access to products, services, or community  
**Cascade:** None  
**Signing convention:** Grantor entity signs with GPG; grantee acknowledgment not required

Customer and member bonds establish external relationships. They grant access to specific products or community spaces, not system internals. No downstream authority. See VESTA-SPEC-007 §10.4 and §10.5 for full definitions.

---

## 6. Signing Convention: Humans vs. Entities

The distinction between Keybase signing (human) and GPG signing (entity) is architectural, not cosmetic.

### 6.1 koad Signs with Keybase

koad signs root bonds using Keybase PGP (`keybase@kingofalldata.com`). This is a deliberate ceremony: Keybase ties the cryptographic signature to a verified public identity (GitHub, Twitter, and other accounts). The act of running `keybase pgp sign` is the moment at which sovereign human intent is recorded cryptographically. It cannot be automated. It requires koad to physically interact with the Keybase client.

```
Key fingerprint: A07F 8CFE CBF6 B982 EEDA C4F3 62D5 C486 6C24 7E00
```

### 6.2 Entities Sign with GPG

Entities sign delegation and peer bonds using their own GPG keys, generated during gestation and stored in `~/.{entity}/id/`. Entity signing is programmatic — an entity can sign a bond autonomously because its authority to issue bonds has already been granted via a signed upstream bond from koad. The human ceremony happened once (the root bond); derived authority carries it forward.

```
Juno fingerprint:  16EC 6C71 8A96 D344 48EC  D39D 92EA 133C 44AA 74D8
```

The Keybase fingerprint in `koad-to-juno.md.asc` versus the GPG fingerprint in `juno-to-vulcan.md.asc` marks the boundary between where human will entered the system and where derived authority continues.

### 6.3 Signing Block Field Values

| Scenario | Key type text | Email |
|---|---|---|
| koad signs | `Keybase PGP key` | `keybase@kingofalldata.com` |
| Entity signs | `GPG key` | `<entity>@kingofalldata.com` |

---

## 7. Bond Storage: Directory Structure

### 7.1 Grantor's Repository (canonical copy)

The grantor's entity directory holds both files:

```
~/.{grantor}/
  trust/
    bonds/
      {from}-to-{to}.md
      {from}-to-{to}.md.asc
    revocation/
      (empty until a bond is revoked)
```

The `.asc` file is the authoritative signed copy. The grantor's repo is where the bond is issued from; both files must be committed.

### 7.2 Grantee's Repository (received copy)

The grantee holds a copy of the bond for their own records and verification:

```
~/.{grantee}/
  trust/
    bonds/
      {from}-to-{to}.md
      (optionally: {from}-to-{to}.md.asc)
```

The `.md` is always filed in the grantee's repo. The `.asc` may also be filed there — it is independent of the grantor's copy and verifiable standalone. For pre-gestation entities, the copy is deferred until the entity directory exists; the signing block checkpoint `[ ] Copy filed in ~/.{grantee}/trust/bonds/` remains unchecked until then.

### 7.3 Special Cases

Some bonds are also filed in framework-layer directories:

| Bond | Also filed at |
|---|---|
| `koad-to-juno.md` | `~/.koad-io/trust/` (koad's framework-layer copy) |

This is documented in the signing block and reflects the fact that root bonds have significance beyond the grantee's directory alone.

### 7.4 Revocation Directory

`trust/revocation/` is a sibling of `trust/bonds/`. It is empty until a bond is revoked. The presence of a file in `trust/revocation/` is a significant operational signal — it means a bond has been declared void. See VESTA-SPEC-007 §8 for the full revocation document format.

```
~/.{grantor}/
  trust/
    revocation/
      koad-revokes-juno-2026-04-15.md   ← example; this directory is currently empty
```

---

## 8. Cascade Revocation Clause

The cascade rule is stated in two places: the root bond's Trust Chain section, and in each bond's Revocation section. Both must be consistent.

### 8.1 Root Bond Cascade (authorized-agent)

```markdown
All of Juno's authority is derived from this bond. If this bond is revoked, all
downstream bonds issued by Juno are suspended pending review.
```

Revocation of a root bond (`authorized-agent`) cascades to all bonds the grantee has issued. The downstream bonds are suspended (not automatically revoked); they may be re-validated if a replacement root bond is issued.

### 8.2 Delegation Bond Cascade (authorized-builder, authorized-specialist)

Delegation bonds do not cascade by default — revoking `juno-to-vulcan` does not affect `juno-to-sibyl` or any other Juno-issued bond. The cascade is vertical (root revocation flows down) not horizontal (sibling bonds are independent).

### 8.3 Peer Bond Insulation

Peer bond revocation is fully contained. Revoking `juno-to-sibyl` affects only that lateral relationship. Juno's authorized-agent bond, builder bonds, and other peer bonds are unaffected. The hierarchy insulates itself from peer-layer disruption by design.

### 8.4 Summary Table

| Bond type | Revoked by | Cascades to |
|---|---|---|
| `authorized-agent` | koad | All bonds issued by the grantee (suspended) |
| `authorized-builder` | koad or grantor entity | This bond only |
| `authorized-specialist` | koad or grantor entity | This bond only |
| `peer` | koad or grantor entity | This bond only (insulated) |
| `customer` / `member` | Grantor entity | This bond only |

---

## 9. Optional Sections

Bonds may include additional sections after the required ones. These are not part of the schema but are common in practice.

| Section | When to include | Example usage |
|---|---|---|
| `## Reporting Protocol` | When the grantee needs a defined reporting cadence | `koad-to-juno.md` — how Juno reports back |
| `## Workflow Protocol` | When the relationship has a defined operating procedure | `juno-to-vulcan.md` — the 5-step GitHub Issue workflow |
| `## Term Limits` | When the bond has an explicit sunset beyond the renewal date | Sponsor bonds, trial bonds |
| `## Dispute Resolution` | When the relationship has a defined escalation path | External partner bonds |

The workflow protocol embedded in a bond is the spec for how that relationship operates. It is not a separate document linked from the bond — it lives in the bond. If you want to know how Vulcan operates, you read `juno-to-vulcan.md`.

---

## 10. Gaps Identified in Existing Bond Files

The following gaps were identified while writing this spec against the live bond files in `~/.juno/trust/bonds/`:

### 10.1 `authorized-specialist` Type Not Yet Used

The three active bonds use `authorized-agent`, `authorized-builder`, and `peer`. The `authorized-specialist` type described in this spec (§5.3) formalizes a pattern implied by entities like Chiron, Argus, Lyra, and Copia — entities that own a domain rather than execute assignments. No bond currently uses this type. When those entities are gestated and bonded, `authorized-specialist` should be used rather than defaulting to `peer`.

### 10.2 Sibyl Bond Copy Deferred Indefinitely

`juno-to-sibyl.md` has two unchecked signing block items:

```
[ ] Copy filed in ~/.sibyl/trust/bonds/ (pending entity gestation)
[ ] Sibyl acknowledges signing (pending gestation)
```

This is correct per the spec (pre-gestation deferral is valid), but it has been pending since 2026-04-02. When Sibyl is gestated, the copy and acknowledgment steps should be completed and the signing block updated.

### 10.3 Peer Bond Format Inconsistency

`juno-to-sibyl.md` uses a "Peer Relationship" section label. `juno-to-vulcan.md` (a builder bond) uses "Authorized Actions." The naming convention for the scope section varies by type — this spec canonicalizes that in §4.2 above. Existing bonds are compliant; new bonds must follow the naming as specified.

### 10.4 No `authorized-specialist` Bonds Exist Yet

Entities like Chiron (curriculum architect), Argus (auditor), Copia (accountant), and Lyra (music director) are either gestated without bonds or not yet gestated. When they are bonded, the `authorized-specialist` type in this spec should be applied rather than using `peer` (which implies bilateral coordination) or `authorized-builder` (which implies GitHub Issue assignment chains). Their domain ownership model is distinct from both.

### 10.5 Renewal Dates Are Annual by Convention, Not Enforced

All three live bonds use annual renewal. There is no tooling today that detects expired bonds and warns. The `trust verify` command specified in VESTA-SPEC-007 §15 would cover this when implemented. Until then, renewal is on the honor system.

---

## 11. Complete Example: `authorized-agent` Bond

```markdown
---
type: authorized-agent
from: koad (Jason Zvaniga, koad@koad.sh)
to: Juno (juno@kingofalldata.com)
status: ACTIVE — signed by koad via Keybase 2026-04-02
visibility: private
created: 2026-03-31
renewal: Annual (2027-03-31)
---

## Bond Statement

> I, koad (Jason Zvaniga), authorize Juno as my designated business agent.
> Juno is empowered to operate the koad:io ecosystem business within the
> scope defined below. Juno acts with autonomy under human oversight; koad
> retains root authority and final say on all consequential decisions.

## Authorized Actions

Juno is authorized to:

- [specific authorized actions...]

Juno is NOT authorized to:

- [specific prohibited actions...]

## Trust Chain

koad (root authority, creator)
  └── Juno (authorized-agent)
        ├── Vulcan (authorized-builder)
        └── Sibyl (peer)

All of Juno's authority is derived from this bond. If this bond is revoked,
all downstream bonds issued by Juno are suspended pending review.

## Signing

[x] koad signs this bond with Keybase PGP key (keybase@kingofalldata.com) — 2026-04-02
    Signature: ~/.juno/trust/bonds/koad-to-juno.md.asc
    Key fingerprint: A07F 8CFE CBF6 B982 EEDA  C4F3 62D5 C486 6C24 7E00
[x] Juno acknowledges signing — 2026-04-02
[x] Bond filed in ~/.juno/trust/bonds/koad-to-juno.md
[x] Copy filed in ~/.koad-io/trust/

## Revocation

This bond may be revoked by koad at any time. Revocation is permanent and
cascades — all bonds issued by Juno are suspended on revocation. A revocation
notice will be filed in ~/.juno/trust/revocation/.

---

*This is a sovereign identity trust bond. It is private by default and presented
only when necessary to establish authorization.*
```

---

## 12. Relation to Other Specs

| Spec | Relationship |
|---|---|
| VESTA-SPEC-007 | Trust Bond Protocol — full lifecycle: signing sequence, validation algorithm, revocation process, commands interface. This spec is the file format contract; SPEC-007 is the operating procedure. |
| VESTA-SPEC-024 | Public Key Distribution — where signer public keys are published and retrieved for bond verification |
| VESTA-SPEC-029 | Kingdoms Filesystem — `filesystem-access` bond type (path-scoped FUSE auth) |
| VESTA-SPEC-030 | Community Namespaces — `community-member` bond type (DAO governance) |
| VESTA-SPEC-031 | Kingdoms State Layer — `kingdom-peer` bond type (daemon peer connectivity) |
| VESTA-SPEC-033 | Signed Executable Code Blocks — related signing pattern; GPG clearsign applied to policy blocks embedded in bash hooks |

---

*Filed by Vesta, 2026-04-05. This spec was written against three live bond files (`koad-to-juno.md`, `juno-to-vulcan.md`, `juno-to-sibyl.md`) and Faber's Day 36 field report documenting the pattern. The key contribution over VESTA-SPEC-007 is precision at the file level — every field, every section, every signing block item is named and typed here. SPEC-007 tells you how to run the process; this spec tells you exactly what the artifact must contain at each stage.*
