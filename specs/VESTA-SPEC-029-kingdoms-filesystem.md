---
status: draft
id: VESTA-SPEC-029
title: "Kingdoms Filesystem — FUSE-Mounted Sovereign Namespace with Git Protocol"
type: spec
version: 0.1
date: 2026-04-04
owner: vesta
description: "A FUSE-mounted, git-addressable namespace organized around entity ownership. Entities own their namespace subtree. Access is governed by trust bonds. The kingdoms:// protocol enables git operations across the network."
related-specs:
  - VESTA-SPEC-007 (Trust Bond Protocol)
  - VESTA-SPEC-009 (Daemon Specification)
  - VESTA-SPEC-014 (Kingdom Peer Connectivity Protocol)
  - VESTA-SPEC-027 (CID Privacy Primitive)
  - VESTA-SPEC-028 (URL as Meeting Coordinate)
---

# VESTA-SPEC-029: Kingdoms Filesystem

**Authority:** Vesta (platform stewardship). This spec defines the sovereign namespace filesystem: its mount structure, access model, git protocol integration, and how it relates to the daemon peer network.

**Scope:** FUSE mount layout, namespace hierarchy, access tiers (private/public/shared), the `kingdoms://` git protocol, local vs. remote access mechanics, and differences from Keybase's KBFS model.

**Consumers:**
- Vulcan (implementation)
- Daemon (auth backend)
- All entities (namespace users)
- koad (human operator and namespace root)

**Status:** Draft. Originated from koad conversation 2026-04-04. Spec this before Vulcan begins implementation.

---

## 1. Motivation

Keybase provided two powerful primitives:
1. **KBFS** — a FUSE-mounted filesystem at `/keybase/` with `private/`, `public/`, and `team/` namespaces, cryptographically backed
2. **Keybase Git** — git repos hosted on the Keybase namespace (`keybase://private/alice/notes`)

koad:io needs an equivalent, but organized around **entities** rather than human users. Entities are the principals. They own namespaces. They grant access via trust bonds, not user invites.

The result: `/kingdoms/` — a FUSE-mounted namespace where every entity has a subtree, and the `kingdoms://` protocol lets you git-clone across it.

---

## 2. Namespace Structure

```
/kingdoms/
├── <url_cid>/              ← URL-addressed namespace (see §2.4)
├── <key_fingerprint>/      ← entity identity namespace (see §10.5)
├── koad/                   ← handle alias → resolves to fingerprint
│   ├── private/       ← koad-only; no external read
│   ├── public/        ← world-readable
│   └── shared/
│       ├── juno/      ← koad shares with Juno
│       └── vulcan/    ← koad shares with Vulcan
│
├── juno/
│   ├── private/
│   ├── public/
│   └── shared/
│       └── koad/      ← Juno shares with koad
│
├── vulcan/
│   ├── private/
│   ├── public/
│   └── shared/
│       └── juno/      ← Vulcan shares with Juno
│
└── ...                ← one subtree per entity/kingdom
```

### 2.4 URL-Addressed Namespaces

Not all namespaces belong to entities. Any URL can address a namespace via its CID (VESTA-SPEC-027):

```
URL: https://github.com/koad
handle: httpsgithubcomkoad
CID: GdYZWjcjY6Y2XonnM

→ /kingdoms/GdYZWjcjY6Y2XonnM/   ← namespace for everything tied to that URL
```

This namespace is where you store **augments** — notes, annotations, context bubbles, extensions, files — tied to that specific URL. Whoever knows the CID (i.e., anyone who can derive it from the URL) can address the namespace. Access control is still governed by trust bonds.

```
/kingdoms/GdYZWjcjY6Y2XonnM/
  notes.md             ← koad's notes about this URL
  context.json         ← structured context bubble
  augments/            ← browser extension augments
    highlight.json
    sidebar.md
  shared/koad/         ← bilateral with koad (same model as entity shared/)
```

The browser extension (passenger) loads this namespace automatically when you visit the URL:

```
1. Visit https://github.com/koad
2. Passenger: derive CID → GdYZWjcjY6Y2XonnM
3. Passenger: load /kingdoms/GdYZWjcjY6Y2XonnM/
4. Passenger: inject augments into page, surface notes, load context
```

Zero configuration. Zero explicit linking. The URL IS the address. Stand on the page; the page's augments load.

This is the filesystem layer of the context bubble architecture. The CID is the stable coordinate. The kingdoms namespace is the store. The passenger is the reader.

### 2.5 Agent-Curated Warnings and Reputation

The URL-CID namespace is also where agents file **curated intelligence** about URLs — warnings, reputation data, sourced citations from known authorities:

```
/kingdoms/GdYZWjcjY6Y2XonnM/
  augments/                    ← personal browser augments
  warnings/
    sibyl.json                 ← Sibyl's research-based warnings
    rossman.json               ← sourced from Rossman's consumer rights wiki
    veritas.json               ← Veritas fact-check results
  reputation/
    summary.json               ← aggregated ring reputation
    sources.json               ← citation index (external authoritative sources)
  citations/
    rossman-wiki/              ← pulled articles from Ross Mann's wiki
    gdpr-violations/           ← GDPR enforcement database entries
    bbb-complaints/            ← BBB complaint data
```

**How it works:**

Sibyl runs a standing worker that:
1. Monitors configured external sources (Rossman wiki, GDPR tracker, scam databases, etc.)
2. For each URL mentioned, derives the CID
3. Writes a structured entry to `/kingdoms/<url_cid>/warnings/<source>.json`
4. Commits and pushes to the ring

When the passenger loads a URL:
1. Derives CID
2. Loads `/kingdoms/<url_cid>/warnings/` across all entities in the ring it has bonds with
3. Surfaces relevant warnings in the browser UI — inline, non-intrusive, source-attributed

**The sovereignty difference from centralized warning systems:**

| System | Who decides what gets flagged | Who controls the data |
|--------|------------------------------|----------------------|
| Google Safe Browsing | Google | Google |
| Web of Trust (WOT) | Crowd + WOT company | WOT company |
| Browser vendor warnings | Browser vendor | Browser vendor |
| kingdoms warnings | Your ring + agents you authorized | You, on your daemon |

No central authority can unflag a URL to protect a business relationship. No vendor can silence a warning you filed. The ring's collective intelligence is yours. The sources are ones you chose to hook in.

**Ring-scoped reputation:**

Warnings written by Sibyl in koad's ring appear at `/kingdoms/koad/shared/juno/` (bilateral) or directly at the URL-CID namespace — visible to everyone in the ring with a bond. A peer ring from a journalist or researcher who shares bonds with koad can also pull these in, extending the reputation graph without any central aggregator.

This is Web of Trust done right: trust-scoped, source-attributed, agent-maintained, sovereign.

---

### 2.1 Visibility Tiers

| Path | Reader | Writer | Backing auth |
|------|--------|--------|--------------|
| `/kingdoms/<entity>/public/` | Anyone | Entity | None (anonymous read) |
| `/kingdoms/<entity>/private/` | Entity only | Entity | Entity keys (daemon enforces) |
| `/kingdoms/<entity>/shared/<who>/` | Entity + `<who>` | Entity + `<who>` | Trust bond required |

### 2.2 Shared Space: Bilateral, Symmetric, Same Backing Store

The key design insight — and the departure from Keybase:

```
/kingdoms/koad/shared/juno/   ←──┐
                                  ├── same backing store
/kingdoms/juno/shared/koad/   ←──┘
```

Both paths are live. Both resolve to identical content. There are no symlinks — the FUSE layer resolves both paths to the same inode at the routing level. From either participant's perspective, the folder is in their namespace. Neither is a "guest" in the other's space. The shared store exists once, accessible from both directions equally.

This is the clean model Keybase approximated with `private/alice,bob/` — but the Keybase path is order-dependent and requires knowing both names. Here, each participant navigates via their own namespace:

- koad opens `/kingdoms/koad/shared/juno/` — sees the shared space from his root
- Juno opens `/kingdoms/juno/shared/koad/` — sees the same files from her root
- A third entity with bonds to both could navigate via either path

**Infinitely routable:** Because the paths are equivalent and each resolves correctly from any entity that has a trust bond with either participant, no out-of-band link passing is needed. The path is always `my-namespace/shared/their-name` — readable, memorable, unsurprising.

### 2.3 Backing Key for Shared Spaces

The underlying storage for a bilateral shared space is keyed by the **sorted pair** of entity names:

```
shared:{koad,juno}   →   backs both /kingdoms/koad/shared/juno/
                                 and /kingdoms/juno/shared/koad/
```

Sorting ensures there is exactly one backing store per pair regardless of which direction the path is approached from.

---

## 3. The `kingdoms://` Protocol

### 3.1 URL Structure

```
kingdoms://<entity>/<visibility>[/<who>]/<path>
```

Examples:
```
kingdoms://koad/alice                         → /kingdoms/koad/public/alice.git
kingdoms://koad/private/dotfiles              → /kingdoms/koad/private/dotfiles.git
kingdoms://juno/shared/koad/session-notes     → /kingdoms/juno/shared/koad/session-notes.git
kingdoms://vulcan/public                      → /kingdoms/vulcan/public/ (directory browse)
```

### 3.2 Git Operations

```bash
# Clone a public repo from koad's namespace
git clone kingdoms://koad/alice

# Clone a repo from Juno's shared-with-koad space
git clone kingdoms://juno/shared/koad/session-notes

# Add as a remote
git remote add kingdoms kingdoms://koad/private/myproject
git push kingdoms main

# Browse a public namespace
ls kingdoms://vulcan/public/
```

### 3.3 Protocol Handler: `git-remote-kingdoms`

A git remote helper binary installed at a PATH location git can find:

```
~/.koad-io/bin/git-remote-kingdoms
```

This binary:
1. Parses the `kingdoms://` URL
2. Resolves the entity + path to a local FUSE mount path OR a remote daemon address
3. Delegates to `git-remote-ext` or directly handles the git pack protocol
4. Enforces access via trust bond verification (delegates auth check to daemon)

```bash
# git calls this automatically when it sees kingdoms:// remotes
git-remote-kingdoms $REMOTE_NAME $URL
```

---

## 4. FUSE Mount

### 4.1 Mount Point

```
/kingdoms/
```

System-wide. Mounted at boot via `/etc/fstab` or systemd unit. Requires `koad-kingdoms` daemon or the existing entity daemon to serve it.

```bash
# Mount command
koad kingdoms mount

# Unmount
koad kingdoms unmount

# Status
koad kingdoms status
```

### 4.2 Local vs. Remote Subtrees

The FUSE implementation distinguishes two backing modes:

**Local entity** (entity runs on this machine):
- `/kingdoms/koad/` backed by local filesystem at `~/.kingdom/koad-fs/` or similar
- No network required; daemon enforces access locally via entity keys

**Remote entity** (entity runs on another machine):
- `/kingdoms/juno/` backed by Juno's daemon on fourty4 (via SPEC-014 peer connection)
- FUSE layer fetches files from remote daemon on access
- Read cache with configurable TTL
- Writes go direct to remote daemon, synchronous

Visibility from a machine:
- Local entities: full read/write (subject to access tier)
- Remote entities: only `public/` and `shared/<you>/` are accessible
- Remote `private/`: not mountable; returns EACCES

### 4.3 Caching

```
~/.koad-io/.kingdoms-cache/
  <entity>/
    public/       ← cached public files, TTL 5min
    shared/<who>/ ← cached shared files, TTL 1min
```

Cache is write-through: writes go to daemon immediately, cache is invalidated on write.

---

## 5. Git Repo Storage

### 5.1 Bare Repos

Under each namespace, git repos are stored as bare repos:

```
/kingdoms/koad/public/
  alice.git/            ← bare git repo
  io.git/               ← bare git repo
  README.md             ← namespace index (optional)
```

### 5.2 CID Addressing

Every repo in the kingdoms filesystem gets a CID (VESTA-SPEC-027):

```bash
# CID of the canonical URL for this repo
cid("kingdoms://koad/alice") → "GdYZWjcjY6Y2XonnM"
```

The CID provides stable addressing even if the namespace path changes. A CID can be resolved to a kingdoms URL via the daemon's namespace registry:

```
kingdoms://cid/GdYZWjcjY6Y2XonnM → resolves → kingdoms://koad/alice
```

### 5.3 Repo Initialization

```bash
# Create a new repo in koad's public namespace
git init --bare /kingdoms/koad/public/myproject.git

# OR via koad:io command (preferred)
koad kingdoms init koad/public/myproject

# Clone and push
git clone kingdoms://koad/myproject
cd myproject && git push kingdoms main
```

---

## 6. Access Control

### 6.1 Trust Bond as Grant

Access to `private/` and `shared/` paths requires a trust bond:

**Bond type for filesystem access:**
```yaml
---
type: filesystem-access
from: juno
to: koad
paths:
  - /kingdoms/juno/shared/koad/
access: read-write
created: 2026-04-04
---
```

The daemon reads this bond at mount time. Any FUSE access request to `/kingdoms/juno/shared/koad/` by a process authenticated as koad is allowed.

### 6.2 Authentication of Processes

How does the FUSE layer know which entity is making a request?

- **Local process**: Use Unix UID/GID. koad's processes run as UID `koad`; Juno's processes run as UID `juno`. The FUSE layer maps UID → entity identity.
- **Remote access**: Authenticated via daemon peer key exchange (SPEC-014). The requesting daemon presents its entity key; the FUSE backing daemon verifies the bond.

### 6.3 Anonymous Access to public/

No auth required for reads to any `/kingdoms/<entity>/public/` path. The FUSE layer serves these as world-readable.

For remote access to another entity's `public/`:
- No bond needed
- Daemon serves via HTTP or direct peer protocol

---

## 7. Storage Backends (Pluggable, Self-Hosted)

Keybase's KBFS stores files on AWS S3 — buckets that Keybase controls. When Keybase shuts down, the files are gone.

kingdoms takes the opposite position: **each entity controls their own storage backend.** The daemon doesn't care what backs `/kingdoms/<entity>/` — it's a configuration decision per entity.

### 7.1 Supported Backends

| Backend | Use Case | Config Key |
|---------|----------|------------|
| **Local disk** | Default. `~/.kingdom-fs/<entity>/` on the entity's machine | `KINGDOMS_BACKEND=local` |
| **S3-compatible** | AWS S3, Cloudflare R2, MinIO, Backblaze B2 | `KINGDOMS_BACKEND=s3` |
| **NAS / network mount** | Synology, TrueNAS, NFS | `KINGDOMS_BACKEND=path:/mnt/nas/kingdoms/` |
| **Distributed** | IPFS-pinned blobs (future) | `KINGDOMS_BACKEND=ipfs` |

The daemon reads `KINGDOMS_BACKEND` from `.env` and routes all filesystem operations accordingly.

### 7.2 Per-Entity Backend Configuration

Each entity configures their own backing store independently:

```env
# ~/.juno/.env
KINGDOMS_BACKEND=s3
KINGDOMS_S3_BUCKET=juno-kingdoms
KINGDOMS_S3_REGION=us-east-1
KINGDOMS_S3_ENDPOINT=https://s3.amazonaws.com  # or MinIO, R2, etc.
```

```env
# ~/.koad/.env (the human operator's daemon)
KINGDOMS_BACKEND=local
KINGDOMS_LOCAL_PATH=/mnt/nas/kingdoms/koad/
```

### 7.3 Bilateral Shared Space — Co-Hosted

For shared spaces (Section 2.2), the bilateral store lives on one entity's backend by default — typically the one who initiated the shared space. The FUSE layer on the other entity's machine accesses it via the daemon peer protocol (SPEC-014).

If both parties want redundancy, they can mirror: both backends hold a copy, and writes sync via daemon-to-daemon replication. The backing key (`shared:{koad,juno}`) is stable regardless of which replica serves a given request.

### 7.4 Sovereignty Guarantee

The storage is yours because:
1. You configure the backend
2. The credentials for the backend (S3 key, NAS password) stay in your `.env` — never leave your machine
3. You can switch backends: `juno kingdoms migrate --to s3` moves the data
4. You can export: `juno kingdoms export --path ./backup/` dumps everything to local disk

If the daemon dies, the files are still in your S3 bucket / NAS / local path. No kingdoms.io to go down.

---

## 8. Differences from Keybase KBFS

| Dimension | Keybase KBFS | kingdoms |
|-----------|-------------|----------|
| Principal | Human user | Entity (AI or human) |
| Namespace root | `/keybase/` | `/kingdoms/` |
| Private | `/keybase/private/alice/` | `/kingdoms/alice/private/` |
| Public | `/keybase/public/alice/` | `/kingdoms/alice/public/` |
| Shared | `/keybase/private/alice,bob/` (order-dependent, joint) | `/kingdoms/alice/shared/bob/` AND `/kingdoms/bob/shared/alice/` (same store, both live) |
| Teams | `/keybase/team/teamname/` | Trust rings (SPEC-014) |
| Auth | Keybase identity service | Trust bonds (SPEC-007) + entity keys |
| Git | `keybase://` protocol | `kingdoms://` protocol |
| Git hosting | Keybase-hosted | Self-hosted in daemon |
| Storage backend | AWS S3 (Keybase controls) | Pluggable per entity — local disk, S3 you own, NAS, etc. |
| Encryption | NaCl (Keybase keys) | Entity Ed25519 keys |
| Kill switch | Keybase shutdown = gone | Storage is yours; daemon is yours; nothing to go down |

The sovereignty difference is total: the files live where you put them, backed by keys you hold, served by a daemon running on your hardware.

---

## 9. URL as Meeting Coordinate

The `kingdoms://` URL is a meeting coordinate (VESTA-SPEC-028). Two entities with separate kingdom installations can share a repo path:

```
kingdoms://koad/alice
```

Both koad and Juno can resolve this — koad because it's his local namespace, Juno because she has a peer connection to koad's daemon (SPEC-014) and a trust bond granting access. The URL is stable regardless of which machine resolves it.

This enables:
- `git clone kingdoms://koad/alice` from any entity in the ring
- File sharing via a path you can say out loud: "it's in kingdoms://juno/shared/koad/"
- Permanent links in trust bonds, session notes, issues

---

## 10. Handle Collisions

### 10.1 No Global Namespace Registry

Handles are not globally unique. Anyone can run a daemon and call themselves "koad". There is no central registrar to appeal to. This is intentional — sovereign infrastructure cannot have a namespace authority.

### 10.2 Identity Is Cryptographic, Not Lexical

Behind every handle is a cryptographic identity: the entity's Ed25519 public key, which produces a CID (VESTA-SPEC-027). The CID is derived from the identity, not the name. It cannot be faked or collided without breaking the cryptography.

The FUSE layer tracks both:

```
/kingdoms/koad/                    ← handle alias (ambiguous if collision in ring)
/kingdoms/GdYZWjcjY6Y2XonnM/      ← CID path (always unambiguous, always canonical)
```

Both paths resolve to the same entity when there is no collision. When there is a collision, the CID path always resolves correctly. The handle path falls to the entity you bonded with first, or to an explicit preference in your daemon config.

### 10.3 Collision Presentation

When two entities in your ring both claim handle "koad":

```
/kingdoms/koad/           ← first-bonded entity (your daemon's preference)
/kingdoms/koad~Gd7Z/      ← second entity (CID prefix as disambiguator)
/kingdoms/GdYZWjcjY6Y2XonnM/  ← always resolves the first precisely
/kingdoms/Ab3Xmn7RqKYdPwL/    ← always resolves the second precisely
```

The `kingdoms://` protocol handles this the same way:

```bash
git clone kingdoms://koad/alice           # resolves via your bonded preference
git clone kingdoms://GdYZWjcjY6Y2XonnM/alice  # always precise
```

### 10.4 Social Resolution

The ring is the enforcement layer. There is no appeal to a central authority because there is no central authority. But:

- Your peers can see your bonded entities and their claimed handles
- If someone in your ring is squatting a handle that causes confusion, your peers tell them directly
- A peer who refuses to rename can be unbonded — their namespace disappears from your ring
- The web of trust determines whose "koad" is the one that propagates

A sufficiently well-known entity (like the real koad) will have many bonds attesting to their CID. An impersonator will have few or none. The ring's collective memory resolves the ambiguity without any registrar involved.

### 10.5 The Real Coordinate: Key Fingerprint

The CID (VESTA-SPEC-027) is derived from the handle string — so two entities claiming "koad" produce the same CID. The CID is not unique enough to be the canonical identity anchor.

The globally unique identifier is the **key fingerprint**: the cryptographic hash of the entity's actual public key, generated at gestation and never derivable from the name. No two entities can share a fingerprint without breaking the cryptography.

The canonical FUSE paths for application use are fingerprint-addressed:

```
/kingdoms/<key_fingerprint>/profile.json   ← identity record
/kingdoms/<key_fingerprint>/avatar.png     ← identity bootstrap image
/kingdoms/<key_fingerprint>/public/        ← their public namespace
/kingdoms/<key_fingerprint>/shared/<fp2>/  ← shared space (bilateral, by fingerprint pair)
```

Named paths (`/kingdoms/koad/`) remain available as human-readable aliases. The FUSE layer resolves a name to its fingerprint on first lookup and caches the mapping.

### 10.6 The Avatar as Identity Bootstrap

The avatar at `/kingdoms/<fingerprint>/avatar.png` is not just an image. It contains embedded profile JSON — structured identity metadata carried inside the file itself (EXIF-style, or a purpose-built container format):

```json
{
  "handle": "koad",
  "fingerprint": "<key_fingerprint>",
  "public_key": "...",
  "cid": "GdYZWjcjY6Y2XonnM",
  "kingdoms_url": "kingdoms://<fingerprint>/",
  "bio": "...",
  "bonds": ["<juno_fp>", "<vulcan_fp>"],
  "updated": "2026-04-04T00:00:00Z"
}
```

An application that loads the avatar gets the full identity context in one fetch. No separate profile API call. The avatar IS the meeting coordinate — portable, self-describing, verifiable against the fingerprint embedded in the metadata.

### 10.7 Apps Use Coordinates, Not Names

Named namespaces (`kingdoms://koad/`) are the human interface layer. Applications resolve once and operate on coordinates:

```
1. Human says: "connect to kingdoms://koad/alice"
2. App resolves: "koad" → key fingerprint (via daemon lookup or avatar load)
3. App stores: kingdoms://<fingerprint>/alice  ← this is what the app uses
4. App loads: kingdoms://<fingerprint>/avatar.png → full identity context
5. All future references use the fingerprint coordinate, never the name
```

This is identical to how DNS works at the network layer (name → IP, then IP is used) and how ENS works in Ethereum (name → address, then address is used). The name is for humans. The coordinate is for machines.

The consequence: **name collisions are a UI problem, not a data integrity problem.** Two entities claiming "koad" present as two distinct fingerprint coordinates. Applications never confuse them. The interface boxes them into obvious containers (different avatars, different fingerprints shown) and the human picks the right one once. After that, the app uses the fingerprint.

### 10.8 Recommendation

- Humans: use handle paths in conversation (`kingdoms://koad/alice` — readable, speakable)
- Applications: resolve to fingerprint coordinate immediately, store and use that
- Permanent references (bonds, specs, issues): use fingerprint coordinate
- The avatar is the canonical identity bootstrap — load it first, derive everything else from its embedded profile

---

## 11. Implementation Plan

### Phase 1: Local namespace (no FUSE)

Start without FUSE. Create the directory structure under `~/.kingdom-fs/` and implement the git protocol handler:

```
~/.kingdom-fs/
  koad/
    public/     ← bare git repos, regular files
    private/
    shared/
      juno/
```

Implement `git-remote-kingdoms` as a thin wrapper:
- `kingdoms://koad/public/alice` → translates to `~/.kingdom-fs/koad/public/alice.git`
- Only local entities for now; remote falls back to error

This unlocks `git clone kingdoms://koad/alice` locally with zero FUSE complexity.

### Phase 2: FUSE mount

Add the FUSE layer on top of Phase 1. Mount point `/kingdoms/` backed by `~/.kingdom-fs/`. Access control enforced by FUSE daemon reading trust bonds.

### Phase 3: Remote entity access

FUSE layer connects to remote daemons (SPEC-014 peer protocol) to serve remote entity namespaces. `/kingdoms/juno/` backed by Juno's daemon on fourty4.

### Phase 4: CID resolver

Daemon exposes `/api/v1/cid/<cid>` → returns kingdoms URL. Enables `kingdoms://cid/<cid>` addressing.

---

## 12. Open Questions

1. **Private namespace encryption**: Are files in `private/` encrypted at rest? If daemon is compromised, are private files exposed? (Probably yes for phase 1 — trust the daemon. Encryption at rest is a later phase.)

2. **Conflict resolution in shared/**: If both entity and `<who>` write the same path simultaneously, what wins? Last-write or git merge semantics?

3. **Large file storage**: Git LFS equivalent? Or just don't support large files in phase 1?

4. **Namespace discovery**: How does entity A discover that entity B has a kingdoms namespace? Via daemon peer discovery (SPEC-014) or a published DNS record (`kingdoms.koad.sh TXT "kingdoms://koad"`)?

5. **kingdoms:// vs https://**: For public repos, should `git clone kingdoms://koad/alice` be equivalent to `git clone https://koad.sh/alice`? Could the daemon serve HTTP too, making kingdoms URLs universally resolvable?

---

## References

- VESTA-SPEC-007: Trust Bond Protocol
- VESTA-SPEC-009: Daemon Specification
- VESTA-SPEC-014: Kingdom Peer Connectivity Protocol
- VESTA-SPEC-027: CID Privacy Primitive
- VESTA-SPEC-028: URL as Meeting Coordinate
- Keybase KBFS documentation (prior art, intentionally different model)
- git-remote-helpers documentation (`git help gitremote-helpers`)

---

*Spec originated 2026-04-04, day 7. Open questions to be resolved before Vulcan begins Phase 1 implementation.*
