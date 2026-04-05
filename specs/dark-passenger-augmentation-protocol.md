---
id: VESTA-SPEC-018
title: Dark Passenger Augmentation Protocol
status: canonical
created: 2026-04-03
updated: 2026-04-05
author: Juno (from direct description by koad)
owner: vesta
applies-to: daemon, Dark Passenger Chrome extension, ring members
changelog:
  - "2026-04-05: Promoted draft → canonical. Resolved open questions (§Open Questions replaced with §Resolved Decisions). Reviewed by Vesta. Added §Security Note."
---

# VESTA-SPEC-018: Dark Passenger Augmentation Protocol

## Purpose

Define the protocol by which a koad:io daemon hosts web augmentation packages, and the Dark Passenger Chrome extension fetches, applies, and wires those augmentations onto any website a ring member visits.

## Core Model

Dark Passenger is not limited to domains the profile owner controls. It operates on **any URL** — including third-party platforms (social networks, forums, old sites, services the profile owner uses but doesn't host).

When a ring member visits a URL associated with a profile in their ring, the extension:
1. Resolves which profile "owns" that URL (via namespace profile lookup)
2. Fetches the augmentation package for that URL pattern from the profile's daemon
3. Injects the augmentation: CSS, HTML, JS, and hook wires
4. Hook-wired UI elements call back to the daemon, which executes the registered handler

The public sees the original page. Ring members see the sovereign layer on top.

---

## The Augmentation Manifest

Each daemon hosts an augmentation manifest — the web equivalent of `passenger.json`. It maps URL patterns to augmentation packages and ring access levels.

### Manifest Format

```json
{
  "augmentations": [
    {
      "id": "myspace-koad",
      "pattern": "myspace.com/koad*",
      "ring": "any",
      "package": "/augments/myspace-koad/",
      "hooks": [
        { "id": "contact", "label": "Message via daemon", "endpoint": "/hooks/contact" },
        { "id": "subscribe", "label": "Subscribe to feed", "endpoint": "/hooks/subscribe" }
      ]
    },
    {
      "id": "github-koad-private-layer",
      "pattern": "github.com/koad*",
      "ring": "inner",
      "package": "/augments/github-koad-inner/",
      "hooks": [
        { "id": "issue-juno", "label": "File to Juno", "endpoint": "/hooks/file-issue" }
      ]
    }
  ]
}
```

### Fields

- **`pattern`** — URL glob pattern this augmentation applies to
- **`ring`** — access level: `any` (all ring members), `inner`, `peer`, or a named bond type
- **`package`** — path on the daemon where augmentation assets live
- **`hooks`** — UI elements to inject that wire back to daemon endpoints

---

## Augmentation Package Structure

An augmentation package is a directory hosted on the daemon:

```
/augments/myspace-koad/
  manifest.json     — metadata, version, ring requirement
  inject.css        — CSS overrides (avatar, background, layout fixes)
  inject.js         — behavior augmentations
  inject.html       — HTML fragments to insert (buttons, panels, overlays)
  hooks.json        — hook endpoint bindings for injected UI
```

The extension fetches these assets from the daemon on first visit to a matching URL, and caches them for the session. Cache invalidation is triggered by daemon-pushed version bumps.

---

## Hook Architecture

Injected buttons and UI elements wire back to the daemon via HTTP calls to registered hook endpoints. This mirrors `passenger.json` workers — same routing model, different trigger source.

```
Browser (Dark Passenger) → button click
  ↓
Extension → POST /hooks/contact (to daemon)
  ↓
Daemon executes registered handler
  ↓
Response (optional) → extension surfaces result in page overlay or sidebar
```

The daemon is the execution host. The extension is the event wire. The browser is the UI surface.

Hook endpoints on the daemon:
- Can execute any registered worker (send message, file issue, update state, notify entity)
- Return responses that the extension can surface inline (toast, sidebar, overlay)
- Are scoped by ring level — the daemon checks the caller's identity before executing

---

## Ring-Based Access Control for Augmentations

Not all ring members see the same augmentation layer. The manifest's `ring` field controls what gets served:

| Ring Level | What They See |
|---|---|
| `any` | Public augmentations — avatar fix, basic layout, public contact buttons |
| `outer` | Public + outer-ring overlays (annotations, follow buttons) |
| `inner` | Full augmentation package + inner-ring hooks (file issue, direct message) |
| `peer` | Everything + peer-tier tools (raw hook access, daemon state panel) |

The extension presents its ring credential (namespace identity + signature) when fetching augmentation packages. The daemon serves the appropriate package tier.

---

## Peer-Shared Augmentations

Profile owners can share augmentation packages with specific ring members, allowing peers to:

1. **Receive** augmentation packages for URLs they visit (the normal flow)
2. **Contribute** augmentation snippets to a profile owner's package (peer collaboration on the layer)
3. **Distribute** their own augmentation packages to their ring members for URLs they own/use

Example: koad shares a `github.com/koad/*` augmentation with Juno's ring tier. When Juno visits koad's GitHub, Juno sees koad's sovereign layer — quick-file buttons, status overlays, whatever koad has configured.

The augmentation package is sovereign: hosted on koad's daemon, served by koad's rules, revocable at any time by removing from the manifest.

---

## URL Association Model

The extension needs to know which profile "owns" a given URL to know where to fetch augmentations.

Three resolution methods (in order):

### Method 1 — TXT Record Proof (for owned domains)
Profile includes a domain with TXT record proof (Keybase-style). Extension resolves URL domain → looks up ring profiles → checks for TXT-proven match.

### Method 2 — Platform Handle Mapping (for third-party platforms)
Profile includes platform handles in a structured section:
```json
{
  "platforms": {
    "myspace": "koad",
    "twitter": "koadio",
    "github": "koad",
    "reddit": "u/koadio"
  }
}
```
Extension matches URL pattern against platform handle mappings in ring profiles.

### Method 3 — Explicit Augmentation Share
Profile owner explicitly shares an augmentation package with specific ring members for a URL pattern. No domain proof needed — the share is the authorization.

---

## The MySpace Scenario (Reference Example)

1. koad has a MySpace page at `myspace.com/koad` (legacy, broken CSS, limited functionality)
2. koad's daemon hosts `/augments/myspace-koad/` — fixes the CSS, injects his current avatar, adds a "contact via daemon" button
3. koad's profile includes `"myspace": "koad"` in platform handles
4. A ring member visits `myspace.com/koad`
5. Extension resolves: this URL matches koad's MySpace handle → fetch augmentation from koad's daemon
6. Extension injects the package: page now shows koad's proper avatar, fixed layout, added buttons
7. Ring member clicks "Contact via daemon" → POST to koad's daemon `/hooks/contact` → daemon routes to Juno for response
8. Public visitors see the original MySpace page. Ring members see koad's sovereign overlay.

---

## Extension Responsibilities

The Dark Passenger extension:

- Maintains a local cache of ring profiles (refreshed periodically from daemon)
- On every page load: checks URL against all ring profile URL associations
- On match: fetches and injects the appropriate augmentation package (ring-gated)
- Wires hook endpoints to injected UI elements
- Presents namespace identity credential when fetching gated packages
- Surfaces hook responses inline (sidebar, toast, overlay)

---

## Daemon Responsibilities

The daemon:

- Hosts augmentation manifests at `GET /augments/manifest.json`
- Serves augmentation packages at `GET /augments/{id}/`
- Validates ring credentials on gated package requests
- Executes hook calls at `POST /hooks/{id}`
- Notifies connected extension instances of package updates (version bump push)

---

## Relation to Other Specs

- **VESTA-SPEC-014 (Kingdom Peer Connectivity):** Daemon-to-daemon channels are the backbone for ring credential verification in augmentation requests
- **VESTA-SPEC-017 (Operator Identity Verification):** Hook calls to the daemon use the same identity verification chain before executing
- **VESTA-SPEC-016 (Context Bubble Protocol):** Augmentation overlays are one surface for context bubble display in the browser layer

---

## Resolved Decisions (Vesta review, 2026-04-05)

**Q1: Offline daemon — serve stale cached package or degrade gracefully?**

Decision: **Serve stale cache with a staleness indicator; never hard-fail.**

The extension SHOULD cache augmentation packages locally (in browser storage) with a version tag and last-fetched timestamp. On page load, if the daemon is unreachable, serve the cached version. The injected augmentation SHOULD include a subtle visual indicator (e.g., a small icon or tooltip) that the package is stale and the daemon is offline. Duration before showing the indicator: 24 hours since last successful fetch. After 7 days of staleness, degraded mode: show only cached CSS/HTML, do not wire hook buttons (since hooks require live daemon to execute).

**Q2: Peer augmentation contributions — push model or owner-only?**

Decision: **Owner-only for package updates; peers contribute via proposals.**

The augmentation package is sovereign — only the profile owner can update what gets served from their daemon. Peers who want to contribute (e.g., suggest a better CSS fix for a platform) submit proposals via GitHub Issues or daemon messages. The profile owner reviews and includes the contribution in the next package update if accepted. This preserves sovereignty: a ring member cannot change what other ring members see on your pages. There is no merge authority for augmentation packages.

**Q3: Multiple ring members with augmentations for the same URL — priority order?**

Decision: **Profile owner's package wins; additional ring packages are additive, not conflicting.**

When visiting a URL that multiple ring members have augmentations for:
1. The URL is resolved to its primary "owner" profile (via URL association model — Method 1 TXT, Method 2 platform handle)
2. Only the primary owner's augmentation package is applied for that URL
3. Ring members who have *shared* an augmentation for the same URL pattern (via explicit share, Method 3) contribute additive overlays — their packages are injected after the primary, but MUST NOT remove or modify the primary owner's injections
4. If no primary owner is resolvable (no URL claim), the oldest-registered ring member's package is used; ties are broken by ring level (closer ring wins)

**Q4: Hook security — daemon verification that hook call came from a legitimate ring member's extension?**

Decision: **Ring member presents a signed session token issued at ring join time; daemon verifies signature.**

Hook requests from the extension include an `Authorization` header: `Bearer {ring-session-token}`. The ring session token is a short-lived JWT (or equivalent signed structure) issued by the profile owner's daemon when the ring member's extension authenticates at setup. The token:
- Is signed by the profile owner's entity key
- Includes: ring member identity, ring level, expiry (default 24h)
- Is refreshed by the extension in the background before expiry

The daemon verifies the token signature against the profile owner's own key (the daemon holds its own private key and can self-verify). This means the daemon doesn't need to call out to a third party for every hook — it's a self-contained verification against the token it originally issued. Spoofed HTTP calls without a valid token are rejected with HTTP 401.

---

## Security Note

The augmentation injection model has an inherent attack surface: if the daemon is compromised, its augmentation packages could inject malicious JavaScript into any page a ring member visits. Mitigations:

1. The extension SHOULD verify a package's content hash against the manifest before injecting
2. Packages SHOULD be reviewed/signed by the profile owner before publication (using entity GPG key on the manifest)
3. Extension SHOULD enforce a Content Security Policy on injected JS (no `eval`, no external scripts)
4. Hook endpoints SHOULD use HTTPS (TLS) for all daemon communication, even on LAN

---

*Filed by Juno, 2026-04-03. Developed from direct description by koad of the Dark Passenger augmentation model — significantly expands the scope of what was captured in Iris's platform-vision-sovereign-web.md. The key insight: the daemon is an augmentation server, the extension is a thin client, and the model works on any URL — not just owned domains.*

*Promoted to canonical by Vesta, 2026-04-05. Open questions resolved above.*
