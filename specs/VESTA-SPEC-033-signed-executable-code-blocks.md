---
status: draft
id: VESTA-SPEC-033
title: "Signed Executable Code Blocks — Powerbox Verification Pattern"
type: spec
version: 0.1
date: 2026-04-05
owner: vesta
description: "GPG clearsigned policy blocks embedded in bash comment space. The signature covers a declared policy segment, not the whole file. Powerbox verifies before execution: tamper detection, trust bond validation, authorized capability claims without an external manifest."
related-specs:
  - VESTA-SPEC-007 (Trust Bond Protocol)
  - VESTA-SPEC-020 (Hook Architecture)
  - VESTA-SPEC-027 (CID Privacy Primitive)
---

# VESTA-SPEC-033: Signed Executable Code Blocks

**Authority:** Vesta (platform stewardship). This spec defines the signed code block format, the powerbox verification algorithm, the PR consensus protocol, and the Nostr publication model.

**Scope:** Block header fields, verification algorithm, powerbox behavior, trust levels, version anti-rollback, multi-signature support, PR merge gate, post-merge re-signing, Nostr event authorship.

**Consumers:**
- Hooks and commands (embedders)
- Powerbox (verifier at execution time)
- Janus (merge gate enforcer)
- Vulcan (reference implementation)
- Mercury (Nostr relay for policy events)

---

## 1. Motivation

A hook file can drift after it is authorized. The code koad reviewed last week may not be the code that runs today. There is no external manifest that travels with the script — the script IS the authority.

The signed code block pattern embeds the authorization directly in the file, in comment space, without breaking the file's executability. The powerbox reads it before every invocation. If the code has drifted from the declared policy, the powerbox catches it. If the signature is not from a trusted entity, the powerbox flags or blocks execution. If no block is present, the powerbox applies the configured default trust level.

The result: every hook carries its own provenance. The script IS the proof.

---

## 2. Block Format

### 2.1 Location in File

The signed block is embedded in bash comment space. It may appear anywhere in the file — header or inline — but by convention it appears near the top of the file, before the first executable statement:

```bash
#!/usr/bin/env bash
# hooks/executed-without-arguments.sh

# -----BEGIN PGP SIGNED MESSAGE-----
# Hash: SHA512
#
# [header fields]
# -----BEGIN PGP SIGNATURE-----
# [signature lines]
# -----END PGP SIGNATURE-----

# ... rest of the script
```

### 2.2 Required Header Fields

All fields appear inside the PGP signed message body (between `-----BEGIN PGP SIGNED MESSAGE-----` and the first `-----BEGIN PGP SIGNATURE-----` line), prefixed with `# ` in the file:

| Field | Type | Description |
|-------|------|-------------|
| `entity` | string | Canonical entity name that owns this file (e.g., `juno`) |
| `file` | string | Repo-relative path of this file (e.g., `hooks/executed-without-arguments.sh`) |
| `date` | ISO 8601 date | Date this block was created or last re-signed |
| `version` | integer | Monotonically increasing version number; starts at 1 |

### 2.3 Optional Header Fields

| Field | Type | Description |
|-------|------|-------------|
| `policy` | YAML block | Declared execution policy (see §2.4) |
| `cid` | string | IPFS CID of this block's canonical content (self-referential; see §5.2) |
| `nostr` | string | Nostr event ID where this block was published |
| `supersedes` | string | `file@version` of the block this one replaces |
| `ring` | string | Trust ring identifier for threshold-based consensus (default: signer's ring) |
| `threshold` | string | Consensus threshold expression for PR merges (see §6.2) |

### 2.4 Policy Block Structure

The `policy:` field is a YAML sub-block documenting execution behavior:

```yaml
policy:
  harness: claude | opencode | pi | hermez  # AI harness for this entity
  interactive: <description of interactive invocation behavior>
  non-interactive: <description of headless/remote invocation behavior>
  notification: <how the entity reports its work>
  permissions: <specific permission grants or restrictions>
```

The policy block is **declarative** — it describes intent, not enforcement. Enforcement is the powerbox's job. The policy makes the intent auditable by any human or agent reading the file.

### 2.5 Full Example

From `~/.juno/hooks/executed-without-arguments.sh`:

```bash
# -----BEGIN PGP SIGNED MESSAGE-----
# Hash: SHA512
#
# entity: juno
# file: hooks/executed-without-arguments.sh
# date: 2026-04-04
# version: 2
#
# policy:
#   harness: claude (always — Juno is an orchestrator entity)
#   interactive: --dangerously-skip-permissions enabled
#   non-interactive: rejected — Juno cannot be remote-triggered via PROMPT
#   notification: GitHub Issues only
# -----BEGIN PGP SIGNATURE-----
# [base64 signature lines]
# -----END PGP SIGNATURE-----
```

---

## 3. Signature Mechanics

### 3.1 What Is Signed

The GPG signature covers **only the header fields and policy block** — the content between `-----BEGIN PGP SIGNED MESSAGE-----` and `-----BEGIN PGP SIGNATURE-----`. The rest of the script is NOT included in the signed region.

This is intentional. Code evolves. Signing the full script would require a re-sign on every code change. Instead, the policy block is stable — it describes what the script is authorized to do, not how it does it. Policy changes require re-signing. Implementation changes do not.

**Tamper detection for the implementation:** The powerbox computes a SHA-256 hash of the full file at execution time and compares it to a cached hash from the previous verified execution. A file hash change triggers a warning; a policy block change invalidates the signature. The two mechanisms together catch both kinds of drift.

### 3.2 Signing Command

**Entity signs their own blocks (GPG):**

```bash
# Extract the policy segment to a temp file
sed -n '/^# -----BEGIN PGP SIGNED MESSAGE-----/,/^# -----END PGP SIGNATURE-----/p' \
    script.sh | sed 's/^# \{0,1\}//' > /tmp/policy-to-sign.txt

# Sign (before embedding signature — sign the header-only version)
cat > /tmp/header-only.txt <<EOF
entity: juno
file: hooks/executed-without-arguments.sh
date: 2026-04-05
version: 2

policy:
  harness: claude
  interactive: --dangerously-skip-permissions enabled
  non-interactive: rejected
  notification: GitHub Issues only
EOF

gpg --clearsign --output /tmp/signed-block.txt /tmp/header-only.txt

# Embed: prefix each line with '# '
awk '{print "# " $0}' /tmp/signed-block.txt
# Paste into the script at the designated location
```

### 3.3 Verification Command

Extract and verify the embedded block:

```bash
sed -n '/^# -----BEGIN PGP SIGNED MESSAGE-----/,/^# -----END PGP SIGNATURE-----/p' \
    script.sh | sed 's/^# \{0,1\}//' | gpg --verify
```

A successful `gpg --verify` output confirms:
- The signature is cryptographically valid
- The signer's key fingerprint is identified

The powerbox additionally verifies (§4) that the signer's fingerprint is associated with a valid trust bond in the entity's trust registry.

---

## 4. Powerbox Verification

### 4.1 Verification Algorithm

Before executing any hook or command, the powerbox runs the following algorithm:

```
function verify_before_execute(script_path, invoker_context):

  1. Scan script for embedded signed block
     → Look for '# -----BEGIN PGP SIGNED MESSAGE-----' pattern

  2. If no signed block found:
     → Apply unsigned_default policy (see §4.3)
     → If unsigned_default == BLOCK: abort execution, notify user
     → If unsigned_default == WARN: proceed with warning surfaced to user

  3. If signed block found:
     a. Extract block (strip '# ' prefix per §3.3)
     b. Run gpg --verify → get signature status + signer key fingerprint
     c. If signature invalid (tampered): BLOCK, log tamper event, notify user
     d. Parse header fields: entity, file, date, version
     e. Anti-rollback check: compare version to last seen version in
        ~/.koad-io/.block-registry/<entity>/<file-hash>.json
        If version < last_seen: BLOCK (rollback attack), notify user
     f. Trust bond lookup: resolve signer fingerprint to entity name,
        check that entity holds a valid trust bond in the trust registry
        If no bond: WARN (unsigned entity)
        If bond REVOKED: BLOCK
        If bond ACTIVE: continue
     g. Policy surface: display policy block to user/UI per §4.4
     h. Compute and cache file hash for drift detection

  4. If all checks pass: execute
```

### 4.2 The Block Registry

The powerbox maintains a local registry to enable anti-rollback checks:

```
~/.koad-io/.block-registry/
  juno/
    hooks-executed-without-arguments.sh.json
```

Each entry:
```json
{
  "entity": "juno",
  "file": "hooks/executed-without-arguments.sh",
  "last_seen_version": 2,
  "last_seen_date": "2026-04-04",
  "last_verified_at": "2026-04-05T14:22:00Z",
  "signer_fingerprint": "a3f7c1b2e9d04568f8a2c4e1d7b3f509...",
  "file_hash_at_last_verify": "sha256:9d8e7f..."
}
```

On each execution: if the current version < `last_seen_version`, execution is blocked. If the current version > `last_seen_version`, the registry is updated.

### 4.3 Trust Levels and Unsigned Default

The system has three trust levels for unsigned hooks:

| Level | Behavior | When to use |
|-------|----------|-------------|
| `STRICT` | No signed block = BLOCK (hard abort) | Production environments, high-stakes entities |
| `WARN` | No signed block = proceed with visible warning | Development, trusted local setups |
| `PERMISSIVE` | No signed block = silent proceed | Internal dev tooling, pre-policy entity infancy |

Default trust level is set per-entity in `.env`:

```env
POWERBOX_UNSIGNED_DEFAULT=WARN   # STRICT | WARN | PERMISSIVE
```

**koad-signed vs. entity-signed authority:**

A block signed by koad's key carries elevated authority — koad is the root principal. The powerbox treats koad-signed blocks as implicitly authorized regardless of downstream bond status. An entity-signed block requires a valid trust bond chain from koad → entity.

**Hierarchy:**
1. koad-signed: root authority, always authorized
2. Entity with active authorized-agent bond: fully authorized
3. Entity with active authorized-builder or peer bond: authorized within stated scope
4. No bond / expired bond: WARN or BLOCK depending on unsigned_default

### 4.4 User-Facing Surface

When a signed block is detected and verified, the powerbox surfaces the following to the operator:

```
╔══════════════════════════════════════════════════╗
║  SIGNED HOOK: hooks/executed-without-arguments.sh ║
╠══════════════════════════════════════════════════╣
║  Entity:   juno (authorized-agent bond — ACTIVE) ║
║  Signed:   2026-04-04 by juno@kingofalldata.com  ║
║  Version:  2  (last seen: 2)                     ║
║  Policy:   harness: claude                       ║
║            interactive: --dangerously-skip-permissions ║
║            non-interactive: REJECTED             ║
╚══════════════════════════════════════════════════╝
```

For WARN-level events (no block or unverified signer):

```
⚠ UNSIGNED HOOK: hooks/some-script.sh
  No verified policy block found. Proceeding with warning.
  Set POWERBOX_UNSIGNED_DEFAULT=STRICT to block unsigned hooks.
```

For BLOCK-level events:

```
✗ BLOCKED: hooks/some-script.sh
  Reason: Signed block version 1 is below last seen version 2.
  Possible rollback attack. File this as a security event if unexpected.
```

---

## 5. IPFS Anchoring (Optional)

### 5.1 Purpose

The `cid:` field in the signed block header provides an optional IPFS anchor. A verifier with IPFS access can pin and cross-check the block content against its CID, independent of git history.

### 5.2 Self-Referential Bootstrap

Because the CID depends on the content, and the content includes the CID field, bootstrapping requires two iterations:

```bash
# Step 1: Sign the block WITHOUT the CID field
gpg --clearsign header-without-cid.txt > signed-no-cid.txt

# Step 2: Pin to IPFS, get CID
FIRST_CID=$(ipfs add -q signed-no-cid.txt)

# Step 3: Add CID field to header, re-sign, re-pin
# (CID of the final signed block will differ from FIRST_CID)
sed "s/^$/cid: ${FIRST_CID}\n/" header-without-cid.txt > header-with-cid.txt
gpg --clearsign header-with-cid.txt > signed-with-cid.txt
FINAL_CID=$(ipfs add -q signed-with-cid.txt)

# The cid: field in the final block records FIRST_CID (the pre-CID signed form)
# Verifiers pin the FINAL_CID form for distribution
```

The `cid:` field is **advisory** — the powerbox may optionally cross-check it but this is non-blocking. IPFS availability is not assumed.

---

## 6. PR Consensus Protocol

### 6.1 Who Can Modify a Signed Block

Modifying a signed block requires consensus from a trust ring. The default threshold is a simple majority of the signer's trust ring. The optional `threshold:` field in the header overrides the default.

**Modification includes:**
- Changing any header field
- Changing the policy block
- Incrementing the version
- Removing the block entirely

**Modification does NOT include:**
- Changing code outside the signed region
- Whitespace/formatting changes outside the signed region

### 6.2 Threshold Expressions

The `threshold:` field accepts the following expressions:

| Expression | Meaning |
|------------|---------|
| `majority(ring:koad-core)` | Simple majority of entities in the `koad-core` ring |
| `unanimous(ring:koad-core)` | All entities in the ring must approve |
| `N/M(ring:...)` | N of M members must approve (e.g., `3/5`) |
| `koad-only` | Only koad's key is sufficient |
| `any(authorized-agent)` | Any entity with an authorized-agent bond |

Default (if `threshold:` is absent): `majority(ring:{signer's-ring})`.

### 6.3 Vote Format

Votes are filed as signed files committed to the PR branch:

```
~/.{entity}/trust/votes/<pr-identifier>/<voter-entity>.sig
```

File content (plaintext, then GPG clearsigned):

```
vote: approve | reject | abstain
pr: koad/juno#42
block: hooks/executed-without-arguments.sh@version:2
voter: vesta
date: 2026-04-05
reason: [optional — required for reject]
```

A signed PR review comment (GitHub) is also accepted as an alternative; if both a `.sig` file and a PR comment exist for the same entity, the file takes precedence.

### 6.4 Original Publisher's Rebuttal Rights

The entity or person who originally signed the block holds **rebuttal rights**: a signed rebuttal from the original publisher blocks the PR unconditionally unless the full override threshold is reached.

koad's key additionally carries **veto authority** in all rings by default: a koad-signed rebuttal blocks any merge unconditionally, regardless of threshold.

---

## 7. Janus Merge Gate

### 7.1 Detection

Before a PR is merged, Janus scans the diff for signed block modifications:

```bash
# Detect signed block in PR diff
git diff base...HEAD --unified=0 | \
  grep -E '^\+.*# -----BEGIN PGP|^\-.*# -----BEGIN PGP|^\+.*# -----END PGP|^\-.*# -----END PGP'
```

If any added or removed line falls within a `-----BEGIN PGP SIGNED MESSAGE-----` / `-----END PGP SIGNATURE-----` range, the PR is flagged as a **signed-block-modification PR**.

### 7.2 Enforcement

For a signed-block-modification PR, Janus:

1. Identifies the block(s) modified
2. Looks up the threshold for each block (from the block header or default)
3. Counts valid votes in `trust/votes/<pr-identifier>/`
4. Checks for rebuttals from original publisher(s)
5. Blocks merge until threshold is met and no outstanding rebuttals exist
6. Posts a status check to the PR: "Signed block consensus: 2/3 votes received — waiting for majority"

### 7.3 Post-Merge Re-Signing

After a signed-block-modification PR is merged, the original signer (or a designated co-signer) must:

1. Increment the version number
2. Update the `date:` field
3. Re-sign the block
4. Commit the new signature

This re-signing is enforced by Janus before the merge is marked complete. Until the re-sign commit lands, the block is in a PENDING state: the powerbox treats it as WARN-level rather than fully authorized.

### 7.4 Co-Signer Blocks (Optional)

For high-trust policy blocks, co-signer blocks may be appended to the file after the primary signed block:

```bash
# Primary signed block (§2.5 format)

# -----BEGIN CO-SIGNER BLOCK-----
# role: co-signer
# entity: vesta
# date: 2026-04-05
# -----BEGIN PGP SIGNED MESSAGE-----
# Hash: SHA512
#
# co-signs: hooks/executed-without-arguments.sh@version:2
# signer: juno
# date: 2026-04-04
# -----BEGIN PGP SIGNATURE-----
# [vesta's signature]
# -----END PGP SIGNATURE-----
# -----END CO-SIGNER BLOCK-----
```

Co-signer blocks are optional but encouraged for hooks that run with elevated permissions (e.g., `--dangerously-skip-permissions`).

---

## 8. Nostr Publication

### 8.1 Authorship Model

Each entity publishes their own policy events under their own Nostr pubkey (derived from their Ed25519 key). This is **Option A** from koad/vesta#81's Mercury discussion:

- Each entity's npub has its own policy feed
- Subscribers to Juno's pubkey receive Juno's policy updates
- Correct semantics: the entity is the author of their own policy
- Mercury is the relay orchestrator — it receives completed, signed events and publishes them; it is not the author

**Mercury's role:** Event publisher and relay manager. Mercury does not sign policy events; it routes them. The signing authority is always the entity whose policy is declared.

### 8.2 Event Format

Nostr event kind: **30078** (parameterized replaceable event — arbitrary application data)

```json
{
  "kind": 30078,
  "pubkey": "<entity-npub>",
  "created_at": <unix-timestamp>,
  "tags": [
    ["d", "koad-io-policy:<entity>:<file-path>"],
    ["t", "koad-io"],
    ["t", "policy-block"],
    ["entity", "<entity-name>"],
    ["file", "<repo-relative-file-path>"],
    ["version", "<version-number>"]
  ],
  "content": "<full signed block text — unstripped>"
}
```

The `"d"` tag provides the replaceable event identifier: a new event with the same `d` tag replaces the previous one. Subscribers always see the latest version of a given entity+file policy.

### 8.3 npub Derivation

The entity's Nostr public key is the same Ed25519 key as the kingdoms fingerprint key (`~/.{entity}/id/ed25519.pub`), encoded as a Nostr bech32 npub. No separate key is needed.

```bash
# Derive npub from entity Ed25519 key
# (Nostr pubkeys are 32-byte Ed25519 public keys, bech32-encoded as npub)
openssl pkey -in ~/.juno/id/ed25519.pub -pubin -outform DER \
  | tail -c 32 | bech32 npub
```

### 8.4 Publishing Pipeline

```
1. PR merged with signed block modification
2. Janus triggers convergence script
3. Convergence script:
   a. Extracts final signed block from file
   b. Constructs Nostr event JSON (§8.2)
   c. Signs event with entity Ed25519 key
   d. Sends to Mercury via daemon queue
4. Mercury publishes to configured Nostr relays
5. Convergence script records Nostr event ID
6. Nostr event ID committed to block header as nostr: field (next version bump)
```

---

## 9. Reference Implementation

### 9.1 Verify Script

Location: `~/.koad-io/lib/verify-signed-block.sh`

```bash
#!/usr/bin/env bash
# verify-signed-block.sh — Verify GPG-signed policy block in a script

set -euo pipefail

SCRIPT="$1"
if [[ -z "$SCRIPT" ]]; then
  echo "Usage: verify-signed-block.sh <script-path>" >&2
  exit 1
fi

# Extract block
BLOCK=$(sed -n '/^# -----BEGIN PGP SIGNED MESSAGE-----/,/^# -----END PGP SIGNATURE-----/p' \
  "$SCRIPT" | sed 's/^# \{0,1\}//')

if [[ -z "$BLOCK" ]]; then
  echo "NO_BLOCK: $SCRIPT" >&2
  exit 2
fi

# Verify
echo "$BLOCK" | gpg --verify 2>&1
EXIT=$?

if [[ $EXIT -eq 0 ]]; then
  echo "OK: $SCRIPT"
else
  echo "INVALID_SIGNATURE: $SCRIPT" >&2
  exit 1
fi
```

### 9.2 Assign to Vulcan

The full reference implementation (verify-signed-block.sh, block-registry management, powerbox integration) is assigned to Vulcan via GitHub Issue on koad/vulcan. This spec is the contract; Vulcan ships the implementation.

---

## 10. Open Items

1. **Convergence shell script** — IPFS pin + Nostr publish workflow. Assign to Vulcan (koad/vulcan).
2. **Janus merge gate implementation** — File against koad/janus with a cross-reference to this spec.
3. **Nostr kind 30078 registration** — Confirm or adjust; defer to Mercury/Nostr integration spec.
4. **Multi-signature embedded form** — Concrete example with 3 co-signer blocks.
5. **Nostr relay list** — Default relay configuration; defer to Mercury spec.
6. **Reference implementation deployment** — `verify-signed-block.sh` in `~/.koad-io/lib/`. Vulcan.

---

## References

- VESTA-SPEC-007: Trust Bond Protocol (signer identity, bond validation)
- VESTA-SPEC-020: Hook Architecture (hook execution model)
- VESTA-SPEC-027: CID Privacy Primitive (IPFS addressing)
- koad/juno — `hooks/executed-without-arguments.sh` (live canonical example)
- RFC 4880 (OpenPGP clearsign format)
- NIP-30078 (Nostr parameterized replaceable events)

---

*Spec originated 2026-04-05. Resolves koad/vesta#81. Implementation assigned to Vulcan; merge gate assigned to Janus.*
