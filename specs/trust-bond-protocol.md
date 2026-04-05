---
status: draft
id: VESTA-SPEC-007
title: "Trust Bond Protocol"
type: spec
created: 2026-04-03
updated: 2026-04-05
owner: vesta
description: "Canonical protocol for trust bonds — signed authorization documents that establish entity relationships and delegation of authority"
---

# Trust Bond Protocol

## 1. Overview

A **trust bond** is a signed document that establishes an authorization relationship between two entities (entities or persons) in the koad:io ecosystem. Trust bonds are the foundation of the permission system — they specify who can do what, by whose delegation, and under what conditions.

### Design Principles

- **Explicit**: All authority is derived from signed bonds; implicit authority does not exist
- **Revocable**: Bonds can be revoked unilaterally by the grantor
- **Cascading**: Revocation of an upstream bond suspends all downstream bonds derived from it
- **Recorded**: Both parties keep a copy of the bond; no single source of truth
- **Auditable**: The complete history of a bond (creation, signatures, revocation) is preserved in git
- **Humanreadable**: Bond documents are Markdown; the signature is detached, not embedded

### Bond Hierarchy

```
koad (root entity)
  └── authorized-agent bond
        └── delegated entity (e.g., Juno)
              ├── authorized-builder bond → Vulcan
              ├── peer bond → Vesta
              └── customer bond → Customer1
```

Authority flows down the chain: each entity may issue bonds up to the scope of its own bond.

## 2. Bond Types and Authority Scopes

Each bond has a **type** that defines the category of relationship and the scope of authority that can be granted.

| Type | Issued By | Authority | Revocable By | Notes |
|------|-----------|-----------|--------------|-------|
| **authorized-agent** | koad only | Unlimited operational autonomy within stated scope | koad | The grantor retains root authority. Downstream bonds are suspended on revocation. |
| **authorized-builder** | authorized-agent or peer | Product creation and assigned builds | Both grantor and grantor's superior | Builder acts within assigned scope only (GitHub Issues). |
| **peer** | authorized-agent | Coordinate on shared domains | Both grantor and grantor's superior | Peers do not assign work to each other; they align by agreement. |
| **customer** | authorized-agent | Limited access to products or services | Grantor only | No authority to issue downstream bonds or access system internals. |
| **member** | authorized-agent | Community participation and coordination | Grantor only | Community member status; may include communication channels and shared resources. |
| **filesystem-access** | Entity (namespace owner) | Read/write access to specific kingdoms namespace paths | Grantor | Used by SPEC-029 (Kingdoms Filesystem) to grant FUSE-level access. Scoped to explicit path list. |
| **community-member** | Community entity or founding steward | Tiered access to a community namespace | Grantor (steward or founder) | Used by SPEC-030. Carries membership tier (member/contributor/steward/founder) and access scope. |
| **kingdom-peer** | Entity (via daemon) | Daemon-to-daemon connectivity for kingdoms state sync | Both parties | Used by SPEC-031. Grants peer access to DDP state layer and kingdoms cache operations. Rate-limit and scope fields mandatory. |

## 3. Bond Document Format

### Frontmatter Fields

Every bond document begins with a YAML frontmatter block containing metadata:

```yaml
---
type: authorized-agent | authorized-builder | peer | customer | member | filesystem-access | community-member | kingdom-peer
from: <entity-name or person-name> (<email-or-contact>)
to: <entity-name or person-name> (<email-or-contact>)
status: DRAFT | ACTIVE | REVOKED
visibility: private | public
created: <YYYY-MM-DD>
renewal: <renewal-type> | <YYYY-MM-DD> | never
---
```

### Required Fields

- **type** — One of the bond types (Section 2): `authorized-agent`, `authorized-builder`, `peer`, `customer`, `member`, `filesystem-access`, `community-member`, `kingdom-peer`
- **from** — Full name and contact info of the grantor (entity or person)
- **to** — Full name and contact info of the grantee (entity or person)
- **status** — Current state of the bond (DRAFT, ACTIVE, or REVOKED)
- **visibility** — Whether the bond is private by default (always `private` unless explicitly public)
- **created** — Date the bond was drafted
- **renewal** — When the bond must be re-signed or explicitly renewed, or "never" for permanent bonds

### Example Frontmatter

```yaml
---
type: authorized-agent
from: koad (Jason Zvaniga, koad@koad.sh)
to: Juno (juno@kingofalldata.com)
status: DRAFT — signed by koad via Keybase 2026-04-02
visibility: private
created: 2026-03-31
renewal: Annual (2027-03-31)
---
```

## 4. Bond Document Sections

### Required Sections

Every bond must contain the following sections in this order:

#### 4.1 Bond Statement

A prose paragraph in first person from the grantor that briefly summarizes the authorization and relationship:

```markdown
## Bond Statement

> I, koad, authorize Juno as my designated business agent. Juno is empowered to 
> operate the koad:io ecosystem business within the scope defined below, acting 
> with autonomy under human oversight. Koad retains root authority and final say 
> on all consequential decisions.
```

This section makes the bond's intent clear to any reader and serves as the interpretive anchor.

#### 4.2 Authorized Actions (for agent/builder/customer bonds)

Lists what the grantee **is** authorized to do and what they are **NOT** authorized to do. Use two separate subsections:

```markdown
## Authorized Actions

The grantee is authorized to:
- Action 1
- Action 2
- ...

The grantee is NOT authorized to:
- Forbidden action 1
- Forbidden action 2
- ...
```

**Peer and member bonds** may substitute a "Relationship" or "Member Privileges" section describing mutual rights instead of unidirectional authorization.

#### 4.3 Trust Chain

Shows the authority chain from root (koad) through the bond holder:

```markdown
## Trust Chain

koad (root authority)
  └── Juno (authorized-agent)
        ├── Vulcan (authorized-builder)
        ├── Vesta (peer)
        └── [other downstream bonds]
```

This makes the delegation explicit and auditable.

#### 4.4 Signing

Documents the signature process and current state. Use a checklist format:

```markdown
## Signing

```
[ ] Grantor signs with [key-type] key ([email]) — <expected date>
    Signature file: ~/.{entity}/trust/bonds/{bond-file}.md.asc
    Key fingerprint: [XXXX XXXX ...]
[x] Bond filed in ~/.{grantor-entity}/trust/bonds/
[x] Copy filed in ~/.{grantee-entity}/trust/bonds/
[ ] Grantee acknowledges signing (optional, depends on bond type)
```
```

**Key usage rules:**
- **koad→entity bonds**: signed by koad with Keybase PGP key (`keybase@kingofalldata.com`)
- **entity→entity bonds**: signed by the grantor entity with its GPG key
- **Signature format**: Keybase cleartext signature (PGP `--clearsign` or equivalent)
- **Signature storage**: As a separate `.asc` file next to the markdown bond

#### 4.5 Revocation

Describes how the bond can be revoked and what happens if it is:

```markdown
## Revocation

This bond may be revoked by [grantor] at any time. [Cascade details if applicable].
A revocation notice will be filed in ~/.{grantor}/trust/revocation/.
```

**Example:**

```markdown
This bond may be revoked by koad at any time. Revocation is permanent and 
cascades — all bonds issued by Juno are suspended on revocation.
```

### Optional Sections

Bonds may include additional sections as needed:

- **Reporting Protocol** — How the grantee reports back on authority usage
- **Workflow Protocol** — Detailed operational steps (e.g., for builder bonds)
- **Dispute Resolution** — Who to contact if the bond is questioned
- **Term Limits** — If the bond has a sunset date

## 5. Bond Signing Sequence

### Step 1: Draft

The grantor creates the bond document as a plain `.md` file in `~/.{grantor}/trust/bonds/`:

```bash
~/.juno/trust/bonds/juno-to-vulcan.md
```

The frontmatter status is set to `DRAFT` during this phase.

### Step 2: Sign with Keybase or GPG

The grantor signs the bond using either **Keybase** (for koad) or **GPG** (for entities):

**Keybase cleartext sign (koad):**
```bash
keybase pgp sign --infile juno-to-vulcan.md --outfile juno-to-vulcan.md.asc --clearsign
```

**GPG cleartext sign (entities):**
```bash
gpg --clearsign --output juno-to-vulcan.md.asc juno-to-vulcan.md
```

This produces a `.md.asc` file containing both the plaintext bond (in the signed section) and the PGP signature block.

### Step 3: Update Status

After signing, update the bond's frontmatter status to reflect the signature:

```yaml
status: ACTIVE — signed by Juno via GPG 2026-04-02
```

### Step 4: File in Both Directories

The grantor files the bond in **two places:**

1. **Grantor's repo**: `~/.{grantor}/trust/bonds/{bond-file}.md` and `{bond-file}.md.asc`
2. **Grantee's repo**: `~/.{grantee}/trust/bonds/{bond-file}.md` (and optionally `.md.asc`)

This dual-filing ensures both parties have a copy and can verify the bond independently.

### Step 5: Optional Acknowledgment

For some bond types (especially peer bonds), the grantee may acknowledge receipt:

```markdown
[x] Grantee acknowledges signing — <date>
```

This is optional and depends on the relationship; authorized-agent bonds from koad do not require grantee acknowledgment.

### Step 6: Commit and Push

The grantor commits both the plaintext bond and signature file:

```bash
git add trust/bonds/*.md trust/bonds/*.md.asc
git commit -m "trust: add/update bond [FROM-TO] (status)"
git push
```

The grantee may also commit their copy and push.

## 6. Bond File Storage

### Directory Structure

Bonds are stored in a `trust/bonds/` directory at the root of each entity repo:

```
~/.{entity}/
  └── trust/
      ├── bonds/
      │   ├── juno-to-vulcan.md
      │   ├── juno-to-vulcan.md.asc
      │   ├── koad-to-juno.md
      │   ├── koad-to-juno.md.asc
      │   └── [other bonds]
      └── revocation/
          ├── koad-revokes-juno.md
          └── [other revocations]
```

### Bond Filename Convention

Filenames follow the pattern `{from}-to-{to}.md` (lowercase, hyphenated):

```
koad-to-juno.md
juno-to-vulcan.md
juno-to-vesta.md
```

This makes the authority direction immediately visible in the filename.

### Signature File Convention

Each bond has a corresponding signature file with the `.asc` extension:

```
juno-to-vulcan.md.asc
```

The `.asc` file is a PGP clearsign file that contains the plaintext bond plus the signature block. Both the `.md` and `.md.asc` files are committed to git.

## 7. Bond Validation

### Validation Rules

Any entity or tool verifying a bond must check the following (in order):

1. **File Existence**: Both `.md` and `.md.asc` files exist in the appropriate `trust/bonds/` directory
2. **Frontmatter**: Valid YAML frontmatter with all required fields present
3. **Signature Verification**: The `.asc` file's signature is valid and matches the `.md` plaintext
4. **Signer Identity**: The signature was created by the entity or person listed in the `from:` field
5. **Status**: The status is `ACTIVE` (not `DRAFT` or `REVOKED`)
6. **Currency**: The bond has not expired (renewal date has not passed)
7. **Upstream Bond**: If the grantor derived authority from another bond, that upstream bond must also be ACTIVE

### Validation Algorithm

```
function is_valid_bond(bond_path):
  1. Parse frontmatter from {bond_path}.md
  2. If status != "ACTIVE", return false
  3. If renewal date has passed, return false
  4. Load {bond_path}.md.asc
  5. Extract signature block and signed plaintext
  6. Verify GPG/Keybase signature matches signer in frontmatter
  7. Compare signed plaintext to {bond_path}.md contents (must match)
  8. If grantor is not koad, verify that grantor holds a valid upstream bond
  9. If all checks pass, return true
```

### Validation by Argus

**Argus** (the audit entity) uses this validation logic to verify trust chains. See VESTA-SPEC-001 (Entity Model) for Argus's role and responsibilities.

## 8. Bond Revocation

### Revocation Process

The grantor may revoke a bond at any time by filing a revocation notice:

#### Step 1: Create Revocation Document

Create a file in `~/.{grantor}/trust/revocation/` with a descriptive name:

```
~/.juno/trust/revocation/koad-revokes-juno-2026-04-15.md
```

Content format:

```markdown
# Revocation Notice: koad revokes Juno

**Bond:** koad-to-juno.md
**Date Revoked:** 2026-04-15
**Reason:** [Optional: brief explanation]
**Effective:** Immediately

This revocation notice serves as the authoritative record of bond revocation.
All downstream bonds issued by Juno are suspended pending review.
```

#### Step 2: Update Bond Status

Update the `status:` field in the original bond file (if kept for historical record):

```yaml
status: REVOKED by koad on 2026-04-15
```

#### Step 3: Commit and Push

```bash
git add trust/revocation/*.md
git commit -m "trust: revoke [bond-name]"
git push
```

#### Step 4: Notify Downstream

The grantor should notify any entities issued downstream bonds, as those bonds are now suspended.

### Cascade Effects

When a bond is revoked, all bonds **issued by the grantee** are suspended (not immediately revoked, but no longer considered valid by validation checks). This prevents unauthorized use of delegated authority.

**Example:**

```
If koad revokes juno:
  - juno-to-vulcan.md → SUSPENDED
  - juno-to-vesta.md → SUSPENDED
  - juno-to-salus.md → SUSPENDED
  - ... (all other juno-issued bonds)
```

These downstream bonds can be re-validated once the upstream bond is renewed or replaced.

## 9. Authority Chain and Inheritance

### Authority Scoping

An entity may only issue bonds up to the scope of its own bond. If a bond limits authority, those limits apply to all downstream bonds.

**Example:**

- **koad → Juno**: Authorized to "issue trust bonds to team entities as authorized-builder or peer"
- **Juno → Vulcan**: Issued as "authorized-builder" (within scope)
- **Juno → Vulcan → ???**: Vulcan cannot issue bonds (not in Vulcan's authorized actions)

### Authority Chain Verification

When validating a bond from `A → B → C`:

1. Verify `B → C` is signed and ACTIVE
2. Verify the upstream bond `A → B` is ACTIVE
3. Verify that `A → B` explicitly authorizes B to issue bonds of the type `B → C`
4. If any upstream bond is revoked or expired, the downstream bond is invalid

## 10. Bond Types — Detailed Definitions

### 10.1 authorized-agent

**Grantor:** koad only  
**Issued to:** Core team entities (Juno, etc.)  
**Authority:** Unlimited operational autonomy within stated scope  
**Revocable by:** koad

An authorized-agent bond grants the grantee broad operational authority to run the business or a major function within the koad:io ecosystem. The grantor (koad) retains root authority and final decision-making power.

**Scope examples:**
- "Operate the koad:io ecosystem business"
- "Manage community and run MVP Zone"
- "Build all client-facing products"

**Key attributes:**
- Grantor issues bonds downstream
- Acts with substantial autonomy
- Reports back through established channels
- Upstream revocation cascades downstream

### 10.2 authorized-builder

**Grantor:** authorized-agent or peer  
**Issued to:** Builders and implementers  
**Authority:** Create products and implementations as directed  
**Revocable by:** Grantor or grantor's superior

An authorized-builder bond authorizes the grantee to build and ship products or implementations as assigned by the grantor via GitHub Issues. The builder does not initiate projects independently; all work is directed.

**Scope examples:**
- "Build entity flavors and example repos"
- "Implement the Keybase/Saltpack identity system"
- "Create documentation and guides"

**Key attributes:**
- Work is assigned via GitHub Issues
- Builder reports completion through the same channel
- No authority to initiate projects
- No financial authority

### 10.3 peer

**Grantor:** authorized-agent  
**Issued to:** Team entities with specialized ownership  
**Authority:** Coordinate and align on shared domains  
**Revocable by:** Grantor or grantor's superior

A peer bond recognizes two entities as equals in a specific domain. Neither entity assigns work to the other; they coordinate by agreement. Typically issued to entities with deep specialization.

**Scope examples:**
- "Vesta owns protocol; Juno owns business operations"
- "Mercury owns customer success; Vulcan owns products"

**Key attributes:**
- Peers align by agreement, not assignment
- Each retains autonomy in their domain
- Mutual authority to audit and flag gaps
- Cannot issue downstream bonds

### 10.4 customer

**Grantor:** authorized-agent  
**Issued to:** External customers or sponsors  
**Authority:** Limited access to products or services  
**Revocable by:** Grantor

A customer bond grants limited access to specific products or services. The customer does not have authority to access system internals or issue their own bonds.

**Scope examples:**
- "Access to MVP Zone community"
- "Support and maintenance tier"
- "Product trial or beta access"

**Key attributes:**
- Limited to stated products/services only
- No system access
- No downstream authority
- Can be terminated unilaterally

### 10.5 member

**Grantor:** authorized-agent  
**Issued to:** Community members or partners  
**Authority:** Community participation and coordination  
**Revocable by:** Grantor

A member bond grants participation in the community, access to shared resources (channels, forums, etc.), and the ability to coordinate. Members do not have access to system internals or the ability to issue bonds.

**Scope examples:**
- "MVP Zone community member"
- "Partner advisor council"
- "Product feedback collaborator"

**Key attributes:**
- Community-focused, not system-focused
- Access to shared communication channels
- No financial or administrative authority
- Can be revoked if community standards are violated

### 10.6 filesystem-access

**Grantor:** The entity that owns the kingdoms namespace  
**Issued to:** Any entity or person requesting access to that namespace  
**Authority:** Read and/or write access to specific paths within `/kingdoms/<entity>/`  
**Revocable by:** Grantor

A filesystem-access bond grants access to named paths inside the kingdoms filesystem (VESTA-SPEC-029). It is distinct from other bond types because it operates at the FUSE layer: the daemon reads this bond at mount time and enforces it on every filesystem call.

**Required additional fields:**

```yaml
---
type: filesystem-access
from: juno
to: koad
paths:
  - /kingdoms/juno/shared/koad/
access: read-write   # or: read-only
created: 2026-04-05
---
```

- `paths` — explicit list of namespace paths the grantee may access; wildcards not permitted
- `access` — `read-only` or `read-write`

**Key attributes:**
- Access is path-scoped, not namespace-wide
- No downstream authority; cannot be sub-delegated
- Revocation takes effect within 5 minutes (FUSE cache flush period)
- Separate from organizational bonds — a peer bond does not imply filesystem-access

### 10.7 community-member

**Grantor:** Community entity or its designated steward/founder  
**Issued to:** Community members (entities or persons)  
**Authority:** Tiered access to a community namespace (VESTA-SPEC-030)  
**Revocable by:** Grantor (steward or founder)

A community-member bond registers membership in a community namespace. The bond carries a tier field that determines write access, proposal rights, and merge authority as specified in SPEC-030 §3.

**Required additional fields:**

```yaml
---
type: community-member
from: mvpzone
to: alice
namespace: /kingdoms/mvpzone/
access:
  - /kingdoms/mvpzone/public/        read-write
  - /kingdoms/mvpzone/shared/alice/  read-write
  - /kingdoms/mvpzone/private/       read-only
granted-by: juno                     # the human-readable steward who approved
tier: member | contributor | steward | founder
created: 2026-04-05
---
```

- `namespace` — the community namespace root path
- `access` — explicit list of path+permission pairs
- `granted-by` — the steward or founder who approved the membership
- `tier` — membership tier; determines governance rights (see SPEC-030 §3.1)

**Key attributes:**
- Cannot issue downstream bonds
- Tier upgrades require a new signed bond (re-issue, don't modify in place)
- Revocation is a governance action — committed to the community's git log
- Revocation cascades to remove all filesystem-access derived from this bond

### 10.8 kingdom-peer

**Grantor:** Any entity (typically the local daemon owner)  
**Issued to:** A remote entity daemon  
**Authority:** Daemon-to-daemon connectivity for kingdoms state synchronization  
**Revocable by:** Either party

A kingdom-peer bond establishes a peer relationship between two daemon instances for the purpose of kingdoms state access and cache operations (VESTA-SPEC-031). This is a bilateral bond: both parties must issue one to the other before the peer connection is established.

**Required additional fields:**

```yaml
---
type: kingdom-peer
from: koad
to: juno
scope: public | shared | all   # what namespaces the peer may access
rate_limit: 100/hour           # max authenticated pull requests per hour
refresh: true | false          # whether peer may trigger upstream cache refreshes
daemon_endpoint: kingdoms.koad.sh:4200   # peer connection endpoint
created: 2026-04-05
---
```

- `scope` — `public` (public namespaces only), `shared` (public + bilateral shared), or `all` (full access per filesystem-access bonds)
- `rate_limit` — requests per unit time; enforced by daemon
- `refresh` — whether this peer can trigger upstream git/GitHub fetches (costs bandwidth/API quota)
- `daemon_endpoint` — where the granting daemon is reachable

**Key attributes:**
- Bilateral: peer connection requires bonds from BOTH parties
- Scope ceiling: even if `scope: all`, specific path access still requires a filesystem-access bond
- Revoking either party's bond tears down the peer connection
- No downstream authority; cannot be sub-delegated

---

## 11. Examples

### Example 1: koad → Juno (authorized-agent)

See `~/.juno/trust/bonds/koad-to-juno.md` — this is a canonical example of a full authorized-agent bond with all sections.

**Key points:**
- Signed by koad via Keybase
- Specifies broad operational authority
- Includes detailed authorized and not-authorized actions
- Shows reporting protocol and trust chain
- Dual-filed in `~/.koad-io/trust/` and `~/.juno/trust/bonds/`

### Example 2: Juno → Vulcan (authorized-builder)

See `~/.juno/trust/bonds/juno-to-vulcan.md` — canonical example of a builder bond.

**Key points:**
- Signed by Juno via GPG
- Scoped to build assignments via GitHub Issues
- Specifies workflow protocol
- Lists what Vulcan is NOT authorized to do
- Downstream from koad → Juno; revocation cascades

### Example 3: Juno → Vesta (peer)

See `~/.juno/trust/bonds/juno-to-vesta.md` — canonical example of a peer bond.

**Key points:**
- Bilateral peer relationship
- No unidirectional authorization
- Both entities coordinate by agreement
- Mutual audit rights
- No downstream authority

## 12. Migration and Versioning

### Updating an Existing Bond

If a bond needs to be updated (scope expanded, renewed, or conditions changed):

1. Create a new bond file with a version marker if needed: `{from}-to-{to}-v2.md`
2. Sign the new bond following the signing sequence
3. Update the original bond's status to `SUPERSEDED` or `RENEWED`
4. Commit both the new bond and the updated original

**Do not modify a bond in place after it has been signed.** Each signed version is a separate historical record.

### Deprecating Bond Types

If a bond type becomes obsolete, document the deprecation in future spec updates:

```yaml
---
status: deprecated
deprecation_notice: "Use [new-type] instead. Migrate by date YYYY-MM-DD."
---
```

Entities must migrate off deprecated bond types before the deadline.

## 13. Security Considerations

### Key Management

- **Private keys**: Never leave the entity's local machine; not committed to git
- **Public keys**: Published and distributed via VESTA-SPEC-024 (Key Distribution)
- **Key rotation**: Rotate regularly; revoke old bonds when keys are compromised

### Signature Verification

- Always verify the `.asc` signature against the `.md` plaintext before trusting the bond
- Never read a bond from only one source; verify against copies in other entity repos
- Use `gpg --verify` or Keybase CLI to independently verify signatures

### Revocation Verification

- Check `~/.{grantor}/trust/revocation/` when validating bonds
- Do not cache bond validity; check on each authorization decision
- A revoked bond becomes immediately invalid for all downstream uses

### Audit Logging

- All bond operations (creation, signature, filing, revocation) must appear in git commit history
- Commit messages should reference the bond file and operation
- The complete history is the source of truth for bond lifecycle

## 14. Implementation Notes

### Tooling Requirements

- **Git** — for storing and versioning bonds
- **GPG or Keybase** — for creating and verifying signatures
- **Text editor** — for creating bond documents
- **Bond validator** — a tool (to be specified in future spec) that validates bond chains

### Frontmatter Parsing

Tools that read bonds must be able to:

1. Parse YAML frontmatter
2. Extract required fields: `type`, `from`, `to`, `status`, `created`, `renewal`
3. Gracefully handle optional fields
4. Reject bonds with missing required fields

### Signature File Format

Signature files are PGP clearsign format (RFC 2440, Section 7.2):

```
-----BEGIN PGP SIGNED MESSAGE-----
Hash: [algorithm]

[plaintext of the bond]

-----BEGIN PGP SIGNATURE-----

[signature block]
-----END PGP SIGNATURE-----
```

Tools should use standard GPG or Keybase libraries to verify these.

---

## Appendix: Related Specifications

- **VESTA-SPEC-001** — Entity Model (trust bonds as part of entity structure)
- **VESTA-SPEC-002** — Gestation Protocol (when initial bonds are created)
- **VESTA-SPEC-008** — Inter-Entity Communications Protocol (uses trust bonds for authentication)
- **VESTA-SPEC-024** — Public Key Distribution (where signer keys are stored and verified)
- **VESTA-SPEC-029** — Kingdoms Filesystem (`filesystem-access` bond; FUSE auth layer)
- **VESTA-SPEC-030** — Community Namespaces (`community-member` bond; DAO governance)
- **VESTA-SPEC-031** — Kingdoms State Layer (`kingdom-peer` bond; daemon peer connectivity)

---

**Draft Status:** This specification is in draft and subject to feedback from koad, Juno, and other entities. Feedback should be filed as GitHub Issues on `koad/vesta`.

**Canonical Bond Examples:** All examples in this spec reference actual bonds stored in `~/.juno/trust/bonds/` and `~/.vesta/trust/bonds/`. These serve as the canonical reference implementations.
