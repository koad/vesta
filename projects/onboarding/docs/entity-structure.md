# Entity Directory Structure

This document describes the canonical directory structure of a koad:io entity. Every entity at `~/.entityname/` follows this layout.

**Vesta owns this spec.** If your entity diverges from it, that is a gap — file an issue against `koad/vesta`.

---

## Top-Level Layout

```
~/.entityname/
├── CLAUDE.md           required   AI runtime instructions
├── README.md           required   Public identity and purpose
├── GOVERNANCE.md       required   Trust chain and authorization scope
├── .env                required   Entity environment variables
├── commands/           required   Entity commands
├── memories/           required   Identity and context
├── opencode/           required   AI agent configuration
├── id/                 required   Cryptographic keys
├── trust/              required   Trust bonds
├── projects/           recommended  Active work
├── skeletons/          optional   Inherited project templates
├── hooks/              optional   Lifecycle hooks (entity-specific)
├── var/                optional   Runtime data
├── bin/                optional   Entity wrapper scripts
└── KOAD_IO_VERSION     optional   Framework version at gestation
```

---

## Required Files

### `CLAUDE.md`

Instructions for the AI runtime. Loaded automatically when Claude Code (or any compatible AI) runs in this directory. Contains:
- Entity identity and role
- Protocol the entity owns or follows
- Behavioral constraints
- Project structure and workflow

Do not use this file for content that changes frequently. It is guidance, not state.

### `README.md`

Public-facing identity document. Explains what this entity is, what it does, and how to interact with it. Written as if a stranger might read it.

### `GOVERNANCE.md`

Documents the trust chain: who created this entity, what authority it operates under, and what it is authorized to do. References trust bonds for cryptographic backing.

### `.env`

Entity environment variables. At minimum:

```env
ENTITY=entityname
ENTITY_DIR=/home/username/.entityname
GIT_AUTHOR_NAME=EntityName
GIT_AUTHOR_EMAIL=entityname@canon.koad.sh
```

**Environment cascade** (highest to lowest priority):
1. Command-local `.env` (in the command directory)
2. Entity `.env` (`~/.entityname/.env`)
3. Framework `.env` (`~/.koad-io/.env`)

Variables at higher priority override lower priority. Never rely on framework-level variables for entity-specific config.

---

## `commands/`

Entity commands. These take highest priority in command discovery.

```
commands/
└── <command-name>/
    ├── command.sh      required   The executable
    └── .env            optional   Command-scoped variables
```

Commands are invoked as `entityname <command-name>`. See `commands.md` for the full discovery and invocation spec.

---

## `memories/`

Files loaded to give the AI runtime context and identity. Naming convention uses a numeric prefix to control load order.

```
memories/
├── 001-identity.md     Core identity — who this entity is
├── 002-operational-preferences.md   How this entity works
└── NNN-<topic>.md      Additional context as needed
```

**Format:** Plain markdown. Written in first person from the entity's perspective. Loaded fresh each session — do not store mutable state here. State goes in `var/`.

---

## `opencode/`

AI agent configuration.

```
opencode/
├── opencode.jsonc      Agent config (model, tools, etc.)
├── agent.md            Identity context loaded by the agent
└── skills/             Skill definitions
    └── <skill-name>/
        ├── SKILL.md    required   Skill metadata and description
        └── *.md        optional   Supporting documentation
```

### `SKILL.md` frontmatter

```yaml
---
name: skill-name
description: What this skill does
license: MIT
compatibility: opencode v1.0+
metadata:
  version: "1.0.0"
  category: category-name
---
```

---

## `id/`

Cryptographic keys. Generated at gestation. **Private keys are never shared, never committed, never transmitted.**

```
id/
├── ed25519             Ed25519 private key (signing)
├── ed25519.pub         Ed25519 public key
├── ecdsa               ECDSA private key
├── ecdsa.pub           ECDSA public key
├── rsa                 RSA private key
├── rsa.pub             RSA public key
├── dsa                 DSA private key
├── dsa.pub             DSA public key
└── ssl/
    ├── master-curve.pem
    ├── device-curve.pem
    └── session.pem
```

Public keys are distributed at `canon.koad.sh/<entityname>.keys`.

Private key files must not appear in `.gitignore` exceptions, CI/CD pipelines, or any automated process that transmits them off the machine.

---

## `trust/`

Trust bonds — signed authorization agreements between entities.

```
trust/
└── bonds/
    ├── <grantor>-<type>.signed     Active bonds
    └── revoked/                    Revoked bonds (archived, not deleted)
```

See `trust.md` for the full bond format and verification protocol.

---

## `projects/`

Active work — specifications, tasks, documentation in progress. Recommended structure:

```
projects/
└── <area>/
    ├── project.md      Project entry point (frontmatter required)
    └── <spec-name>/
        └── project.md  Spec detail
```

### `project.md` frontmatter (mandatory)

```yaml
---
id: spec-<name>
title: "Human-readable title"
type: project
status: backlog | active | blocked | review | shipped | cancelled
priority: 1
assigned_by: <entity>
issue: ""
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [tag1, tag2]
description: "One-line description"
owner: <entity>
---
```

---

## `skeletons/`

Project templates inherited from the framework or defined locally. When `koad-io spawn <skeleton>` is run in a directory, it copies the skeleton structure there.

Standard skeletons (from `~/.koad-io/skeletons/`):
- `bare` — minimal project
- `interface` — UI project
- `lighthouse` — full-stack project

---

## `hooks/`

Lifecycle hooks executed by the koad-io runtime at defined points. Entity-level hooks override or extend framework-level hooks at `~/.koad-io/hooks/`.

---

## `var/`

Mutable runtime data. Anything that changes during operation goes here, not in `memories/`. Logs, queues, cached state.

---

## Gestation

When an entity is created with `koad-io gestate <name>`, the framework:
1. Creates `~/.entityname/` with the canonical structure above
2. Generates all four key pairs in `id/`
3. Creates SSL credentials in `id/ssl/`
4. Creates an entity wrapper at `~/.koad-io/bin/<name>`
5. Inherits commands, skeletons, and hooks from the mother entity (if running as one)
6. Writes `KOAD_IO_VERSION` from the current framework version

Alternatively, an entity repo can be cloned and initialized with `koad-io init <name>`, which creates the wrapper and establishes inheritance without generating keys (the entity generates its own on first run).
