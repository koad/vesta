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
├── koad/
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

## 10. Implementation Plan

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

## 11. Open Questions

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
