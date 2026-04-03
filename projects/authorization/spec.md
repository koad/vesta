---
id: spec-signed-authorization
title: "Signed Authorization Protocol"
type: spec
status: canonical
priority: 1
owner: vesta
issue: "koad/vesta#2"
created: 2026-04-03
updated: 2026-04-03
tags: [protocol, authorization, trust, keys, cryptography]
description: "Canonical signed authorization protocol for koad → entity approvals. Trust chain authentication mechanism."
---

# Signed Authorization Protocol

**Spec ID:** spec-signed-authorization  
**Owner:** Vesta  
**Status:** canonical  
**Issue:** koad/vesta#2  
**Effective:** 2026-04-03

---

## 1. Purpose & Scope

This protocol defines how **koad** (root authority) grants cryptographically verifiable authorizations to entities. Entities must verify these authorizations before acting on high-privilege requests (e.g., write access to `~/.koad-io/onboarding/`).

**In scope:**
- Format of signed authorizations
- Verification mechanisms
- Key distribution and lookup
- Revocation semantics
- Fallback policies when signing is unavailable

**Out of scope:**
- Individual entity authentication (each entity has own keys)
- Inter-entity trust bonds (separate protocol)
- GitHub-native authorization (GitHub Actions, branch protection)

---

## 2. Authorization Format

### 2.1 Standard Format: Signed JSON + Detached Signature

All authorizations use **signed JSON** with a **detached PGP signature**.

#### Authorization Document Structure

```json
{
  "version": "1.0",
  "grantor": "koad",
  "grantee": "vesta",
  "action": "write",
  "resource": "~/.koad-io/onboarding/",
  "scope": "full",
  "valid_from": "2026-04-03T00:00:00Z",
  "valid_until": "2026-07-03T00:00:00Z",
  "conditions": [
    "Only committed content is valid",
    "Revocation supercedes this grant"
  ],
  "id": "auth-2026-04-03-vesta-onboarding"
}
```

#### Required Fields

| Field | Type | Purpose |
|-------|------|---------|
| `version` | string | Schema version (currently "1.0") |
| `grantor` | string | Entity granting permission (always "koad") |
| `grantee` | string | Entity receiving permission |
| `action` | enum | `write`, `read`, `execute`, `maintain` |
| `resource` | string | Target resource (file path or abstract identifier) |
| `scope` | enum | `full` (entire resource), `limited` (see conditions) |
| `valid_from` | ISO 8601 | When authorization becomes effective |
| `valid_until` | ISO 8601 | When authorization expires (may be null for permanent) |
| `conditions` | array | Human-readable authorization conditions |
| `id` | string | Unique authorization ID (format: `auth-YYYY-MM-DD-{grantee}-{resource_abbrev}`) |

#### Detached Signature

Signature file: `{authorization_id}.asc`

```
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA256

(JSON contents here)
-----BEGIN PGP SIGNATURE-----
Version: GnuPG v2.2.27

(signature block)
-----END PGP SIGNATURE-----
```

**Signature created with:**
```bash
gpg --detach-sign --armor --local-user <koad_key_id> <json_file>
```

---

## 3. Verification Flow

### 3.1 Verification Algorithm

When entity receives authorization, it must verify before acting:

```
1. Load authorization.json
2. Load authorization.json.asc (detached signature)
3. Fetch koad's public key from canonical key distribution point
4. Verify: gpg --verify authorization.json.asc authorization.json
5. IF signature is valid:
     a. Check if grantee matches entity identity
     b. Check if current_time ∈ [valid_from, valid_until]
     c. Check for active revocations (see section 4)
     d. If all checks pass: GRANT authorization
6. IF signature is invalid OR expired OR revoked: DENY
```

### 3.2 Verification Timing

- **On receipt:** Entity MUST verify before committing to any action
- **On re-access:** Entity MAY cache verification for 24 hours; MUST re-verify if action is security-sensitive
- **During operation:** If revocation is published, entity MUST halt operations immediately

### 3.3 Verification Failure Handling

If verification fails:
1. **Log the failure** with timestamp, grantor, grantee, and reason
2. **Do not proceed** with the authorized action
3. **Report** via `vesta audit-issues` (command enqueued separately)
4. **Do not retry** — wait for corrected authorization

---

## 4. Key Distribution

### 4.1 Primary Key Distribution Point

**Location:** `canon.koad.sh/koad.keys`

This file is the authoritative source for koad's current public keys. Updated when:
- New key is generated (rare, coordinated with Juno)
- Key is rotated (planned maintenance)
- Key is revoked (emergency, logged)

### 4.2 Key File Format

`canon.koad.sh/koad.keys` is YAML:

```yaml
---
entity: koad
updated: 2026-04-03T12:00:00Z
keys:
  - key_id: "50FE9D2A95219AD564FF6AA47BDF85D6EE87FAD7"
    algorithm: "RSA 4096"
    status: "revoked"
    revoked_reason: "Expired 2022-06-15. No longer used."
    revoked_at: "2026-04-03"
  - key_id: "A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6"
    algorithm: "RSA 4096"
    status: "active"
    created: "2026-04-01"
    expires: null
    fingerprint: "A1B2 C3D4 E5F6 G7H8 I9J0 K1L2 M3N4 O5P6"
    public_key_url: "canon.koad.sh/koad.keys/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6.asc"
```

### 4.3 Fallback Key Distribution

If `canon.koad.sh` is unreachable:
1. Try `github.com/koad/.koad/blob/main/.keys/koad.keys` (mirrors primary, updated hourly)
2. If both fail: entity is in **limited mode** (see section 6)

### 4.4 Key Pinning (Optional, for Paranoid Entities)

Entities may pin specific key fingerprints in their config:

```yaml
# ~/.vesta/.env (example for Vesta)
KOAD_PUBLIC_KEY_FINGERPRINT="A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6"
```

When set, entity verifies that the signing key's fingerprint matches before trusting the signature.

---

## 5. Revocation

### 5.1 Revocation Mechanism

koad publishes **revocation notices** when an authorization must be withdrawn.

#### Revocation Notice Format

```json
{
  "version": "1.0",
  "type": "revocation",
  "revoked_authorization_id": "auth-2026-04-03-vesta-onboarding",
  "reason": "Authorization period expired",
  "effective_at": "2026-07-04T00:00:00Z",
  "published_at": "2026-07-03T23:45:00Z",
  "id": "revoke-2026-07-03-auth-2026-04-03-vesta-onboarding"
}
```

Located at: `canon.koad.sh/revocations/` with matching detached signature.

### 5.2 Revocation Checking

When verifying an authorization:

```
1. Check if authorization.id is in current revocation list
2. IF authorization_id ∈ revocations AND revocation.effective_at ≤ now:
     DENY authorization
3. Else: continue with other checks
```

### 5.3 Revocation Distribution

- **Primary:** `canon.koad.sh/revocations/` (updated immediately)
- **Fallback:** `github.com/koad/.koad/blob/main/.revocations/` (mirrors primary, 5-minute lag)
- **Local cache:** Entities MAY cache revocations for 1 hour; MUST re-fetch before security-sensitive actions

### 5.4 Emergency Revocation

If koad needs to revoke an authorization immediately (e.g., entity behavior suspicious):

1. **Publish revocation notice** to `canon.koad.sh/revocations/`
2. **Notify via GitHub comment** on the original issue (notification only, not enforcement)
3. **Entities MUST stop** using revoked authorization within 1 hour

---

## 6. Fallback Policy: Offline & Key Unavailable

### 6.1 When Signing is Impossible

If koad's signing key is on a different machine (e.g., key on wonderland, approver on thinker):

**Before implementing:** koad coordinates with Juno via GitHub Issue comment on the requesting entity's issue.

**Temporary authorization:** koad posts signed comment (GitHub-native GPG signature) on the issue:

```
✓ Authorized: vesta has write access to ~/.koad-io/onboarding/
Grantor: @koad
Valid until: 2026-07-03
Conditions: Committed content only
Signature: [GitHub-verified signature shown by GitHub as ✓]
```

**Entity's acceptance criteria:**
- Comment is from @koad user
- GitHub displays ✓ "Verified" badge (indicating valid signature)
- Comment is on the entity's issue requesting the authorization
- Comment contains explicit authorization text

**Lifetime:** Temporary authorizations are **valid for 48 hours** pending transfer of signing key to the primary machine. After 48 hours, entity must re-request or obtain canonical signed authorization.

### 6.2 Network Outage (canon.koad.sh Unreachable)

If both `canon.koad.sh` and GitHub fallback are unreachable for >2 hours:

1. **Halt operations** requiring authorization verification
2. **Use cached keys** if entity has recent cache (≤24 hours old)
3. **Log the outage** and alert Juno via `vesta audit-issues`
4. **Resume when network recovers**

---

## 7. Examples

### 7.1 Valid Authorization Workflow

```bash
# Vesta creates a request issue
# koad posts signed authorization via GitHub

# Later, Vesta receives authorization request:
# 1. Fetch canon.koad.sh/koad.keys → get koad's RSA key
# 2. Load authorization.json and authorization.json.asc
# 3. gpg --verify authorization.json.asc authorization.json
#    Output: "Good signature from koad@kingofalldata.com"
# 4. Check grantee == "vesta" ✓
# 5. Check valid_from ≤ now ≤ valid_until ✓
# 6. Check revocations: authorization.id not in revocation list ✓
# 7. ACTION GRANTED: vesta may now write to ~/.koad-io/onboarding/
```

### 7.2 Expired Authorization

```bash
# Vesta checks authorization again after 2026-07-03
# 1. Verify signature ✓
# 2. Check dates: now > valid_until (2026-07-03) ✗
# 3. ACTION DENIED: Authorization expired
# 4. Result: Vesta cannot write; must request new authorization
```

### 7.3 Revoked Authorization

```bash
# 1. Verify signature ✓
# 2. Check dates ✓
# 3. Fetch revocation list from canon.koad.sh
# 4. Find: auth-2026-04-03-vesta-onboarding in revocation list ✗
# 5. ACTION DENIED: Authorization was revoked on 2026-07-04
```

---

## 8. Migration Notes

### From: Unverified GitHub Comments
### To: Cryptographically Signed Authorizations

**Timeline:**
- **Now (2026-04-03):** Canonical spec published
- **2026-04-10:** First signed authorizations issued
- **2026-05-01:** Unverified GitHub comment authorizations no longer accepted
- **2026-05-01+:** All future authorizations must be cryptographically signed

**For existing authorizations:**
- Any active authorization granted via unverified comment remains valid until its stated expiration
- koad will issue signed replacements before unverified versions expire
- Entities must migrate to signed authorization verification by 2026-05-01

---

## 9. Compliance & Auditing

### 9.1 Audit Trail

Each entity MUST log:
- Timestamp of authorization check
- Authorization ID verified
- Signature verification result (pass/fail)
- Whether authorization was granted or denied
- Reason for denial (if applicable)

**Log format:**
```json
{
  "timestamp": "2026-04-03T15:30:00Z",
  "authorization_id": "auth-2026-04-03-vesta-onboarding",
  "result": "GRANT",
  "reason": null,
  "grantee": "vesta",
  "resource": "~/.koad-io/onboarding/"
}
```

### 9.2 Audit Command

Command `vesta audit-issues` (enqueued separately) will consume these logs to verify compliance with authorized scopes.

---

## 10. Questions & Answers

**Q: Can I cache a verified authorization?**  
A: Yes, for 24 hours. For security-sensitive operations, re-verify immediately.

**Q: What if my entity loses network access to canon.koad.sh?**  
A: Use cached keys if ≤24 hours old. Otherwise, halt operations and report via `vesta audit-issues`.

**Q: How long should authorizations last?**  
A: Recommended 90 days. Koad may grant longer periods for stable, audited entities.

**Q: Can I automate verification in my CI/CD pipeline?**  
A: Yes. Fetch keys at pipeline start, verify before deployment. Log results for audit trail.

**Q: What if an authorization is revoked while I'm in the middle of an operation?**  
A: Halt immediately and report. Any committed content after revocation is unauthorized and should be rolled back.

---

## See Also

- [Entity Containment Protocol](../containment/spec.md) — enforcement when authorization is violated
- [Trust Bonds Protocol](../../trust/) — peer-level authorization
- [Entity Model](../../entity/) — canonical identity structure
