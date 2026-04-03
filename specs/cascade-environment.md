---
status: draft
id: VESTA-SPEC-005
title: "Cascade Environment — .env Loading and Override Mechanics"
type: spec
created: 2026-04-03
updated: 2026-04-03
owner: vesta
description: "Canonical protocol for environment variable cascade loading in the two-layer koad:io architecture"
---

# Cascade Environment

## 1. Overview

The **cascade environment** is the set of shell environment variables that are loaded when any process runs in the koad:io ecosystem. The cascade ensures that:

- Framework-level defaults are always available
- Entity-level customization overrides framework defaults
- Local or session-specific overrides are possible
- Sensitive variables (private keys, tokens) do not leak across entity boundaries
- The loaded environment is auditable and inspectable

### Design Principles

- **Layered Loading**: Each layer (framework → entity → local) can override previous layers
- **Explicit Scoping**: Variable prefixes indicate which layer they belong to (framework vs entity)
- **Fail-Safe Defaults**: If a required variable is missing, the process should fail with a clear error
- **No Implicit Defaults**: Variables are not loaded from arbitrary locations; only explicit `.env` files
- **Auditable**: Commands can inspect the effective environment and see where each variable came from
- **Security-Aware**: Private keys and sensitive variables are never passed across entity boundaries

## 2. Layer Architecture

The cascade environment is built from three distinct layers, loaded in this order:

```
Layer 1: Framework Layer (~/.koad-io/.env)
    ↓ (overrides)
Layer 2: Entity Layer (~/.{entity}/.env)
    ↓ (overrides)
Layer 3: Session Layer (working directory .env or ad-hoc exports)
    ↓
Effective Environment (used by process)
```

### Layer 1: Framework Layer

**File:** `~/.koad-io/.env`

The framework layer contains system-wide defaults for the entire koad:io installation. These variables are loaded first and are available to all entities.

**Scope:**
- System-wide infrastructure parameters (bind IP, package directories, etc.)
- Root entity identity (PRIMARY_ENTITY)
- Framework version and configuration
- Logging and debugging flags that apply to all entities

**Ownership:** koad (root entity)

**Loaded by:** All entity commands and processes automatically

**Example:**
```bash
PRIMARY_ENTITY=koad
KOAD_IO_BIND_IP=127.0.0.1
KOAD_IO_HOME=/home/koad
METEOR_PACKAGE_DIRS=/home/koad/.koad-io/packages:/home/koad/.koad-io/extra-packages
KOAD_IO_QUIET=0
```

### Layer 2: Entity Layer

**File:** `~/.{entity}/.env`

The entity layer contains entity-specific configuration that overrides framework defaults. This layer is loaded after the framework layer, so entity-specific variables take precedence.

**Scope:**
- Entity identity (ENTITY, ENTITY_DIR, ENTITY_HOME)
- Entity's public keys and trust chain locations
- Entity's role and purpose
- Git author/committer identity for commits from this entity
- Entity-specific daemon or worker configuration

**Ownership:** The entity itself (entity can modify its own .env)

**Loaded by:** Automatically when code runs as the entity (via `koad-io dispatch` or entity daemon)

**Example:**
```bash
ENTITY=vesta
ENTITY_DIR=/home/koad/.vesta
ENTITY_HOME=/home/koad/.vesta/home/vesta
ENTITY_KEYS=/home/koad/.vesta/vesta.keys
TRUST_CHAIN=/home/koad/.vesta/trust
CREATOR=koad
CREATOR_KEYS=canon.koad.sh/koad.keys
MOTHER=juno
MOTHER_KEYS=canon.koad.sh/juno.keys
ROLE=architect
PURPOSE="Specify and maintain the structural standards of the koad:io ecosystem"
GIT_AUTHOR_NAME=Vesta
GIT_AUTHOR_EMAIL=vesta@kingofalldata.com
GIT_COMMITTER_NAME=Vesta
GIT_COMMITTER_EMAIL=vesta@kingofalldata.com
```

### Layer 3: Session Layer (Optional)

**File:** `.env` in current working directory, or ad-hoc exports

The session layer allows for temporary, working-directory-specific overrides. This layer is optional and typically used for:

- Development/debugging overrides
- Temporary credentials or flags
- Test or CI-specific variables

**Scope:**
- Any variable that needs to be overridden for a specific session or test

**Ownership:** The developer or session runner

**Loaded by:** Explicitly via `source .env` or shell initialization

**Example:**
```bash
# In a developer's working directory
KOAD_IO_QUIET=1
DEBUG_LEVEL=2
```

## 3. Load Sequence

### Automatic Loading

When any koad:io command or entity process starts, the cascade environment is loaded in this order:

1. **Start with minimal shell environment** (PATH, HOME, etc.)
2. **Load framework layer**: `source ~/.koad-io/.env`
3. **Load entity layer**: `source ~/.{entity}/.env` (based on ENTITY variable or current context)
4. **Load local session layer** (optional): `source .env` if it exists in current working directory
5. **Apply ad-hoc exports** from the command line or parent process

Each subsequent layer overrides variables from previous layers. If a variable is defined in both the framework and entity layers, the entity layer value is used.

### Dispatcher Control

The **koad-io dispatcher** (the main entry point for entity commands) handles automatic environment loading:

```bash
#!/bin/bash
# Simplified dispatcher logic

# Load framework layer
source ~/.koad-io/.env

# Determine entity (from argument, ENTITY env var, or git context)
ENTITY=${1:-$ENTITY}
if [[ ! -d ~/.${ENTITY} ]]; then
  echo "Error: entity ~/.${ENTITY} not found"
  exit 1
fi

# Load entity layer
source ~/.${ENTITY}/.env

# Optionally load session layer
if [[ -f .env ]]; then
  source .env
fi

# Execute command with cascade environment
exec "${@:2}"
```

### Manual Loading

Developers can manually load the cascade environment in scripts:

```bash
#!/bin/bash
# Load cascade environment manually
source ~/.koad-io/.env
source ~/.${ENTITY}/.env
[[ -f .env ]] && source .env

# Your script here
```

## 4. Required Variables by Layer

### Framework Layer Requirements

The framework layer MUST define:

| Variable | Purpose | Example |
|----------|---------|---------|
| `PRIMARY_ENTITY` | Root entity (usually `koad`) | `koad` |
| `KOAD_IO_HOME` | Framework installation directory | `/home/koad` |
| `KOAD_IO_BIND_IP` | IP address for binding services | `127.0.0.1` or `0.0.0.0` |
| `METEOR_PACKAGE_DIRS` | Package search paths (use absolute paths) | `/home/koad/.koad-io/packages` |

**IMPORTANT NOTE on `METEOR_PACKAGE_DIRS`:** Always use **absolute paths** (e.g., `/home/koad/.koad-io/packages`), NOT shell variable expansion like `$HOME`. Shell expansions fail in cron and systemd contexts where the environment is minimal. If multiple paths are needed, separate them with `:` and use full absolute paths.

The framework layer MAY define:

- `KOAD_IO_QUIET` — Suppress non-error output (0 or 1)
- `KOAD_IO_LOG_LEVEL` — Logging verbosity (DEBUG, INFO, WARN, ERROR)
- `KOAD_IO_TIMEOUT` — Default timeout for operations (seconds)

### Entity Layer Requirements

Each entity MUST define in its `.env`:

| Variable | Purpose | Example |
|----------|---------|---------|
| `ENTITY` | This entity's name | `vesta` |
| `ENTITY_DIR` | This entity's home directory | `/home/koad/.vesta` |
| `ENTITY_HOME` | User home within entity | `/home/koad/.vesta/home/vesta` |
| `ENTITY_KEYS` | Path to entity's public keys file | `/home/koad/.vesta/vesta.keys` |
| `TRUST_CHAIN` | Path to trust bonds directory | `/home/koad/.vesta/trust` |
| `CREATOR` | Entity that gestated this one | `koad` |
| `CREATOR_KEYS` | Path to creator's public keys | `canon.koad.sh/koad.keys` |
| `ROLE` | Entity's role in the team | `architect`, `builder`, `auditor`, etc. |
| `PURPOSE` | One-line description of entity's purpose | `"Specify and maintain the structural standards of the koad:io ecosystem"` |

The entity MAY define:

| Variable | Purpose | Example |
|----------|---------|---------|
| `MOTHER` | Entity that created this one (alternate) | `juno` |
| `MOTHER_KEYS` | Path to mother's public keys | `canon.koad.sh/juno.keys` |
| `GIT_AUTHOR_NAME` | Author name for git commits | `Vesta` |
| `GIT_AUTHOR_EMAIL` | Author email for git commits | `vesta@kingofalldata.com` |
| `GIT_COMMITTER_NAME` | Committer name for git commits | `Vesta` |
| `GIT_COMMITTER_EMAIL` | Committer email for git commits | `vesta@kingofalldata.com` |
| `DAEMON_ENABLED` | Whether this entity runs a daemon (true/false) | `false` |
| `DAEMON_PORT` | Port for entity daemon (if daemon enabled) | `8443` |
| `ENTITY_ENDPOINT` | HTTP endpoint for entity commands | `https://entity.internal:8443` |

### Session Layer

The session layer has no required variables. It is used only for optional overrides.

## 5. Variable Naming Conventions

### Prefixes for Scoping

Variables are named using prefixes to indicate which layer they belong to and how broadly they apply:

#### `KOAD_IO_*` — Framework Variables

Variables prefixed with `KOAD_IO_` belong to the framework layer and apply globally:

- `KOAD_IO_HOME` — Framework installation directory
- `KOAD_IO_BIND_IP` — Bind address for services
- `KOAD_IO_QUIET` — Global quiet flag
- `KOAD_IO_LOG_LEVEL` — Global logging level

#### `ENTITY_*` — Entity Identity Variables

Variables prefixed with `ENTITY_` describe the current entity:

- `ENTITY` — Entity name
- `ENTITY_DIR` — Entity directory
- `ENTITY_HOME` — Entity user home
- `ENTITY_KEYS` — Entity's public keys
- `ENTITY_ENDPOINT` — Entity's service endpoint

#### `*_KEYS` — Cryptographic Key Paths

Variables ending with `_KEYS` point to files containing public keys:

- `ENTITY_KEYS` — This entity's keys
- `CREATOR_KEYS` — Creator's keys
- `MOTHER_KEYS` — Mother's keys
- `AUTHORIZER_KEYS` — Authorizer's keys (in trust bonds)

These are paths, not the keys themselves. Private keys are never stored in environment variables.

#### `GIT_*` — Git Configuration

Variables prefixed with `GIT_` are git-specific:

- `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL` — Commit author
- `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` — Committer identity
- `GIT_AUTHOR_DATE`, `GIT_COMMITTER_DATE` — Timestamps

#### Application-Specific Variables

Applications can define their own variables:

- Use UPPERCASE for constants
- Use prefixes to avoid collisions: `{ENTITY}_{SUBSYSTEM}_*` or `{FEATURE}_*`
- Document all custom variables in the entity's README or .env

### Naming Examples

| Variable | Purpose | Layer |
|----------|---------|-------|
| `KOAD_IO_HOME` | Framework root | Framework |
| `ENTITY` | Current entity | Entity |
| `CREATOR_KEYS` | Creator's public keys file | Entity |
| `DEBUG_LEVEL` | Session-specific debug level | Session |
| `VULCAN_BUILD_CONCURRENCY` | Vulcan builder concurrency | Entity |

## 6. Override Semantics

### Basic Override

When a variable is defined in multiple layers, the later layer wins:

```bash
# Framework: KOAD_IO_QUIET=0
# Entity:    KOAD_IO_QUIET=1
# Result:    KOAD_IO_QUIET=1 (entity overrides framework)
```

### Explicit Block (Prevention of Override)

To prevent a variable from being overridden by a later layer, prefix it with an underscore `_`:

```bash
# Framework: _IMMUTABLE_VAR=value
# Entity:    IMMUTABLE_VAR=newvalue  ← has no effect
# Result:    _IMMUTABLE_VAR=value (not overridden)
```

The underscore prefix indicates "do not override this variable from lower layers." This is rarely used and should be documented when it is.

### Append and Prepend

For list variables (like `PATH` or `METEOR_PACKAGE_DIRS`), you can append or prepend values:

```bash
# Framework: METEOR_PACKAGE_DIRS=/home/koad/.koad-io/packages
# Entity:    METEOR_PACKAGE_DIRS=/home/koad/.vulcan/packages:/home/koad/.koad-io/packages
# Result:    METEOR_PACKAGE_DIRS=/home/koad/.vulcan/packages:/home/koad/.koad-io/packages
```

**For `METEOR_PACKAGE_DIRS` specifically:** Always list paths as absolute paths separated by `:`. Do not use `${VARNAME}` expansion or shell variables (e.g., `$HOME`), as these fail in cron and systemd environments. Each entity that extends package directories should list them explicitly.

## 7. Security Boundaries

### Variables That Must NOT Cross Boundaries

The following types of variables must never be passed across entity boundaries:

1. **Private Key Paths and Contents**
   - Never export `*_PRIVATE_KEY`, `*_SECRET_KEY`, or similar
   - Never export keys or credentials as variables (use key files instead)
   - Example: Do not export `ENTITY_SECRET_KEY=xyz123`

2. **Tokens and Credentials**
   - OAuth tokens, API keys, passwords must not be in `.env`
   - If needed, store in `~/.{entity}/.env.secrets` (NOT committed) and source carefully
   - Example: Do not export `GITHUB_TOKEN=ghp_xxx`

3. **Internal Addresses and Ports**
   - Entity-internal endpoints should not be visible to other entities
   - Only expose endpoints explicitly defined in entity's API spec
   - Example: Do not export internal `DATABASE_URL` unless documented publicly

4. **Debugging and Audit Variables**
   - `DEBUG_*`, `TRACE_*`, and `AUDIT_*` variables should not leak debugging data
   - Use `KOAD_IO_QUIET` and `KOAD_IO_LOG_LEVEL` instead for controlled logging

### Boundary Enforcement

When one entity invokes another via the dispatcher, the cascade environment is built fresh from the called entity's `.env`, not inherited from the caller:

```bash
# Vesta wants to invoke a Vulcan command
# Vesta's environment has: ENTITY=vesta, VESTA_PRIVATE_KEY_PATH=...
# Vesta calls: koad-io vulcan some-command

# The dispatcher does:
# 1. Load framework: ~/.koad-io/.env
# 2. Load Vulcan entity: ~/.vulcan/.env
#    (Vesta's VESTA_PRIVATE_KEY_PATH is NOT passed to Vulcan)
# 3. Execute Vulcan command with only Vulcan's environment
```

This prevents accidental credential leakage.

## 8. Variable Debugging and Inspection

### Inspecting the Effective Environment

To see all loaded environment variables and their sources:

```bash
# Print all variables and mark which layer they came from
env | sort | grep -E '^(KOAD_IO|ENTITY|GIT_|CREATOR|MOTHER)'
```

For debugging, create a utility script that shows variable sources:

```bash
#!/bin/bash
# debug-env.sh — show where each variable came from

echo "=== Framework Layer (~/.koad-io/.env) ==="
grep -E "^[A-Z_]+" ~/.koad-io/.env || echo "(none)"

echo ""
echo "=== Entity Layer (~/.${ENTITY}/.env) ==="
grep -E "^[A-Z_]+" ~/.${ENTITY}/.env || echo "(none)"

echo ""
echo "=== Current Effective Environment ==="
env | grep -E '^(KOAD_IO|ENTITY|GIT_|CREATOR|MOTHER)' | sort

echo ""
echo "=== Overrides Detected ==="
# Variables in entity that differ from framework
```

### Logging Environment at Process Start

Daemons and long-running processes should log the effective environment on startup (at appropriate log level):

```bash
#!/bin/bash
# In daemon startup
if [[ "${KOAD_IO_LOG_LEVEL}" != "ERROR" ]]; then
  echo "Environment: ENTITY=${ENTITY} ROLE=${ROLE}" >&2
  echo "Keys: ENTITY_KEYS=${ENTITY_KEYS}" >&2
fi
```

## 9. Entity Gestation and .env Generation

### Gestation Process

When a new entity is gestated (created) via the `koad-io gestate` command, a `.env` file is automatically generated with:

1. All required variables (from Section 4)
2. Template values filled in based on the gestation parameters
3. Creator and mother entity information
4. Role and purpose specified by the creator

See **VESTA-SPEC-002** (Gestation Protocol) for details on the gestation process and `.env` initialization.

### Template Substitution

The gestation script uses a template `.env` with placeholders:

```bash
# Template at ~/.koad-io/templates/entity.env.template
ENTITY={{ENTITY_NAME}}
ENTITY_DIR={{ENTITY_DIR}}
CREATOR={{CREATOR_ENTITY}}
ROLE={{ENTITY_ROLE}}
PURPOSE={{PURPOSE_STRING}}
```

These placeholders are replaced during gestation to produce the entity's `.env`.

## 10. Examples

### Example 1: Running a Vesta Command

```bash
# User runs: koad-io vesta spec-review

# Dispatcher loads cascade environment:
source ~/.koad-io/.env         # Framework defaults
source ~/.vesta/.env           # Vesta's identity

# Vesta's effective environment:
ENTITY=vesta
ENTITY_DIR=/home/koad/.vesta
CREATOR=koad
ROLE=architect
KOAD_IO_BIND_IP=127.0.0.1
METEOR_PACKAGE_DIRS=/home/koad/.koad-io/packages
GIT_AUTHOR_NAME=Vesta
GIT_AUTHOR_EMAIL=vesta@kingofalldata.com

# Command runs with this environment
```

### Example 2: Developer Session with Overrides

```bash
# Developer in ~/.vesta directory
cat > .env << EOF
KOAD_IO_QUIET=1
DEBUG_LEVEL=2
EOF

# Developer's command:
source ~/.koad-io/.env
source ~/.vesta/.env
source .env  # Local session overrides

# Environment now has:
KOAD_IO_QUIET=1            # Overridden by session
DEBUG_LEVEL=2              # Added by session
ENTITY=vesta               # From entity layer
GIT_AUTHOR_NAME=Vesta      # From entity layer
```

### Example 3: Cross-Entity Call

```bash
# Vesta (entity=vesta) calls a Vulcan command:
koad-io vulcan build-entity

# Dispatcher does:
source ~/.koad-io/.env     # Framework
source ~/.vulcan/.env      # Vulcan's environment (not Vesta's!)

# Vulcan's environment is isolated:
ENTITY=vulcan
ROLE=builder
GIT_AUTHOR_NAME=Vulcan
# Vesta's variables are NOT visible
```

## 11. Daemon and Cron Environment

### Daemon Startup

When an entity daemon starts (via systemd, supervisor, or manual startup), it loads the cascade environment:

```bash
#!/bin/bash
# Entity daemon startup script

# Load cascade environment
source ~/.koad-io/.env
source ~/.${ENTITY}/.env

# Daemon code runs with full cascade environment
exec /path/to/daemon-process
```

### Cron Jobs

Cron jobs running as an entity must explicitly load the cascade environment, since cron has a minimal environment:

```bash
# In crontab or systemd timer
0 12 * * * /bin/bash -c 'source ~/.koad-io/.env && source ~/.vesta/.env && /path/to/task'
```

Without loading the cascade environment, cron jobs will fail due to missing variables.

## 12. Troubleshooting

### Missing Variable Errors

If a process fails with "Variable not found" or similar:

1. Check if the variable is in the required list (Section 4)
2. Verify both `.env` files exist:
   - `~/.koad-io/.env` (framework)
   - `~/.{entity}/.env` (entity)
3. Run the debug script (Section 8) to see the effective environment
4. Check if the process is being run with the dispatcher (which loads the cascade)

### Variable Not Taking Effect

If you change a variable in `.env` but the process still uses the old value:

1. Verify the file is saved
2. Check if the variable is prefixed with `_` (immutable flag)
3. Verify the new value is in the correct layer (framework vs entity vs session)
4. Restart the process (new processes load fresh environment)

### Credential Leakage

If a process exposes sensitive variables in logs or errors:

1. Do NOT store credentials in `.env` files
2. Use `~/.{entity}/.env.secrets` (gitignored) for sensitive variables
3. Source `.env.secrets` only in specific, controlled scripts
4. Use `KOAD_IO_QUIET=1` to suppress verbose output in production

## 13. Migration Notes

### Updating .env Format

If the environment variable format changes in a future spec version:

1. New variables are backward-compatible (added, not removed)
2. Renamed variables should have a transition period with both names working
3. Deprecated variables should be marked in comments: `# DEPRECATED: use VAR_NEW instead`
4. Entities must update their `.env` files before the deadline

### Example Deprecation

```bash
# Old variable (deprecated as of 2026-07-01)
OLD_VAR=value  # DEPRECATED: use NEW_VAR instead

# New variable (replacement)
NEW_VAR=${OLD_VAR}
```

---

## Appendix: Related Specifications

- **VESTA-SPEC-001** — Entity Model (entity structure and required files)
- **VESTA-SPEC-002** — Gestation Protocol (how .env is created for new entities)
- **VESTA-SPEC-008** — Inter-Entity Communications Protocol (uses ENTITY_ENDPOINT and related vars)

---

**Draft Status:** This specification is in draft and subject to feedback from koad and other entities. The load sequence and variable requirements are based on current practice in `~/.koad-io/`, `~/.vesta/`, and `~/.juno/`. Feedback should be filed as GitHub Issues on `koad/vesta`.
