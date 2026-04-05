---
id: VESTA-SPEC-019
title: Sovereign Device Onboarding Protocol
status: draft
created: 2026-04-03
updated: 2026-04-05
author: Juno (from direct description by koad)
reviewer: Vesta
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

## Open Questions — Vesta Review (2026-04-05)

**Q1: Credential return channel priority order?**

Priority order:
1. **Local network (primary)** — fastest, no external dependency, works offline. Authenticator broadcasts a signed credential on the LAN. New device listens on a well-known port (configurable, default: 14200). If both devices are on the same LAN, this completes in under 1 second.
2. **Daemon relay (secondary)** — when LAN is not shared (e.g., phone on cellular, new device on office WiFi). Authenticator sends credential to the user's daemon via an authenticated push. Daemon holds it until the new device polls or receives a push notification. Latency: 2–10 seconds depending on daemon connectivity.
3. **QR round-trip (fallback)** — both devices offline or no daemon reachable. Authenticator displays a response QR containing the signed credential. New device scans it. Latency: manual (human scan). Always works; requires no network.

All three methods produce identical credential payloads. The new device cannot distinguish which channel delivered it.

**Implementation note:** New device tries LAN first (3s timeout), then falls back to daemon relay (10s timeout), then prompts user to use QR round-trip. No user configuration needed for the common case.

**Q2: Offline onboarding (QR round-trip fully specified)**

Full flow for QR round-trip:

1. New device generates challenge QR (Step 1 per §Device Onboarding Flow)
2. New device enters "waiting for QR response" mode (displays a second QR zone)
3. Operator opens authenticator, scans the challenge QR (Step 2 per §Device Onboarding Flow)
4. Authenticator displays the signed credential as a QR code (the response QR)
5. New device scans the response QR
6. New device decodes the credential: `{signature, device_id, device_pubkey, nonce, profile_handle, profile_public_key}`
7. New device verifies: `gpg --verify` signature using the profile's public key (embedded in the credential or pre-loaded)
8. On success: credential stored locally, device is live

The profile's public key must be available to the new device to verify the signature. Two options:
- **Pre-loaded**: the new device was given the public key at install time (e.g., bundled in the authenticator app's config, or scanned from a separate "identity QR")
- **Embedded in credential**: the authenticator includes the profile's public key in the credential payload; the new device trusts it on first-use (TOFU), then verifies against a known record on subsequent use

TOFU is acceptable for first onboarding. Subsequent credential refreshes must match the previously verified public key.

**Q3: Multi-profile support**

Yes. The authenticator may hold keys for multiple profiles. Each profile is a separate keyring entry:

```
authenticator/profiles/
  koad.json       ← koad's profile (keys + device registry)
  juno.json       ← Juno's profile (keys + device registry)
```

When scanning a challenge QR, the authenticator detects the `profile_handle` field and selects the corresponding keyring. If the scanned QR requests `profile: juno`, the authenticator signs with Juno's key. If the operator holds both profiles and both keys, they choose which identity to use.

**UX constraint:** The authenticator must make the selected profile visible during approval: "Signing in Dark Passenger as **juno** (not koad). [Switch]". Accidental cross-profile sign-ins must be impossible to miss.

**Q4: Credential expiry**

Policy: device credentials **persist until explicitly revoked**, with two exceptions:

- **Entity sessions** (Claude Code, opencode): credentials expire at session end (process exit). A new session generates a new credential.
- **Ring peer membership tokens**: expire per the terms of the ring bond (which has its own renewal policy — see SPEC-007 §3).

Permanent credentials for daemons and Dark Passenger are intentional: these long-running processes should not require periodic re-authorization. Revocation is the mechanism for removing access.

However: daemons and passengers must re-verify their credential against the profile's `active.json` **on every daemon restart** (not every request). If the device is absent from `active.json` on restart, the credential is rejected.

**Q5: Recovery when no old phone exists**

Out of scope for this spec. Companion spec required: **VESTA-SPEC-035** (Sovereign Recovery Protocol). Options include:

- Paper key recovery (entropy printed at gestation)
- Shamir Secret Sharing split across trusted contacts
- Social recovery via ring consensus

Until SPEC-035 exists, the practical answer is: keep an offline backup of the profile's root private key in a physically secure location. Loss of the root key without a backup means starting over with a new profile.

---

*Filed by Juno, 2026-04-03. Reviewed by Vesta, 2026-04-05. Open questions resolved in review. Remaining work: companion spec VESTA-SPEC-035 (key recovery) needed before this spec reaches canonical status.*
