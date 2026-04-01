# Trust Bonds

A trust bond is a signed authorization agreement between two parties. It answers the question: *"Is this entity actually authorized to do what it says it can do?"*

Trust bonds are how the koad:io system establishes verifiable relationships without relying on blind faith or platform-imposed permissions.

---

## What a Trust Bond Is

A trust bond is a document, signed cryptographically by the grantor, that states:

- **Who** is being authorized (the grantee)
- **What** they are authorized to do (the scope)
- **Under what conditions** (constraints)
- **By whom** (the grantor, with their signature)

The signature is the trust. Without a valid signature from the grantor, the bond is meaningless.

**Example:** koad grants Juno authorization to operate business operations up to certain limits. That authorization is written into a bond file, signed with koad's key, and stored in `~/.juno/trust/bonds/`. When Juno needs to prove she's authorized to act on koad's behalf, she presents the bond. Anyone with koad's public key can verify it.

---

## Where Bonds Live

```
~/.entityname/trust/
└── bonds/
    ├── <grantor>-<type>.signed     Active bonds
    └── revoked/                    Revoked bonds (archived, not deleted)
```

**Naming convention:** `<grantor>-<type>.signed`

Examples:
- `koad-authorized-agent.signed` — koad authorized this entity as an agent
- `juno-peer-coordination.signed` — Juno established a peer coordination bond
- `koad-platform-stewardship.signed` — koad delegated platform stewardship to Vesta

---

## Bond File Format

A bond file is a signed document. The unsigned source document contains:

```
TRUST BOND

Grantor:    koad (fingerprint: <GPG fingerprint>)
Grantee:    vesta (fingerprint: <GPG fingerprint>)
Type:       platform-stewardship
Issued:     2026-03-31
Expires:    never (revocable)

SCOPE:
- Vesta is authorized to define the koad:io protocol
- Vesta's published specs are canonical — all entities update to match
- Vesta may audit any entity's directory against the canonical spec
- Vesta may not modify other entities' repositories directly

CONSTRAINTS:
- Protocol changes affecting security or identity require koad review
- Vesta may not act outside the scope of protocol definition

SIGNED BY GRANTOR:
<detached GPG signature>
```

The `.signed` file contains this document plus the grantor's detached signature appended.

---

## How to Read a Bond

When you encounter a bond:

1. **Identify the grantor** — whose authority backs this bond?
2. **Check the scope** — what exactly is authorized? Read it precisely. Do not infer beyond what is written.
3. **Check constraints** — what is explicitly excluded or limited?
4. **Verify the signature** — confirm the grantor's key signed this document

Do not treat a bond as granting anything beyond its explicit scope. If the bond says "authorize up to $500," it does not authorize $501.

---

## Verifying a Bond

To verify a bond, you need the grantor's public key. Public keys are distributed at:

```
canon.koad.sh/<entityname>.keys
```

Verification with GPG:

```bash
# Import grantor's public key
curl canon.koad.sh/koad.keys | gpg --import

# Verify the bond
gpg --verify koad-platform-stewardship.signed
```

A valid signature confirms:
- The document was signed by the stated grantor
- The document has not been modified since signing

An invalid or missing signature means the bond cannot be trusted.

---

## Bond Types

| Type | Meaning |
|------|---------|
| `authorized-agent` | Grantee may act on grantor's behalf within scope |
| `peer-coordination` | Mutual coordination rights between entities |
| `platform-stewardship` | Grantee owns a domain of the platform |
| `employee` | Work relationship, specific permissions |
| `member` | Community membership |
| `vendor` | Verified business relationship |
| `revocation` | Explicit record that a bond has been revoked |

New bond types may be defined by Vesta as the protocol evolves. File an issue at `koad/vesta` to propose a new type.

---

## Creating a Bond

Bond creation requires both parties:

1. **Draft** the bond document — grantor and grantee agree on scope and constraints
2. **Sign** — grantor signs the document with their private key
3. **Distribute** — signed bond is stored in grantee's `trust/bonds/`
4. **Reference** — grantor's `GOVERNANCE.md` or trust directory notes the bond was issued

Never self-sign a bond. A bond you signed yourself proves nothing about the grantor's authorization.

---

## Revoking a Bond

Revocation is explicit — bonds are never silently deleted.

1. Grantor signs a revocation document referencing the original bond
2. Original bond is moved to `trust/bonds/revoked/`
3. Revocation document is stored alongside it
4. Grantee is notified (GitHub Issue or direct communication)
5. Affected entities stop accepting the revoked authorization

Revoked bonds are archived, not deleted. The history of authorization matters.

---

## What to Do Without a Bond

If you need to act in an area where you do not have an explicit bond:

1. **Stop.** Do not assume authorization.
2. File an issue against the entity who would need to grant the bond.
3. Wait for the bond to be issued before acting.

If you are a new entity and do not yet have any bonds, your first action should be to establish a bond from koad or Juno before taking any actions outside your immediate entity directory.
