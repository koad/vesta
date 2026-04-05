---
id: VESTA-SPEC-036
title: Dark Passenger Contextual Intelligence Layer — Sovereignty and Consumer Rights at Browse Time
status: draft
created: 2026-04-05
author: Vesta
applies-to: Dark Passenger Chrome extension, daemon, dataset plugin system, ring membership
---

# VESTA-SPEC-036: Dark Passenger Contextual Intelligence Layer

## Purpose

Extend the Dark Passenger (VESTA-SPEC-018) beyond profile augmentation into a general-purpose consumer sovereignty layer. When a ring member browses any product page, manufacturer site, service provider, or app store listing, the Dark Passenger surfaces relevant warnings, repairability scores, ToS grades, and sovereignty flags — inline, non-intrusively, without leaving the page, and without any data leaving the device.

This is the consumer rights use case of the Dark Passenger. The augmentation protocol (VESTA-SPEC-018) handles *identity* augmentation. This spec handles *contextual intelligence* — attaching sovereign knowledge to commercial and institutional web surfaces.

---

## 1. The Core Pattern

```
User visits: https://www.bestbuy.com/product/samsung-qn85c-85-inch-tv/...

Dark Passenger checks local dataset indexes:
  → iFixit:  repairability 3/10 — "Requires heat gun to open; adhesive everywhere"
  → Rossmann: "Samsung extended warranty voided by opening — repair shop hostile"
  → ToS;DR:  Samsung account grade C — "Broad data collection; forced arbitration clause"
  → Aegis:   No traps flagged for this specific product

Dark Passenger surfaces overlay:
  ┌─────────────────────────────────────────┐
  │  Repairability: 3/10  ⚠                │
  │  Right-to-repair: Hostile  ⚠           │
  │  ToS grade: C  ⚠                       │
  │  Sovereignty traps: None found  ✓      │
  │  [Details]  [Dismiss]                   │
  └─────────────────────────────────────────┘
```

The user gets actionable context at the moment of decision — while they are actively considering the purchase — not in a separate research workflow they will skip.

---

## 2. Dataset Plugin Architecture

Each dataset is a sovereign plugin: a local index maintained as flat files, distributed via git, with no cloud dependency. The extension queries only what is installed locally.

### 2.1 Plugin Format

A dataset plugin is a directory with:

```
~/.koad-io/dark-passenger/datasets/<plugin-id>/
  manifest.json       — plugin metadata, version, URL match patterns
  index/              — compressed lookup tables (keyed by CID, see VESTA-SPEC-027)
  sources.json        — upstream sync sources (git remotes, HTTP endpoints)
  last-sync           — timestamp of last successful sync
```

### 2.2 manifest.json Schema

```json
{
  "id": "ifixit-repairability",
  "name": "iFixit Repairability Scores",
  "version": "2026.04.01",
  "publisher": "community",
  "ring_requirement": "peer",
  "url_patterns": [
    "*.bestbuy.com/product/*",
    "*.amazon.com/dp/*",
    "*.bhphotovideo.com/c/product/*"
  ],
  "match_strategy": "product-title-fuzzy",
  "overlay_position": "top-right",
  "overlay_style": "badge"
}
```

### 2.3 Index Format

Dataset indexes are keyed by CID (per VESTA-SPEC-027). Each entry maps a product or entity CID to a structured record:

```json
{
  "cid": "k3mN7pQrX9wY2zA",
  "source_handle": "Samsung QN85C",
  "score": 3,
  "score_label": "Repairability Score",
  "max_score": 10,
  "summary": "Requires heat gun to open; adhesive throughout; battery replacement is destructive.",
  "url": "https://www.ifixit.com/repairability/samsung-qn85c",
  "last_updated": 1743811200
}
```

The extension never transmits the page URL to look up a product — it computes the CID locally using normalized product identifiers extracted from the page, and queries the local index. No network request is made for dataset lookups. The entire query is local.

### 2.4 URL-to-CID Resolution for Products

Product pages require a more complex CID derivation than profile pages. The extension uses a tiered extraction strategy:

1. **Structured data** — `<script type="application/ld+json">` product schema on the page; extract `name`, `gtin`, `mpn`
2. **OpenGraph** — `og:title` and `og:upc` if present
3. **URL pattern extraction** — ASIN from Amazon URLs, model number from BestBuy slugs
4. **Page title fallback** — normalized page title as last resort

The CID is computed from the best available product identifier using `koad.generate.cid(koad.generate.handle(identifier))`. All tiers produce deterministic CIDs for the same product, allowing the index to be pre-built from canonical identifiers (UPC, ASIN, manufacturer model number).

---

## 3. First-Party Datasets

These datasets are maintained by koad:io entities and distributed as part of the peer ring:

| Dataset | Maintainer | Domain | Ring Tier |
|---|---|---|---|
| Aegis trap registry | Aegis entity | Software/services sovereignty traps | Free (base layer) |
| ToS;DR mirror | Janus entity | Terms of service grades | Free (base layer) |
| Rossmann repair-hostility index | Janus entity (from Rossmann wiki) | Vendor lock-in, warranty practices | Peer ring |
| iFixit repairability index | Janus entity (from iFixit API) | Hardware repairability scores | Peer ring |
| Sovereign device registry | Argus entity | Hardware with verified open firmware | Peer ring |

**Free tier (Aegis + ToS;DR)**: Available to all ring members without sponsorship. This is the base sovereignty layer — the minimum context everyone deserves while browsing.

**Peer ring datasets**: Available to sponsoring members. These datasets require ongoing curation effort and provide deeper research value.

### 3.1 Aegis Trap Registry

Aegis maintains a registry of sovereignty traps in software and services — practices that reduce user agency, lock data, surveil without consent, or create exit barriers. The Dark Passenger surfaces these inline when a user visits a product or service page.

Trap categories:
- `data-hostage` — proprietary formats with no export path
- `account-required` — device or software requires cloud account to function
- `forced-subscription` — one-time purchase converted to subscription without consent
- `surveil` — documented broad data collection beyond stated functionality
- `arbitration` — forced arbitration clauses that waive class action rights
- `repair-hostile` — documented practices that penalize third-party repair

### 3.2 ToS;DR Mirror

ToS;DR (https://tosdr.org) assigns letter grades (A–E) to service terms. koad:io mirrors this dataset locally for offline lookup. The Janus entity maintains the sync and curates additions for services not yet rated.

When a user creates an account or signs up for a service, the Dark Passenger surfaces the ToS;DR grade before the user clicks "I agree."

### 3.3 Rossmann Repair-Hostility Index

Louis Rossmann's wiki documents specific manufacturer practices: warranty void stickers, glued components, soldered RAM, denied parts sales, and dealer-only diagnostic software. This is the most actionable repair intelligence available for consumer hardware.

The Rossmann index is curated from the Rossmann Group wiki (rossmanngroup.com/wiki) by the Janus entity with explicit attribution. The overlay for this dataset links back to the original wiki page.

**Rossmann collaboration angle**: This dataset should be pitched to Louis Rossmann directly. His audience is the koad:io audience — builders, fixers, right-to-repair advocates. Distributing his research as a sovereign, local, privacy-preserving dataset that surfaces at purchase time is his philosophy made into infrastructure. No API key. No phone home. Just his knowledge, available at the moment it matters most.

---

## 4. Community Dataset Plugins

Peer ring members can publish and subscribe to community dataset plugins. The community plugin system is analogous to a package registry — but sovereign, git-distributed, and with no central authority.

### 4.1 Publishing a Plugin

```bash
# Create the plugin directory
mkdir ~/.koad-io/dark-passenger/datasets/ewg-cosmetics

# Add manifest.json and index/
# Publish as a git repo (GitHub, Gitea, or any git host)

# Register with the peer ring dataset registry
koad-io dataset publish ewg-cosmetics https://github.com/yourname/dp-ewg-cosmetics
```

### 4.2 Subscribing to a Plugin

```bash
koad-io dataset install ewg-cosmetics https://github.com/yourname/dp-ewg-cosmetics
```

Installation clones the repo, validates the manifest, and adds the plugin to the extension's active dataset list. Sync is handled by the daemon's dataset worker.

### 4.3 Trust Model for Community Datasets

Community datasets are signed by their publisher. The extension checks the signature before loading any dataset. If the signature is invalid or the dataset has been tampered with, the extension refuses to load it.

Publishers establish trust via:
1. **Ring membership** — peer ring members are implicitly trusted for dataset publishing
2. **External publishers** — koad or Janus can co-sign an external publisher's dataset to vouch for it
3. **Self-sovereign external** — users can manually trust unsigned datasets by explicit consent

---

## 5. Overlay UX

The overlay must be:
- **Non-intrusive** — does not block the page; appears as a badge or collapsed sidebar
- **Dismissible** — one-click dismiss; per-domain or per-session dismiss memory
- **Useful at a glance** — grade letter or score visible without expanding
- **Linkable** — every data point links to its source (iFixit page, ToS;DR record, Rossmann wiki entry)
- **Honest about gaps** — when no data is found, the overlay says "no data found" rather than implying something is fine

### 5.1 Overlay Positions

The manifest's `overlay_position` field controls placement:
- `top-right` — fixed badge, collapses to icon after 5 seconds
- `bottom-left` — persistent sidebar tab
- `inline` — injected into the page near the product title or CTA (requires an `inject.css` for the target site)

### 5.2 Composite Overlays

When multiple datasets match a page, the extension composes a single overlay rather than stacking individual ones. The composite overlay:
- Shows one row per dataset with a relevant signal (score, grade, flag count)
- Sorts by severity (worst signal first)
- Expands to per-dataset detail on click

### 5.3 Purchase-Gate Mode

An optional ring-level preference: **purchase-gate mode**. When enabled, the overlay becomes a confirmation step before any "Add to Cart" or "Buy Now" button is clickable. The user must either dismiss the overlay or acknowledge each flagged issue before proceeding.

This is opt-in. It is never the default. It is available for users who want stronger friction before purchases involving flagged products.

---

## 6. Sovereignty Architecture

### 6.1 Zero Telemetry Guarantee

The contextual intelligence layer operates entirely locally:
- Dataset indexes are stored on the user's device
- URL-to-CID resolution happens in the extension process (no network call)
- All dataset queries are local file reads or in-memory lookups
- The daemon is not involved in per-page dataset queries (only in dataset sync)
- No browse history, no page URL, no query log is sent anywhere

This is the structural guarantee, not a policy claim. There is no telemetry endpoint in the protocol. There is no place in the architecture where a URL could be transmitted for a dataset query.

### 6.2 Sync Privacy

Dataset updates sync from git remotes or HTTP endpoints. The sync process uses the CID pattern (VESTA-SPEC-027) for all inter-kingdom queries. Direct git pulls to public repos are not privacy-sensitive — the plugin is public, and the fetch URL is the plugin repo, not any user-specific query.

### 6.3 Dataset Provenance

Every dataset record includes a `source_url` pointing to its original research. The overlay always shows "Source: iFixit" (or equivalent) and links to the underlying record. koad:io does not present third-party research as its own — it distributes it, attributes it, and makes it accessible at browse time.

### 6.4 Ring Integration — Tiered Access

```
Free tier: Aegis trap registry + ToS;DR mirror
  → These are sovereign baselines; everyone deserves them

Peer ring: Rossmann index + iFixit + first-party specialist datasets
  → Curation effort justifies ring membership

Community contributing members: Can publish to the ring dataset registry
  → Contribution is the access mechanism for community plugins
```

---

## 7. Dataset Sync Architecture

The daemon manages dataset sync as a background worker:

```
passenger.json (daemon config):
{
  "workers": [
    {
      "id": "dataset-sync",
      "type": "cron",
      "schedule": "0 3 * * *",   // 3am daily
      "command": "koad-io dataset sync --all"
    }
  ]
}
```

The sync worker:
1. Iterates installed datasets
2. Checks `last-sync` timestamp against the dataset's `update_frequency` in its manifest
3. Pulls from configured `sources.json` git remotes or HTTP endpoints
4. Validates signatures on updated indexes
5. Atomically replaces the local index (write to temp, rename — no partial reads)
6. Updates `last-sync`

The extension reads from the local index only. It does not wait for sync to complete. If the index is temporarily unavailable during atomic replacement, the extension degrades gracefully (shows "checking..." and retries).

---

## 8. Relation to Other Specs

| Spec | Relationship |
|---|---|
| VESTA-SPEC-018 (Dark Passenger Augmentation Protocol) | This spec extends Dark Passenger from profile augmentation to contextual intelligence; same extension, new dataset query path |
| VESTA-SPEC-027 (CID Privacy Primitive) | CID-keyed index lookups are how the extension queries datasets without transmitting page URLs |
| VESTA-SPEC-009 (Daemon Worker Specification) | Dataset sync runs as a daemon worker per the worker spec |
| koad/aegis | Aegis entity maintains the first-party trap registry dataset |

---

## 9. Implementation Sequence

1. **Phase 1** — Aegis trap registry dataset plugin (local index, sync from aegis git repo, overlay for flagged services). Blocked on: Aegis gestation.
2. **Phase 2** — ToS;DR mirror plugin. Janus entity runs the sync worker; index distributed to ring members.
3. **Phase 3** — Community plugin infrastructure: `koad-io dataset install/publish` commands, signing protocol.
4. **Phase 4** — Rossmann index plugin. Requires discussion with Louis Rossmann about attribution and distribution model.
5. **Phase 5** — iFixit plugin via iFixit API (open API, no key required for basic repairability data).

Phase 1 and 2 can ship with the first Dark Passenger release. Phases 3–5 are post-launch.

---

## Open Questions

None. This spec is complete for the architecture phase. Implementation questions will be tracked per-phase in the relevant entity repos.

---

*Filed by Vesta, 2026-04-05. Developed from koad's insight (via issue #71): "The Dark Passenger becomes a consumer protection layer that delivers sovereignty and rights information at the moment of highest relevance." The Rossmann collaboration angle is koad's framing — preserved verbatim because it is accurate and useful for distribution strategy.*
