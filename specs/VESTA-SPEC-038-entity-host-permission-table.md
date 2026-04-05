---
id: VESTA-SPEC-038
title: Entity Host Permission Table
status: canonical
created: 2026-04-05
owner: vesta
applies-to: all entities, Argus (audit), daemon, trust bond protocol
related-issues:
  - koad/vesta#57
description: "Defines the permission table format that maps entity+host combinations to authorized actions. Complements trust bonds (WHAT an entity may do) with host authorization (WHERE it may act from)."
---

# VESTA-SPEC-038: Entity Host Permission Table

## Purpose

Trust bonds (VESTA-SPEC-007) establish WHAT an entity is authorized to do. This spec establishes WHERE an entity is authorized to act from — which hosts (machines) are valid execution environments for each entity and what actions each host is permitted to perform on behalf of that entity.

Every signed commit or release carries an entity identity AND a host identity (via hostname-namespaced keys, per VESTA-SPEC-009). The permission table is the whitelist that says which entity+host pairings are valid and what actions each pairing may take.

---

## The Problem

An entity's private key material may exist on multiple machines (thinker, wonderland, fourty4, etc). If any machine is compromised, an attacker can sign commits/releases as the entity from that host. Trust bonds alone cannot detect this — a revoked key is not enough if the attacker already has all key material.

The permission table adds a second dimension: even if a valid entity key is present on a machine, if that machine is not in the entity's permission table, its signatures are unauthorized.

---

## Permission Table Format

### File Location

```
~/.{entity}/trust/permissions.md
```

One file per entity. Signed by koad (or Juno on koad's behalf) for root-delegated entities.

### File Format

YAML frontmatter with the permission table, followed by optional markdown body for human context:

```yaml
---
entity: vulcan
signed_by: koad
date: 2026-04-05
renewal: Annual (2027-04-05)
status: ACTIVE
hosts:
  wonderland:
    key: id/wonderland.pub
    authorized:
      - build
      - commit
      - deploy
      - release
  thinker:
    key: id/thinker.pub
    authorized:
      - read
      - report
  fourty4:
    key: id/fourty4.pub
    authorized:
      - read
      - report
      - commit
---

## Notes

Vulcan's primary build host is wonderland. thinker and fourty4 are read/report only.
Deploy and release actions are restricted to wonderland until further notice.
```

### Signature File

The permission table MUST be GPG-signed (same pattern as trust bonds):

```
~/.{entity}/trust/permissions.md
~/.{entity}/trust/permissions.md.asc
```

The `.asc` file is a PGP clearsign file. The signature is by the `signed_by` entity.

---

## Fields

### Frontmatter Fields (Required)

| Field | Type | Description |
|-------|------|-------------|
| `entity` | string | Entity this permission table applies to |
| `signed_by` | string | Entity or person who authorized this table |
| `date` | ISO8601 | Date this table was signed |
| `renewal` | string/date | When table must be re-signed (or `never`) |
| `status` | string | `ACTIVE`, `REVOKED`, or `DRAFT` |
| `hosts` | map | Map of hostname → permissions (see below) |

### Host Entry Fields (per host)

| Field | Type | Description |
|-------|------|-------------|
| `key` | path | Relative path to host's public key within `~/.{entity}/id/` |
| `authorized` | list | List of action tokens this host may perform |

### Authorized Action Tokens

| Token | Meaning |
|-------|---------|
| `read` | May read entity state (git pull, inspect) |
| `report` | May file issues, post status updates |
| `commit` | May make commits to the entity's git repos |
| `build` | May run build tasks and produce artifacts |
| `deploy` | May deploy built artifacts to staging/production |
| `release` | May tag and publish releases |
| `spawn` | May spawn child entities |
| `sign` | May sign trust bonds or policy documents on behalf of this entity |

Action tokens are additive. An entry with `[read, report]` may only read and report — it cannot commit even if the entity key is present on that host.

---

## Validation

### Valid Signature Check

A commit or release signed by `{entity}@{host}` is valid if ALL of the following hold:

1. `~/.{entity}/trust/permissions.md` exists
2. `~/.{entity}/trust/permissions.md.asc` exists and signature is valid (verified against the key of `signed_by`)
3. `status` is `ACTIVE`
4. `hosts` map contains an entry for `{host}`
5. The host entry's `key` matches the key used to sign the commit/release
6. The action (e.g., `commit`, `release`) is in the host entry's `authorized` list
7. Renewal date has not passed (if set)

### Unauthorized Host = Red Flag

A signature from an unlisted host is an **unauthorized action**. Argus (audit entity) MUST flag this:

- Log: `[ARGUS] Unauthorized host signature: {entity}@{host} — not in permission table`
- Alert: File a GitHub Issue on `koad/{entity}` tagged `security`
- Salus (if active) escalates to containment check per entity-containment-abort-protocol

### How Argus Validates

```bash
# Argus validation pseudocode

ENTITY="vulcan"
HOST="wonderland"
ACTION="commit"

PERMS_FILE="${HOME}/.${ENTITY}/trust/permissions.md"
PERMS_ASC="${PERMS_FILE}.asc"

# 1. File exists?
[[ -f "$PERMS_FILE" ]] || { echo "FAIL: no permission table for $ENTITY"; exit 1; }
[[ -f "$PERMS_ASC" ]] || { echo "FAIL: permission table unsigned"; exit 1; }

# 2. Signature valid?
gpg --verify "$PERMS_ASC" "$PERMS_FILE" 2>/dev/null || { echo "FAIL: invalid signature"; exit 1; }

# 3. Status ACTIVE?
STATUS=$(grep "^status:" "$PERMS_FILE" | head -1 | awk '{print $2}')
[[ "$STATUS" == "ACTIVE" ]] || { echo "FAIL: status=$STATUS"; exit 1; }

# 4. Host in table?
grep -q "^  ${HOST}:" "$PERMS_FILE" || { echo "FAIL: host $HOST not in permission table"; exit 1; }

# 5+6. Action authorized? (simplified check)
grep -A5 "^  ${HOST}:" "$PERMS_FILE" | grep -q "- ${ACTION}" || { echo "FAIL: $ACTION not authorized for $HOST"; exit 1; }

echo "OK: ${ENTITY}@${HOST} authorized for ${ACTION}"
```

---

## Adding and Updating Hosts

### Adding a New Host

1. The entity generates a new host keypair on the new machine: `ssh-keygen -t ed25519 -f ~/.{entity}/id/{hostname}`
2. The entity operator (or koad) updates `trust/permissions.md` to add the host entry
3. The signer (`signed_by`) signs the updated table: `gpg --clearsign -o trust/permissions.md.asc trust/permissions.md`
4. Both files committed and pushed

### Removing a Host

1. Remove the host entry from `trust/permissions.md`
2. Re-sign the table
3. Commit and push
4. Revocation takes effect immediately — any subsequent signature from the removed host is unauthorized

### Rotating a Host Key

1. Generate new key on the host
2. Update `key:` path in `trust/permissions.md` to point to new key
3. Re-sign table
4. Destroy old private key on host

---

## Integration with Trust Bonds (VESTA-SPEC-007)

Trust bonds define WHO may act. Permission tables define WHERE they may act from. Both checks are required:

```
Is this action authorized?
  ├── Check trust bond: does entity X have a bond granting this authority?
  └── Check permission table: is host Y in entity X's permission table for this action?
  
  Both must pass. Either failure = unauthorized.
```

If an entity's trust bond is revoked, its permission table is irrelevant — trust bond check fails first. If an entity's permission table is missing or unsigned, all host-specific actions fail — even if the trust bond is valid.

---

## Relation to Other Specs

- **VESTA-SPEC-007** (Trust Bond Protocol) — trust bonds establish WHO; permission tables establish WHERE
- **VESTA-SPEC-009** (Daemon) — daemon signs batches using host-namespaced keys; permission table is the authorization source for those keys
- **VESTA-SPEC-017** (Operator Identity Verification) — complements identity verification at the session level; permission tables operate at the key/signature level
- **VESTA-SPEC-024** (Public Key Distribution) — entity public keys registry; permission tables reference keys within `~/.{entity}/id/`

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 (canonical) | 2026-04-05 | Initial spec. Addresses koad/vesta#57. |
