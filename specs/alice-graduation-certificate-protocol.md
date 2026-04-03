---
title: "Alice Graduation Certificate Protocol"
spec-id: VESTA-SPEC-015
status: draft
created: 2026-04-03
author: Vesta (vesta@kingofalldata.com)
reviewers: [koad, Juno, Alice]
related-issues: [koad/juno#8, koad/vesta#XX]
---

# Alice Graduation Certificate Protocol

## 1. Overview

### What It Is

A **graduation certificate** is a cryptographically signed trust bond issued by Alice to a human who has completed the 12-level onboarding curriculum. The certificate is:

- **Proof of mastery**: The graduate understands koad:io philosophy and has demonstrated competence across all 12 levels
- **Authorization bond**: It cryptographically proves Alice vouches for the graduate; it is the graduate's first cryptographic credential in koad:io
- **Juno's credential**: When Juno sees an Alice-signed certificate, Juno knows to treat the holder as a sovereign operator ready to build their kingdom
- **Unforgeable**: Signed by Alice's Keybase identity (saltpack signature); cannot be faked or modified

### Design Principles

- **Verifiable on-chain or offline**: Certificate verification doesn't require network; Keybase public key is canonical
- **Human-readable**: Certificate is markdown with detached signature, not an opaque token
- **Minimal data**: Contains only what Juno needs: identity, levels completed, date, issuer signature
- **Revocable**: Alice can revoke a certificate if circumstances change; revocation is published
- **Portable**: Graduate carries it; becomes first document in their kingdom's trust directory

### The Funnel

```
Stranger → Alice (12 levels) → Graduation Certificate (Alice signs)
    ↓
Juno (sees certificate) → "Welcome to sovereignty"
    ↓
Graduate builds kingdom (with Juno's guidance)
```

---

## 2. Certificate Document Format

### 2.1 File Naming and Location

**Graduate's copy:**
```
~/<GRADUATE_KINGDOM>/.trust/bonds/alice-graduation-<DATE>-<HASH>.md
```

Example:
```
~/mykin/.trust/bonds/alice-graduation-2026-04-10-abc123.md
```

**Alice's copy (archive):**
```
~/.alice/certificates/issued/<GRADUATE_NAME>-<DATE>.md
~/.alice/certificates/issued/<GRADUATE_NAME>-<DATE>.md.asc
```

**Juno's copy (registry):**
```
~/.juno/registry/graduates/<GRADUATE_NAME>-<DATE>.md (signed)
```

All copies are identical documents with identical signatures.

### 2.2 Frontmatter

Every graduation certificate begins with YAML frontmatter:

```yaml
---
type: graduation-certificate
from: Alice (Alice <alice@kingofalldata.com>)
to: <GRADUATE_FULL_NAME> (<GRADUATE_EMAIL>)
status: ACTIVE | REVOKED
issued: <YYYY-MM-DD>
expires: never
certificate-hash: <SHA256_FIRST_16_CHARS>
signature-type: keybase/saltpack
signature-verified-by: Juno, koad
---
```

**Field definitions:**

| Field | Meaning |
|-------|---------|
| `type` | Always `graduation-certificate` (distinguishes from other trust bonds) |
| `from` | Alice's name, email, Keybase identity |
| `to` | Graduate's full name and email (as they will be known in koad:io) |
| `status` | ACTIVE (valid credential) or REVOKED (certificate withdrawn) |
| `issued` | Date Alice signed the certificate (graduation date) |
| `expires` | Always `never` — graduation doesn't expire, but can be revoked |
| `certificate-hash` | SHA256(document content) first 16 chars for quick reference |
| `signature-type` | Always `keybase/saltpack` (canonical signing protocol per VESTA-SPEC-015) |
| `signature-verified-by` | Who has verified this signature; initially Juno and koad |

### 2.3 Certificate Sections

Every graduation certificate contains these sections in order:

#### 2.3.1 Certificate Statement

Alice's attestation in first person:

```markdown
## Certificate Statement

I, Alice, vouch for <GRADUATE_NAME> as a sovereign operator ready to join the koad:io peer ring.

<GRADUATE_NAME> has completed all 12 levels of the koad:io curriculum with demonstrated understanding:
- They understand sovereignty and what it means to be the king/queen of their own data
- They comprehend the entity model and can reason about identity on disk
- They know how to create trust bonds and establish peer rings
- They've built their first command and gestated their first entity
- They've experienced the power and responsibility of the daemon

I grant this certificate as my trust bond to <GRADUATE_NAME>. It authorizes them to:
- Introduce themselves to Juno as my student
- Begin building their kingdom on koad:io
- Enter the peer ring and coordinate with other sovereigns
- Access all public documentation and specs

By holding this certificate, <GRADUATE_NAME> joins the fellowship. They are accountable for their kingdom and answerable to the koad:io ethos: sovereignty, privacy, and the freedom to build.
```

#### 2.3.2 Curriculum Completion

Record which levels were completed and demonstrated:

```markdown
## Curriculum Completion

| Level | Topic | Completed | Verified |
|-------|-------|-----------|----------|
| 1 | Sovereignty: The Problem koad:io Solves | ✓ | 2026-04-02 |
| 2 | The Entity Model: Files, Identity, Keys | ✓ | 2026-04-02 |
| 3 | Keys and Identity: Your Agent | ✓ | 2026-04-02 |
| 4 | The Daemon: Your Kingdom Hub | ✓ | 2026-04-03 |
| 5 | Commands and Skills: How Entities Act | ✓ | 2026-04-03 |
| 6 | Trust Bonds: Governance on Disk | ✓ | 2026-04-03 |
| 7 | Peer Rings: Sovereignty + Connection | ✓ | 2026-04-04 |
| 8 | The Portal: Your Kingdom as Doorway | ✓ | 2026-04-04 |
| 9 | Build Your First Command (Hands-On) | ✓ | 2026-04-05 |
| 10 | Gestate Your First Entity (Hands-On) | ✓ | 2026-04-05 |
| 11 | Build Your Team: Orchestration | ✓ | 2026-04-06 |
| 12 | Mastery: Your Kingdom is Live | ✓ | 2026-04-07 |

**Mastery demonstrated:** <GRADUATE_NAME> has shown understanding across all domains. They are ready.
```

#### 2.3.3 Graduate Profile

Basic information about the graduate for Juno's first contact:

```markdown
## Graduate Profile

- **Name:** <FULL_NAME>
- **Email:** <EMAIL>
- **Cohort:** <MONTH_YEAR> (e.g., "April 2026")
- **Time to mastery:** <NUMBER> hours (approximately)
- **Primary interest:** <BRIEF_DESCRIPTION> (e.g., "building a media archive on their own terms")
- **Kingdom name:** <IF_CHOSEN> or "TBD"
- **Sponsor/Referrer:** <IF_APPLICABLE> or "Direct (no referral)"

**Personal statement from graduate:**
> <GRADUATE_PROVIDES_SHORT_DESCRIPTION_OF_THEIR_JOURNEY_AND_GOALS>

**Alice's notes:**
> <ALICE_OBSERVATIONS_ABOUT_GRADUATE'S_ENGAGEMENT_AND_READINESS>
```

#### 2.3.4 Trust Chain

Shows the delegation path from koad to Alice to the graduate:

```markdown
## Trust Chain

koad (root authority)
  └── Alice (disciple, ambassador)
        └── <GRADUATE_NAME> (sovereign — certificate issued 2026-04-07)
```

This makes explicit: the graduate is now recognized in the koad:io hierarchy.

#### 2.3.5 What This Certificate Authorizes

Clear statement of what the graduate can now do:

```markdown
## Authorized Actions

This certificate authorizes <GRADUATE_NAME> to:

- Introduce themselves to Juno as Alice's student
- Request Juno's guidance in building their kingdom
- Access all public koad:io specs and documentation
- Participate in peer rings with other koad:io sovereigns
- Deploy and run entities on their own infrastructure
- Create and manage their own trust bonds (within koad:io ethics)
- File issues and participate in koad:io protocol discussions

This certificate does NOT authorize:

- Access to private koad:io infrastructure (only through explicit permission)
- Authority to issue new trust bonds on behalf of koad (only their own)
- Ability to revoke or override other entities' decisions
- Public representation of koad:io without explicit delegation
```

### 2.4 Signature Block

After the content, the certificate includes a detached signature:

```markdown
---

## Signature

This certificate is signed by Alice using her Keybase identity and saltpack armor format.

**Signature verification:**
```bash
keybase verify -i alice-graduation-2026-04-07-abc123.md.asc -m alice-graduation-2026-04-07-abc123.md
# Output: alice: ✓ signature is valid
```

**Alice's Keybase profile:** https://keybase.io/alice_koadio

**Revocation:** To check if this certificate has been revoked, see Alice's certificate revocation list at ~/.alice/certificates/revoked/

---

*Certificate issued 2026-04-07 by Alice (alice@kingofalldata.com). Signature: [KEYBASE_SALTPACK_ARMOR_BLOCK]*
```

---

## 3. Signing and Distribution Procedure

### 3.1 Alice's Signing Process

When a graduate completes all 12 levels:

```bash
# 1. Prepare certificate document (markdown)
cat > /tmp/alice-graduation-<DATE>.md <<'EOF'
[certificate content as per Section 2.2-2.4]
EOF

# 2. Sign with Alice's Keybase identity
keybase sign -m /tmp/alice-graduation-<DATE>.md > /tmp/alice-graduation-<DATE>.md.asc

# 3. Verify signature is valid
keybase verify -i /tmp/alice-graduation-<DATE>.md.asc -m /tmp/alice-graduation-<DATE>.md

# 4. Move to Alice's archive
mv /tmp/alice-graduation-<DATE>.md ~/.alice/certificates/issued/
mv /tmp/alice-graduation-<DATE>.md.asc ~/.alice/certificates/issued/

# 5. Distribute to graduate
# (Method TBD: Slack, email, secure file transfer — must be authenticated)

# 6. Notify Juno
# Alice files issue on koad/juno with certificate details
gh issue create --repo koad/juno \
  --title "Graduate: <GRADUATE_NAME>" \
  --body "[certificate link and summary]"
```

### 3.2 Graduate Receives Certificate

Graduate receives two files:
- `alice-graduation-2026-04-07-abc123.md` (certificate document)
- `alice-graduation-2026-04-07-abc123.md.asc` (signature)

They store both in their kingdom:
```bash
cd ~/<KINGDOM>
mkdir -p .trust/bonds/
cp alice-graduation-*.md* .trust/bonds/
git add .trust/bonds/
git commit -m "trust: add Alice graduation certificate"
```

### 3.3 Graduate Introduces to Juno

When graduate clones their kingdom and meets Juno, they provide the certificate:

```bash
juno introduce \
  --certificate ~/.trust/bonds/alice-graduation-2026-04-07-abc123.md \
  --signature ~/.trust/bonds/alice-graduation-2026-04-07-abc123.md.asc
```

---

## 4. Juno's Verification Sequence

When Juno receives a certificate from a new graduate:

### Step 1: Verify Signature

```bash
keybase verify -i <cert>.asc -m <cert>.md
# Must output: alice: ✓ signature is valid
```

If signature verification fails: **REJECT** certificate. Stop.

### Step 2: Check Revocation

```bash
# Check if Alice has revoked this certificate
grep <CERTIFICATE_HASH> ~/.alice/certificates/revoked/ 2>/dev/null
# If found: REJECT certificate. Stop.
```

### Step 3: Verify Content

Parse frontmatter and verify:
- `type: graduation-certificate` ✓
- `from: Alice` ✓
- `to: <GRADUATE_NAME>` (matches who's asking) ✓
- `status: ACTIVE` ✓
- `issued` date is within acceptable range (not future, not ancient) ✓

### Step 4: Record in Registry

```bash
mkdir -p ~/.juno/registry/graduates/
cp <certificate> ~/.juno/registry/graduates/<GRADUATE_NAME>-<DATE>.md
git add ~/.juno/registry/graduates/
git commit -m "registry: add graduate <GRADUATE_NAME> (Alice cert)"
```

### Step 5: Respond to Graduate

```markdown
Welcome, <GRADUATE_NAME>.

I've verified your graduation certificate. Alice vouches for you, and I trust her judgment.

You've earned sovereignty. Let me help you build your kingdom.

Where should we start?
```

---

## 5. Revocation Protocol

### When Alice Revokes

Alice can revoke a certificate if circumstances change:
- Graduate acts in violation of koad:io ethos
- Fraud discovered (certificate holder is not the graduate)
- Mutual agreement to end relationship

Revocation process:

```bash
# 1. Document reason
cat > ~/.alice/certificates/revoked/<GRADUATE_NAME>-<DATE>.txt <<'EOF'
Certificate: alice-graduation-2026-04-07-abc123
Graduate: <NAME>
Issued: 2026-04-07
Revoked: <NEW_DATE>
Reason: <BRIEF_REASON>
EOF

# 2. Publish revocation hash (to prevent reuse)
echo "abc123" >> ~/.alice/certificates/revoked/REVOCATION_LIST.txt

# 3. Notify Juno
gh issue comment --repo koad/juno \
  --issue <ORIGINAL_ISSUE> \
  --body "Certificate revoked: [details]"

# 4. Commit
git add ~/.alice/certificates/revoked/
git commit -m "trust: revoke certificate for <GRADUATE_NAME>"
```

### When Juno Learns of Revocation

Juno checks revocation list at startup:

```bash
if grep <CERT_HASH> ~/.alice/certificates/revoked/REVOCATION_LIST.txt; then
  REVOKED=true
  # Treat graduate as no longer authorized
  # May contact them to understand situation
fi
```

---

## 6. Integration with Alice and Juno

### Alice's Responsibilities

- Conduct 12-level curriculum with human at their pace
- Verify understanding across all domains
- Issue certificate when graduate demonstrates mastery
- Maintain certificate archive and revocation list
- Respond to questions from graduates post-graduation

### Juno's Responsibilities

- Verify certificates when new graduates arrive
- Maintain registry of verified graduates
- Provide guidance for kingdom building
- Escalate issues (fraud, disputes) to koad
- Never issue certificates (Alice does that)

### Graduate's Responsibilities

- Carry certificate in their kingdom (.trust/bonds/)
- Present certificate when introducing to Juno
- Maintain their kingdom according to koad:io ethos
- Respect the trust Alice placed in them

---

## 7. Related Specifications

- **VESTA-SPEC-007** (Trust Bond Protocol): Certificate follows trust bond format and signing protocol
- **VESTA-SPEC-008** (Cross-Harness Identity): Graduate identity becomes new Keybase identity in koad:io
- **VESTA-SPEC-015** (Keybase/Saltpack Protocol): Signature mechanism for certificates
- **VESTA-SPEC-012** (Entity Startup): Alice is a new operator on graduate's machine; detection and introduction

---

## 8. Future Extensions

Potential future enhancements (not in this draft):

- Certificate re-verification (expires after N years, requires refresh)
- Credential levels (bronze/silver/gold mastery indicators)
- Delegation (graduate can sponsor other humans, with Alice approval)
- Appeal process (if certificate revoked, path to restoration)

---

## Appendix A: Example Certificate

```markdown
---
type: graduation-certificate
from: Alice (Alice <alice@kingofalldata.com>)
to: Sam Chen (sam@chen.sh)
status: ACTIVE
issued: 2026-04-07
expires: never
certificate-hash: f2a3d9e1b8c4a7f9
signature-type: keybase/saltpack
signature-verified-by: Juno, koad
---

# Alice Graduation Certificate

## Certificate Statement

I, Alice, vouch for Sam Chen as a sovereign operator ready to join the koad:io peer ring.

Sam has completed all 12 levels of the koad:io curriculum with demonstrated understanding and hands-on competence. They understand the philosophy, can reason about entities, and have proven they can build and operate their own infrastructure with integrity.

I grant this certificate as my trust bond to Sam Chen.

## Curriculum Completion

| Level | Topic | Completed |
|-------|-------|-----------|
| 1 | Sovereignty | ✓ 2026-03-31 |
| 2 | Entity Model | ✓ 2026-04-01 |
| ... | ... | ✓ |
| 12 | Mastery | ✓ 2026-04-07 |

## Graduate Profile

- **Name:** Sam Chen
- **Email:** sam@chen.sh
- **Primary interest:** Building a personal archive system with sovereign control over data
- **Personal statement:** "I want my data to be mine. Not Google's, not AWS's. Mine."

## Trust Chain

koad (root authority)
  └── Alice (disciple, ambassador)
        └── Sam Chen (sovereign — certificate issued 2026-04-07)
```

---

*Spec status: draft (2026-04-03). Ready for Alice implementation and Juno integration review. Implementation target: Alice curriculum launch (coordinated with kingofalldata.com PWA — Vulcan#7). File issues on koad/vesta for certificate template refinements or policy questions.*
