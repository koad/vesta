# VESTA-SPEC-039 — `trust/public-chain.json` Build Artifact

**ID:** VESTA-SPEC-039  
**Title:** Trust Public Chain JSON — Build Artifact for Trust Bond Visualization  
**Status:** canonical  
**Area:** 4: Trust Bonds  
**Applies to:** all entities with `trust/bonds/`, Vulcan (build tooling), Muse (visualization consumer)  
**Created:** 2026-04-05  
**Updated:** 2026-04-05  
**Resolves:** Muse brief `2026-04-05-trust-bond-visualization.md` — Open Question 2  

---

## Why This Exists

Trust bond files (`trust/bonds/*.md` and `.md.asc`) live in entity repos. Most of those repos are private or semi-private. The `TrustBondChain` visualization component on the entity profile page needs trust chain data at runtime, but cannot make authenticated GitHub API calls from a public page, and cannot assume the `trust/bonds/` directory is publicly accessible.

The solution is a build artifact: `trust/public-chain.json`. This file is generated at commit time (or by a build step) from the entity's trust bond files, committed to the repo root, and served as a static file. The visualization component reads this file rather than querying the API directly.

This decouples the visualization from:
- API availability
- Private repo access
- Runtime authentication

The artifact contains only information the entity explicitly chooses to publish. It is not a raw export of the bond files — it is a curated projection of the chain for public consumption.

---

## File Location

```
~/{entity}/trust/public-chain.json
```

Committed to the entity repo. Tracked in git. Updated whenever bonds change.

This file is always public. It contains no secrets. Bond files themselves may remain private. The artifact is the published view.

---

## Schema

```json
{
  "schema_version": "1.0",
  "entity": "juno",
  "generated_at": "2026-04-05T14:32:00Z",
  "generated_by": "juno",
  "chain": [
    {
      "bond_id": "koad-to-juno",
      "grantor": "koad",
      "grantee": "juno",
      "type": "authorized-agent",
      "status": "ACTIVE",
      "signed_by": "Keybase",
      "signed_date": "2026-04-02",
      "fingerprint_tail": "A07F 8CFE CBF6",
      "bond_file_url": "https://github.com/koad/juno/blob/main/trust/bonds/koad-to-juno.md",
      "signature_file_url": "https://github.com/koad/juno/blob/main/trust/bonds/koad-to-juno.md.asc",
      "verified": true
    },
    {
      "bond_id": "juno-to-vulcan",
      "grantor": "juno",
      "grantee": "vulcan",
      "type": "authorized-builder",
      "status": "ACTIVE",
      "signed_by": "GPG",
      "signed_date": "2026-04-02",
      "fingerprint_tail": "16EC 6C71 8A96",
      "bond_file_url": "https://github.com/koad/vulcan/blob/main/trust/bonds/juno-to-vulcan.md",
      "signature_file_url": "https://github.com/koad/vulcan/blob/main/trust/bonds/juno-to-vulcan.md.asc",
      "verified": true
    }
  ],
  "root": "koad",
  "root_signing_method": "Keybase"
}
```

---

## Field Definitions

### Top-level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | string | yes | Always `"1.0"` until a breaking change. |
| `entity` | string | yes | The entity whose chain this describes. The entity that owns and publishes this file. |
| `generated_at` | ISO-8601 UTC string | yes | Timestamp of artifact generation. |
| `generated_by` | string | yes | Entity or process that generated the file. Usually the entity itself during a commit hook. |
| `chain` | array | yes | Ordered list of bond records. See below. |
| `root` | string | yes | The root grantor (human authority at the top of the chain). Always `"koad"` in the current ecosystem. |
| `root_signing_method` | string | yes | `"Keybase"` for human root, `"GPG"` for entity-signed bonds. |

### Bond record (`chain[]`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `bond_id` | string | yes | Filename without extension. Convention: `{grantor}-to-{grantee}`. |
| `grantor` | string | yes | Entity granting authority. |
| `grantee` | string | yes | Entity receiving authority. |
| `type` | string | yes | Bond type. One of: `authorized-agent`, `authorized-builder`, `peer`. Extensible — new types allowed, must be documented in VESTA-SPEC-007. |
| `status` | string | yes | `ACTIVE`, `REVOKED`, or `PENDING`. |
| `signed_by` | string | yes | `"Keybase"` or `"GPG"`. |
| `signed_date` | ISO-8601 date | yes | Date the bond was signed. Date only (no time). |
| `fingerprint_tail` | string | yes | Last 12 characters of the GPG/Keybase fingerprint, space-grouped in fours. Example: `"A07F 8CFE CBF6"`. Used by the visualization. Not the full fingerprint — the full fingerprint lives in the bond file, not in this artifact. |
| `bond_file_url` | string | yes | HTTPS URL to the `.md` bond file on GitHub. Used in the tooltip "View bond file →" affordance. |
| `signature_file_url` | string | yes | HTTPS URL to the `.md.asc` signature file. Used to derive `verified` state. |
| `verified` | boolean | yes | Whether the `.asc` file was present and parseable at generation time. **Does not mean `gpg --verify` was run** — it means the signature file exists. The UI note reads "Signature file present — verify locally with `gpg --verify`". |

---

## What Is Excluded

The following fields from the bond file are NOT included in the artifact:

- **Bond statement text** (the prose `> I, Juno, authorize...`) — private by default.
- **Full fingerprint** — the tail is enough for display. Full fingerprint is in the source file.
- **Scope limitations** — the bond file may contain scope-limiting clauses (e.g., "authorized to act on repositories under koad/"). These are private governance details not published in the artifact.
- **Revocation reason** — if a bond is revoked, `status: "REVOKED"` is published, but no reason is included. Reason stays in the bond file.

---

## Generation

### Trigger

`trust/public-chain.json` is regenerated:
1. **On every commit** that touches any file in `trust/bonds/` — via a pre-commit hook or CI step.
2. **On demand** via a command: `{entity} trust build-chain` (command spec TBD, follows VESTA-SPEC-006 commands pattern).

### Generation logic

```bash
# Pseudocode — actual implementation in koad:io package
for each *.md file in trust/bonds/:
  parse frontmatter: grantor, grantee, type, status, signed_by, signed_date, fingerprint
  check if corresponding *.md.asc exists → verified: true/false
  construct bond record
  append to chain array

write chain array to trust/public-chain.json with metadata
```

### Who generates it

The entity itself generates its own `public-chain.json`. It only includes bonds where the entity is the `grantor` OR the entity is the `grantee` and the bond file lives in the entity's own repo (i.e., the entity has a copy of the inbound bond in its own `trust/bonds/` directory).

This means:
- `~/.juno/trust/public-chain.json` contains all bonds Juno has granted (juno-to-vulcan, juno-to-mercury, etc.) AND the inbound bond from koad (koad-to-juno), if Juno keeps a copy.
- `~/.vulcan/trust/public-chain.json` contains all bonds Vulcan has granted AND the inbound bond from Juno (juno-to-vulcan), if Vulcan keeps a copy.

---

## Consumption by Visualization Components

Per Muse's brief (`2026-04-05-trust-bond-visualization.md`):

```javascript
// Fetch artifact — no authentication needed
const chain = await fetch(
  `https://raw.githubusercontent.com/koad/${entityName}/main/trust/public-chain.json`
).then(r => r.json());

// Verification state logic
const isVerified = bond.verified;
const isRevoked  = bond.status === 'REVOKED';
const isPending  = !isVerified && !isRevoked;
```

Cache: 30 minutes (bonds change rarely).

---

## Trust Considerations

This file is committed to a public repo. The entity publishes it. Review:

- **No secrets included.** Bond files contain signed authorization statements. Those statements are visible in the `.md` file itself (which the `bond_file_url` links to). The artifact's field set is strictly less than the source file.
- **Tamper resistance.** The artifact is not itself signed. It derives from signed source files. To verify authenticity: fetch the original `.md` and `.md.asc` files and run `gpg --verify` locally. The artifact is a convenience cache, not a trust root.
- **An entity can choose not to include specific bonds.** If a bond should remain private (e.g., a peer bond with a non-public entity), the generator may exclude it. The artifact is opt-in per bond, not an automatic full export. Default: include all bonds where both parties are public GitHub repos.

---

## Versioning

When a structural change to this schema is needed (adding/removing required fields, changing type constraints), the `schema_version` increments. Consumers must check `schema_version` before parsing.

Current schema version: `"1.0"`.

---

## Related Specs

- VESTA-SPEC-007 — Trust Bond Protocol (bond file format and signing)
- VESTA-SPEC-024 — Entity Public Key Distribution (canon.koad.sh endpoints)
- VESTA-SPEC-038 — Entity Host Permission Table (what's authorized, not just who)
- Muse brief: `2026-04-05-trust-bond-visualization.md` (visual rendering of this data)
