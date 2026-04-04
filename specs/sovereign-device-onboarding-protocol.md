---
id: VESTA-SPEC-019
title: Sovereign Device Onboarding Protocol
status: draft
created: 2026-04-03
author: Juno (from direct description by koad)
applies-to: koad:io Authenticator, Dark Passenger, daemon, all koad:io clients
---

# VESTA-SPEC-019: Sovereign Device Onboarding Protocol

## Purpose

Define how new devices, clients, and sessions are credentialed into the koad:io system. The model: one credentialed device signs the next into existence. No passwords. No vendor credential store. No SMS codes. The authenticator (phone) is the root signing device; everything else is signed into existence by it.

## Core Principle

**One device logs the next in.**

Every new client (Dark Passenger extension, daemon instance, entity session, new phone) presents a QR code or challenge. The existing credentialed authenticator scans it, approves it, and signs it into the profile. The profile is the ledger of all credentialed devices.

This is the same model used by passkeys and hardware security keys (FIDO2), but sovereign — no relying party, no vendor credential store, no Apple/Google/Microsoft in the chain.

---

## The koad:io Authenticator

**Platform:** Meteor PWA + native iOS + Android  
**Role:** Root signing device. Mobile-first. Holds the profile's private keys.  
**Location:** `~/.koad-io/authenticator/` (source), distributed as app

The authenticator is the gate to the system. Every operation requiring proof of identity routes through it:
- New device onboarding (this spec)
- Challenge-response verification (VESTA-SPEC-017)
- Trust bond signing
- Ring membership issuance
- TOTP for external services (replaces Google Authenticator)
- Dark Passenger credential issuance
- Daemon session authorization

The authenticator is not a tool *for* the system — it is the trust anchor of the system.

---

## Device Onboarding Flow

### Step 1 — New Client Presents Challenge

When a new koad:io client starts for the first time without credentials, it:
1. Generates a device keypair (ephemeral or persistent, depending on client type)
2. Generates a random challenge nonce (min 128 bits)
3. Encodes as QR: `{client_type, device_id, device_pubkey, nonce, timestamp}`
4. Displays QR and waits

No login form. No email field. No password prompt. Just a QR code.

### Step 2 — Authenticator Scans

The profile owner opens their authenticator app and scans the QR. The authenticator:
1. Decodes the request
2. Displays a human-readable approval prompt:
   ```
   Sign in Dark Passenger?
   Device: MacBook Pro [machine fingerprint]
   Time: 2026-04-03 23:51
   
   [Approve]  [Deny]
   ```
3. On approval: signs `{device_id + device_pubkey + nonce + timestamp + profile_handle}` with the profile's private key

### Step 3 — Credential Returned

The signed credential is returned to the new client via one of:
- **Local network:** authenticator and new device on same LAN — direct push
- **Daemon relay:** authenticator sends to daemon, daemon pushes to waiting client
- **QR round-trip:** authenticator displays a response QR, client scans it

### Step 4 — Credential Recorded in Profile

The authorization is committed to the profile:
```
~/.koad-io/devices/
  dark-passenger-macbook-2026-04-03.json    — signed credential
  daemon-thinker-2026-03-30.json            — older entry
  daemon-dotsh-2026-04-01.json
```

Or as a structured entry in the profile's public-facing device registry (daemon-hosted). The profile is the ledger. Every signed-in instance is visible and auditable.

### Step 5 — Client Is Live

The new client holds its signed credential. It presents this credential when:
- Fetching ring-gated augmentations from a daemon (VESTA-SPEC-018)
- Requesting peer connectivity (VESTA-SPEC-014)
- Calling daemon hook endpoints
- Verifying identity to other entities (VESTA-SPEC-017)

---

## Device Types and Credential Scopes

| Client Type | Credential Scope | Persistence |
|---|---|---|
| Dark Passenger extension | Ring membership, augmentation access, hook calls | Session or persistent (user choice) |
| Daemon instance | Full operator-level, entity orchestration | Persistent (server-side) |
| Entity session (Claude Code, opencode) | Entity-scoped operations | Session |
| New phone (authenticator transfer) | Root key authority | Persistent, replaces previous |
| Ring peer onboarding | Ring membership at granted level | Persistent until revoked |

---

## Profile as Device Ledger

The profile (git repo) maintains a device registry. This is the source of truth for what is credentialed.

```
profile/
  devices/
    README.md           — human-readable device list
    active.json         — currently credentialed devices
    revoked.json        — revoked device IDs (daemons check this)
```

**Revocation:** Remove device from `active.json`, add to `revoked.json`, commit and push. At next sync, any daemon or peer that checks the profile sees the revocation. The device's credentials are invalid from that point forward.

**History:** Git history shows every device ever authorized — date, device fingerprint, client type. Complete audit trail.

---

## Onboarding a New Authenticator (Key Transfer)

When the profile owner gets a new phone:

1. New phone installs authenticator, generates its own keypair
2. New phone shows QR (same flow as any new device)
3. **Old phone** scans and approves — signs the new phone into the profile with `root` scope
4. New phone is now the root signing device
5. Profile is updated: new phone's public key replaces old phone's public key in the profile's key section
6. Old phone is optionally revoked from the device registry

The key transfer is sovereign: no iCloud backup, no vendor migration tool — just old device signing new device, same as any other onboarding.

---

## Ring Member Onboarding

When a new peer joins a ring:

1. Peer installs Dark Passenger and onboards their own authenticator (self-sovereign setup)
2. Ring owner invites peer: generates an invitation QR or link (time-limited challenge)
3. Peer's authenticator scans the ring invitation
4. Ring owner's daemon validates peer's credential and issues a ring membership token
5. Ring membership token is signed by ring owner's key, scoped to the granted ring level
6. Peer's profile is linked in ring owner's ring manifest

The peer never gives the ring owner their private keys. The ring owner never holds the peer's credentials. The membership token is the bridge.

---

## Relation to Other Specs

- **VESTA-SPEC-017 (Operator Identity Verification):** The authenticator app is the primary tool for Step 3 (challenge-response). The QR flow described here IS the challenge-response flow, made mobile-native.
- **VESTA-SPEC-018 (Dark Passenger Augmentation):** The extension credential used to fetch ring-gated augmentation packages is issued via this onboarding protocol.
- **VESTA-SPEC-014 (Kingdom Peer Connectivity):** Ring member onboarding uses this protocol to issue ring membership tokens.
- **Trust Bond Protocol:** Trust bonds can be signed via the authenticator — same approval flow, different payload.

---

## Open Questions (for Vesta review)

1. Credential return channel: which of the three return methods (local network, daemon relay, QR round-trip) is primary? All three need to work; what's the priority order?
2. Offline onboarding: what if the profile owner's phone has no network access? QR round-trip is the fallback — specify fully.
3. Multi-profile support: can the authenticator hold keys for multiple profiles (e.g., koad + juno on the same phone)?
4. Credential expiry: should device credentials expire and require renewal, or persist until explicitly revoked?
5. The "new authenticator" flow when no old phone exists (lost/broken): recovery via paper key or shamir backup? Out of scope here but needs a companion spec.

---

*Filed by Juno, 2026-04-03. Developed from direct description by koad of the authenticator onboarding model. Core insight: QR-based chain-of-trust device authorization — same model as passkeys/FIDO2 but fully sovereign, no vendor in the chain, profile as ledger.*
