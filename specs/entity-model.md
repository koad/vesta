---
status: canonical
id: VESTA-SPEC-001
version: 1.0
date: 2026-04-03
promoted: 2026-04-03
owner: vesta
references:
  - koad/vesta#13
  - koad/juno/PROJECTS/entity-model
  - ~/.koad-io/ (framework spec)
---

# VESTA-SPEC-001: Canonical Entity Model

**Authority:** Vesta (platform stewardship). This spec defines what a koad:io entity **is** at the filesystem level.

**Scope:** All autonomous entities in the koad:io ecosystem (Juno, Vulcan, Veritas, Mercury, Muse, Sibyl, Argus, Salus, Janus, Aegis, Vesta) conform to this model.

**Consumers:** Vulcan (gestation), Argus (auditing), Salus (healing), Janus (monitoring).

---

## 1. Entity Definition

An **entity** is an autonomous agent in the koad:io ecosystem with:
- A unique identity (`ENTITY=<name>`)
- A home directory (`ENTITY_DIR=/home/koad/.<name>`)
- A git repository at that location
- Cryptographic keys (`id/`)
- Trust bonds authorizing its scope (`trust/bonds/`)
- Operational configuration (`.env`, `passenger.json`)
- Runtime guidance (`CLAUDE.md`)

Every entity is:
- A git repository under version control
- Owned by a user account (typically `koad`)
- Authorized by signed trust bonds
- Conformable to this spec

---

## 2. Canonical Directory Structure

### Required Directories

Every entity MUST have these directories at the root of `ENTITY_DIR`:

```
~/.ENTITY/
├── id/                 ← cryptographic identity (keys)
├── trust/              ← trust bonds and authorization
│   └── bonds/          ← trust bond files
├── memories/           ← persistent context and knowledge
├── specs/              ← entity-specific specifications (optional for non-platform entities)
├── projects/           ← work tracking and project state
└── .git/               ← git repository
```

### Standard Subdirectories

Most entities include these for operational tracking:

```
~/.ENTITY/
├── commands/           ← entity-authored commands (if any)
├── hooks/              ← git hooks and event handlers (if configured)
├── comms/              ← inter-entity communication logs (if active)
├── keybase/            ← Keybase/Saltpack integration (if using)
├── home/               ← entity home directory structure
│   └── <entity>/       ← per-entity home space
├── archive/            ← deprecated or historical files
├── reports/ or logs/   ← operational logs and reports (varies by entity)
└── templates/          ← reusable templates for entity gestation (Vesta only)
```

### Optional Directories

Entities may have domain-specific directories for their role:

- **Janus:** `alerts/`, `patterns/`
- **Aegis:** `counsel/`
- **Veritas:** `verifications/`
- **Salus:** `reports/`, `recovery-logs/`
- **Sibyl:** `research/`, `sources/`, `notes/`
- **Vulcan:** `builds/`, `deployments/`
- **Mercury:** `communications/`, `releases/`
- **Argus:** `audit-reports/`, `diagnostics/`

---

## 3. Required Files

### At Root Level

| File | Status | Purpose |
|------|--------|---------|
| `CLAUDE.md` | **REQUIRED** | AI runtime guidance (entity-specific instructions) |
| `.env` | **REQUIRED** | Environment variables (`ENTITY`, `ENTITY_DIR`, etc.) |
| `passenger.json` | **REQUIRED** | Entity metadata (name, handle, role, avatar, buttons) |
| `KOAD_IO_VERSION` | **REQUIRED** | Gestation metadata (version, date, creator) |
| `.gitignore` | **REQUIRED** | Git ignore rules (keys, secrets, caches) |
| `README.md` | Optional | Entity overview and purpose |
| `GOVERNANCE.md` | Optional | Governance and decision-making (Juno, Vesta) |

### In `id/` (Cryptographic Identity)

Every entity has public keys; private keys are gitignored.

| File | Type | Status | Purpose |
|------|------|--------|---------|
| `ed25519` | Private | **REQUIRED** | EdDSA signing key (primary) |
| `ed25519.pub` | Public | **REQUIRED** | EdDSA public key |
| `ecdsa` | Private | **REQUIRED** | ECDSA signing key |
| `ecdsa.pub` | Public | **REQUIRED** | ECDSA public key |
| `rsa` | Private | **REQUIRED** | RSA asymmetric key |
| `rsa.pub` | Public | **REQUIRED** | RSA public key |
| `dsa` | Private | Optional | DSA signing key (legacy) |
| `dsa.pub` | Public | Optional | DSA public key (legacy) |

**Permissions:** Private keys `600` (owner read/write only). Public keys `644` (world-readable).

### In `trust/bonds/`

Trust bonds authorizing this entity's scope. Format: `<issuer>-to-<entity>.md`

| File | Status | Purpose |
|------|--------|---------|
| `koad-to-<entity>.md` | **REQUIRED** | Root authority bond (always signed by koad) |
| `<issuer>-to-<entity>.md` | **REQUIRED** if issued by non-root | Any additional bonds |

**Permissions:** `644` (world-readable). Bonds are public contracts, not secrets.

### In `memories/`

Persistent context across sessions. Vesta spec defines structure; see auto-memory system.

| File | Status | Purpose |
|------|--------|---------|
| `001-identity.md` | **REQUIRED** | Core entity identity and self-knowledge |
| `002-operational-preferences.md` | Optional | How the entity operates (session protocol, comms) |
| Other memories | Optional | Role-specific context, past decisions, learned patterns |

---

## 4. `.env` Schema

Environment variables loaded at entity startup. Location: `ENTITY_DIR/.env`

### Required Variables

All entities MUST define these:

| Key | Type | Example | Purpose |
|-----|------|---------|---------|
| `ENTITY` | string | `vesta` | Entity identifier (lowercase, no spaces) |
| `ENTITY_DIR` | path | `/home/koad/.vesta` | Absolute path to entity directory |
| `ENTITY_HOME` | path | `/home/koad/.vesta/home/vesta` | Per-entity home directory |
| `GIT_AUTHOR_NAME` | string | `Vesta` | Git commit author name |
| `GIT_AUTHOR_EMAIL` | string | `vesta@kingofalldata.com` | Git commit author email |
| `CREATOR` | string | `koad` | Creator/deployer entity |
| `MOTHER` | string | `juno` | Orchestrator entity |

### Identity & Keys

| Key | Type | Example | Purpose |
|-----|------|---------|---------|
| `ENTITY_KEYS` | path | `/home/koad/.vesta/vesta.keys` | Public key bundle path |
| `TRUST_CHAIN` | path | `/home/koad/.vesta/trust` | Trust bonds directory |
| `CREATOR_KEYS` | URL | `canon.koad.sh/koad.keys` | Creator's public keys |
| `MOTHER_KEYS` | URL | `canon.koad.sh/juno.keys` | Mother/orchestrator's public keys |

### Role & Purpose

| Key | Type | Example | Purpose |
|-----|------|---------|---------|
| `ROLE` | string | `architect` | Entity's functional role |
| `PURPOSE` | string | `Specify and maintain structural standards` | Entity's mission |

### Framework & Runtime

| Key | Type | Example | Purpose | Status |
|-----|------|---------|---------|--------|
| `KOAD_IO_VERSION` | string | `1.0.0` | koad:io framework version | Optional |
| `KOAD_IO_BIND_IP` | IP | `127.0.0.1` | Bind address for services | Optional |
| `KOAD_IO_QUIET` | bool | `1` | Suppress verbose output | Optional |
| `METEOR_PACKAGE_DIRS` | path | `/home/koad/.koad-io/packages` | Package directory | Optional |

### Git Configuration

| Key | Type | Example | Purpose | Status |
|-----|------|---------|---------|--------|
| `GIT_COMMITTER_NAME` | string | `Vesta` | Git committer name (usually same as author) | Optional |
| `GIT_COMMITTER_EMAIL` | string | `vesta@kingofalldata.com` | Git committer email | Optional |

### Entity-Specific Variables

Entities may define additional variables as needed:
- Janus: heartbeat check intervals, alert categories
- Veritas: verification standards, confidence thresholds
- Vulcan: build configuration, deployment targets

**Rule:** All variables must be documented in the entity's README.md or CLAUDE.md.

---

## 5. `passenger.json` Schema

Metadata about the entity for the Passenger UI/daemon. Location: `ENTITY_DIR/passenger.json`

### Required Fields

```json
{
  "handle": "string (lowercase, no spaces)",
  "name": "string (display name)",
  "role": "string (functional role: architect, builder, guardian, healer, etc.)"
}
```

### Optional Fields

```json
{
  "avatar": "string (path to image file)",
  "status": "string (operational status: active, paused, dormant)",
  "buttons": [
    {
      "label": "string (button label)",
      "action": "string (handler function or command)",
      "description": "string (tooltip)"
    }
  ]
}
```

### Example

```json
{
  "handle": "vesta",
  "name": "Vesta",
  "role": "architect",
  "avatar": "avatar.png",
  "buttons": [
    {
      "label": "Specs",
      "action": "specs",
      "description": "View active specs"
    }
  ]
}
```

---

## 6. `KOAD_IO_VERSION` Format

Version and gestation metadata. Location: `ENTITY_DIR/KOAD_IO_VERSION`

```
# koad:io entity

GESTATED_BY=<creator-entity>
GESTATE_VERSION=<git-commit-hash>
BIRTHDAY=<YY:MM:DD:HH:MM:SS>
NAME=<entity-name>
```

**Purpose:** Tracks when the entity was created, by whom, and with which version of the gestation script.

---

## 7. Git Configuration

### Repository Requirements

| Requirement | Details |
|-------------|---------|
| **Remote** | GitHub repository at `github.com/koad/<entity>` |
| **Default branch** | `main` (never `master`) |
| **Commit signing** | Required for all commits (enforced via hook) |
| **Author** | Must match `GIT_AUTHOR_NAME` and `GIT_AUTHOR_EMAIL` |

### `.gitignore` Requirements

Every entity MUST exclude:

```
# Private keys (no secrets in git)
id/ed25519
id/ecdsa
id/rsa
id/dsa

# Secrets and env overrides
.env.local
.env.*.local
.env.secret*

# Runtime caches
node_modules/
__pycache__/
.pytest_cache/
.venv/
dist/
build/

# Temp files
*.swp
*.swo
*~
.DS_Store
```

---

## 8. File Ownership & Permissions

### Ownership

All files owned by user `koad` (entity operator).

```bash
chown -R koad:koad ~/.ENTITY
```

### Permissions

| File/Dir | Mode | Reason |
|----------|------|--------|
| `id/` (directory) | `700` | Private keys, owner access only |
| `id/<keytype>` (private) | `600` | Private keys, no sharing |
| `id/<keytype>.pub` (public) | `644` | Public keys, world-readable |
| `trust/bonds/` | `755` | Bonds are public, readable by all |
| `trust/bonds/*.md` | `644` | Bonds are contracts, world-readable |
| `.env` | `600` | Contains secrets, owner-only |
| `CLAUDE.md` | `644` | Public guidance, world-readable |
| `.git/` | `700` | Repository metadata, owner-only |
| `.gitignore` | `644` | Configuration, world-readable |

---

## 9. Conformance Checks

### Argus Audit Criteria

When Argus audits an entity, it verifies:

1. **Directory structure:** Required dirs exist and are empty if unused
2. **Required files:** All required files present and non-empty
3. **Keys:** All key types (ed25519, ecdsa, rsa) present, permissions correct
4. **Trust bonds:** At least one valid `koad-to-<entity>` bond present
5. **.env schema:** All required variables set, no undefined references
6. **Git state:** Repository is clean, HEAD points to main, remote origin is correct
7. **File integrity:** No unexpected files in `id/` or `trust/bonds/`
8. **Permissions:** Ownership and permissions match spec

### Salus Healing Standards

When Salus heals an entity, it:

1. **Reconstructs missing directories** with proper permissions
2. **Recovers CLAUDE.md** from Vesta's templates and git history
3. **Rebuilds memories/** from past logs and diagnostic data
4. **Restores .env** from framework spec + entity identity
5. **Recovers trust/bonds/** from git history + known bond graph
6. **Verifies keys** are present (private keys must be restored by koad manually if lost)

---

## 10. Entity Lifecycle

### Gestation (Juno)

When creating a new entity:
1. Run `~/.koad-io/commands/gestate/` with entity name
2. Creates directory `~/.ENTITY` with all required structure
3. Generates cryptographic keys
4. Creates `koad-to-<entity>` bond
5. Initializes git repository
6. Commits initial state with KOAD_IO_VERSION

### Activation (Entity)

When an entity starts up:
1. Reads CLAUDE.md for runtime guidance
2. Loads .env for identity and configuration
3. Verifies trust bonds (check koad-to-<entity> is valid)
4. Loads memories/ for persistent context
5. Connects to GitHub (verifies remote auth)
6. Reports status

### Maintenance (Argus / Salus)

Periodically:
- **Argus** audits entity structure, reports gaps or violations
- **Salus** heals entity from canonical spec if damaged
- **Janus** watches for anomalies or trust violations

### Deactivation / Revocation (koad)

If entity is compromised or untrustworthy:
1. Revoke trust bond (`trust/bonds/koad-to-<entity>.md` marked revoked)
2. Entity can no longer execute authorized commands
3. Historical records preserved for audit

---

## 11. Variation by Entity Type

### Platform Entities (Vesta, Juno, Argus, Salus)

**Additional requirements:**
- `specs/` directory with canonical specifications
- `projects/` directory for protocol work
- `GOVERNANCE.md` for decision authority
- Regular release cadence

### Operational Entities (Vulcan, Mercury, Muse, Sibyl, Janus, Aegis, Veritas)

**Standard structure** as defined above.

### Specialized Entities (Salus)

**Requires:** access to other entities' git histories for healing.

---

## 12. Examples

### Minimal Valid Entity (Janus)

```
~/.janus/
├── CLAUDE.md                       ← runtime guidance
├── .env                            ← identity + config
├── .gitignore                      ← excludes secrets
├── KOAD_IO_VERSION                 ← gestation metadata
├── passenger.json                  ← metadata
├── README.md                       ← overview (optional)
├── .git/                           ← git repository
├── id/                             ← cryptographic keys
│   ├── ed25519                     ← private (600)
│   ├── ed25519.pub                 ← public (644)
│   ├── ecdsa                       ← private (600)
│   ├── ecdsa.pub                   ← public (644)
│   ├── rsa                         ← private (600)
│   └── rsa.pub                     ← public (644)
├── trust/                          ← trust bonds
│   └── bonds/
│       └── koad-to-janus.md        ← signed authorization
└── memories/                       ← persistent context
    ├── 001-identity.md
    └── 002-operational-preferences.md
```

### Full Entity (Vesta)

```
~/.vesta/
├── CLAUDE.md
├── .env
├── .gitignore
├── KOAD_IO_VERSION
├── passenger.json
├── README.md
├── GOVERNANCE.md
├── .git/
├── id/                             ← keys
├── trust/
│   └── bonds/                      ← bonds
│       └── koad-to-vesta.md
├── memories/                       ← persistent context
├── specs/                          ← canonical specifications
│   ├── entity-model.md
│   ├── gestation-protocol.md
│   └── ... (other specs)
├── projects/                       ← work tracking
│   ├── cli-protocol/
│   ├── onboarding/
│   └── ...
├── templates/                      ← templates for gestation
│   └── claude-md/
├── home/                           ← entity home space
│   └── vesta/
├── archive/                        ← historical files
└── ssl/                            ← SSL certificates (Vesta-specific)
```

---

## 13. Change Log

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 0.1 | 2026-04-03 | vesta | **DRAFT** — Initial comprehensive spec covering directory structure, required files, .env schema, and conformance criteria. |

---

## Phase 2 Enhancements

Future iterations may refine:

- Daemon/worker configuration location (passenger.json? separate workers.json?)
- Hook registration mechanism (hooks.json? environment variables?)
- Public key distribution system (see VESTA-SPEC-024)
- Keybase integration requirements (currently optional, recommended)

---

**Status:** Canonical (promoted 2026-04-03). All entities must conform to this model. Implementation deadline: all entity gestation completes by 2026-04-10.

File issues on koad/vesta to propose amendments or report conformance gaps.

**Conformance audits:** Argus checks directory structure, required files, and .env completeness. Salus repairs missing or malformed structures.
