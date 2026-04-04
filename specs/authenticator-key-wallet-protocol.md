---
id: VESTA-SPEC-020
title: koad:io Authenticator — Sovereign Key Wallet Protocol
status: draft
created: 2026-04-04
author: Juno (from direct description by koad)
applies-to: koad:io Authenticator app, all signing operations across the system
---

# VESTA-SPEC-020: koad:io Authenticator — Sovereign Key Wallet Protocol

## Purpose

Define the credential model, wallet structure, and signing UX for the koad:io Authenticator — a Meteor PWA (also native iOS/Android) that serves as the sovereign key wallet for the koad:io system.

## The Wallet Model

The authenticator is a **key wallet** — not a password manager, not just a TOTP app, not a single signing device. It holds multiple credential types and signs operations with the appropriate credential for what is being requested.

Analogy: a hardware crypto wallet (Ledger, Trezor) holds multiple currencies and signs blockchain transactions with the right key. The koad:io authenticator holds multiple credential types and signs identity/auth operations with the right credential.

The core UX: a signing request arrives → the app identifies what credential type is needed → presents matching credentials → user selects and approves → app produces a signed response.

---

## Credential Types Held in the Wallet

### 1. TOTP (Time-Based One-Time Passwords)
- Standard 6-digit rotating codes, RFC 6238 compatible
- Works with any service that accepts Google Authenticator / standard TOTP
- The authenticator is a drop-in replacement for Google Authenticator
- Seeds are stored locally, not in any cloud

### 2. Cryptographic Keys
- Ed25519, ECDSA, RSA, DSA (full koad:io key set per entity spec)
- GPG keys (for trust bond signing, git commit signing, email encryption)
- SSH keys (for server authentication)
- Namespace keys (for koad:io identity claims and ring operations)
- Each key has metadata: created date, purpose, associated profile, rotation history

### 3. Trust Bonds
- Bonds can be loaded into the wallet (as documents to sign or as signed credentials to present)
- Wallet renders the bond in human-readable form before signing
- User reviews scope, from/to, authorization level → approves → wallet signs
- Signed bond (`.md` + `.md.asc`) is returned to requesting party

### 4. Ring Membership Tokens
- Tokens issued by ring owners (via VESTA-SPEC-019 onboarding flow)
- Wallet presents the appropriate ring token when requesting ring-gated resources
- Token includes: ring owner identity, membership level, scope, issue date, expiry

### 5. Device Credentials
- Credentials issued when a device was onboarded (VESTA-SPEC-019)
- Wallet presents device credential to authenticate a session on that device
- Enables re-authentication without re-scanning a QR

### 6. Auth Codes (General)
- Any structured authorization code issued by a koad:io system
- Catch-all for credential types not enumerated above
- Format: signed JSON with issuer, scope, expiry, and payload

---

## The Merkle Key Ring

The wallet does not hold isolated keys. The keys form a **signature chain** — a merkle tree of key operations.

- Every key issuance is signed by the key above it in the chain
- Every key rotation is signed by the key being rotated
- Every revocation is signed by an active key with authority over the revoked key
- The root is the oldest key — the genesis of the profile's identity

This model, proven by Keybase, means:
- You can prove you owned a key at a specific time without trusting any central party
- Key rotations don't break the identity chain — new key signed by old key, continuity preserved
- The tree is the proof — auditable by anyone with the public root

The authenticator maintains the full merkle tree locally. The published profile (git repo + Keybase) is the public view of the tree. Anyone can verify any claim in the chain against the published tree.

---

## Signing Request Flow

### Request Arrival Methods

1. **QR code** — new device, new session, or offline request. Scan with camera.
2. **Push notification** — daemon or known client sends a signing request via authenticated push
3. **Deep link** — `koadio://sign?...` opens the app with pre-populated request
4. **Local network** — same-LAN request (daemon on thinker calling authenticator on phone)
5. **Manual entry** — paste a request payload directly (fallback for any scenario)

### Signing UX

```
Request arrives via any method
  ↓
App parses request: identifies credential type needed, requester identity, payload
  ↓
App displays human-readable summary:
  ┌─────────────────────────────────┐
  │  Sign in Dark Passenger         │
  │  Device: MacBook Air (new)      │
  │  Credential needed: device key  │
  │                                 │
  │  Matching credentials:          │
  │  ● Namespace key — koad         │
  │  ○ GPG key — koad@koad.sh       │
  │                                 │
  │  [Approve]    [Deny]            │
  └─────────────────────────────────┘
  ↓
User selects credential + approves
  ↓
App signs payload with selected credential
  ↓
Signed response returned via same channel as request
```

### Credential Selection Rules

The app presents only credentials that are appropriate for the request type:
- TOTP request → only TOTP seeds for the requesting domain
- GPG sign request → only GPG keys
- Bond signing → only keys with authority to sign that bond type
- Ring token request → only ring tokens from the appropriate ring owner
- Device onboarding → namespace key (used to sign the new device into profile)

The user sees only what's relevant. The app enforces that you can't accidentally sign a bond with a TOTP seed.

---

## The Wallet UI Model

The wallet is organized by credential type, not by chronology:

```
koad:io Authenticator
├── TOTP Codes
│   ├── github.com — koad         [483 291]  (18s)
│   ├── email.koad.sh             [721 044]  (6s)
│   └── + Add
├── Keys
│   ├── koad — namespace (Ed25519)
│   ├── koad — GPG (koad@koad.sh)
│   ├── koad — SSH (thinker)
│   └── + Import / Generate
├── Trust Bonds
│   ├── koad → juno (authorized-agent) [ACTIVE]
│   ├── koad → vulcan (authorized-builder) [ACTIVE]
│   └── + Load bond
├── Ring Tokens
│   ├── koad inner ring (self)
│   └── [peer rings when applicable]
├── Devices
│   ├── thinker — daemon [credentialed 2026-03-30]
│   ├── Dark Passenger — MacBook [credentialed 2026-04-03]
│   └── Revoke device...
└── Auth Codes
    └── (general purpose, issued by system)
```

---

## Interoperability

The authenticator is the sovereign replacement for:

| Replaced Tool | What the Authenticator Provides Instead |
|---|---|
| Google Authenticator | TOTP (same standard, local seeds, no cloud) |
| 1Password / Bitwarden | Key wallet (holds credentials, signs — not just fills) |
| GPG keychain GUI | Key management + signing UI |
| SSH agent | SSH key storage + auth |
| Keybase mobile | Key operations, signature chain, profile management |
| Apple Wallet (for passes) | Ring tokens, bonds, auth codes |

The difference from all of these: the authenticator doesn't **fill in** credentials like a password manager. It **signs** with them. The output is always a proof, not a secret.

---

## Offline Operation

The authenticator operates fully offline for:
- TOTP generation (seeds are local)
- Signing with locally stored keys
- Displaying stored credentials

Network is needed for:
- Fetching new ring tokens from a daemon
- Publishing signed bonds to a profile
- Push-based signing requests

QR-based flows (VESTA-SPEC-019) work offline — the response QR is displayed on screen and scanned by the requesting device.

---

## Security Model

- All credential storage is encrypted at rest using the device's secure enclave (iOS: Secure Enclave, Android: StrongBox/TEE)
- The wallet master password / biometric is the local unlock — it never leaves the device
- Private keys never leave the authenticator unencrypted
- Signing happens on-device — the app receives a payload, signs it, returns the signature
- No cloud backup of private keys (backup via sovereign paper key / shamir shares — separate spec)

---

## Relation to Other Specs

- **VESTA-SPEC-017 (Operator Identity Verification):** The authenticator is the primary tool for challenge-response verification — the QR challenge is resolved by scanning with the authenticator and approving
- **VESTA-SPEC-018 (Dark Passenger Augmentation):** Extension credential for ring-gated augmentation packages is held in the wallet and presented automatically
- **VESTA-SPEC-019 (Sovereign Device Onboarding):** Device onboarding QR flow is executed through the authenticator's scanning interface
- **Trust Bond Protocol:** Bonds are reviewed and signed through the authenticator's bond signing UI
- **VESTA-SPEC-014 (Kingdom Peer Connectivity):** Ring membership tokens held in wallet are the credential for peer ring access

---

## Open Questions (for Vesta review)

1. Multi-profile support: can one authenticator hold keys for multiple profiles (e.g., koad AND juno on the same phone)?
2. Shared device: if koad and a family member share a tablet, how is wallet isolation handled?
3. Wallet export/import: format for moving credentials to a new authenticator device (beyond the device-signs-device flow in SPEC-019)?
4. Bond signing UX: when a bond needs both parties' signatures, does the app handle the multi-step flow, or is each party's signing a separate action?
5. Key generation: should the app support generating new keys directly, or should key generation always happen in the daemon/CLI and be imported into the wallet?

---

*Filed by Juno, 2026-04-04. Developed from direct description by koad of the authenticator as a key wallet — not a single signing device but a credential holder where the user picks the appropriate key for the operation. The framing: not a password manager (fills secrets), a key wallet (signs with proofs). Includes TOTP for external service compatibility, cryptographic keys, trust bonds, ring tokens, and device credentials — all under a single sovereign app.*
