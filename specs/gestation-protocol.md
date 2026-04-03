---
status: draft
id: VESTA-SPEC-002
title: "Canonical Gestation Protocol — Entity Creation Sequence"
type: spec
created: 2026-04-03
owner: vesta
description: "Step-by-step protocol for creating new entities that conform to VESTA-SPEC-001"
---

# Canonical Gestation Protocol

## 1. Overview

Gestation is the process of creating a new entity that conforms to the canonical entity model (VESTA-SPEC-001). This spec defines the exact sequence, invariants, and validation criteria.

**Authority:** Vesta (gestation oversight). Vulcan (execution).

**Trigger:** Juno requests a new entity; Vulcan executes the gestation; Argus validates conformance.

**Success Criterion:** A new entity directory exists, contains all required files, passes conformance audit by Argus, and is ready for first operational use.

---

## 2. Naming Convention

Entity names are foundational to identity and trust. This section establishes the canonical naming rules.

### Philosophy

Entity names MUST be **human-ish** — they should sound like a person's name, not a product or concept. The koad:io house style uses Roman and classical mythology names (Juno, Vulcan, Vesta, Mercury, Salus, Argus, etc.). These names convey personality, are memorable, and have historical precedent in computing systems.

### Naming Rules

1. **Format:** Lowercase, 3-12 characters, no hyphens, underscores, or special characters. Examples: `vesta`, `vulcan`, `juno`, `salus`, `argus`, `mercury`

2. **Reserved names:** The following names are permanently reserved and MUST NOT be reused:
   - `koad` (root authority)
   - `juno` (mother entity, orchestrator)
   - `vesta` (platform stewardship)
   - `vulcan` (builder)

3. **Namespace Conflicts:** Before gestation, the entity name MUST be checked for conflicts with:
   - **AI models/assistants:** Claude, Gemini, ChatGPT, Copilot, Codex, etc. (and related product families)
   - **Developer tools:** Cursor, Copilot, Tabnine, Kite, etc.
   - **Major software brands:** Docker, Kubernetes, Git, Redis, Postgres, etc.
   - **Social networks or platforms:** Twitter, Discord, Slack, GitHub, etc.

   **Conflict Resolution:** If a conflict is found, REJECT the name and propose an alternative from Roman/classical mythology until a clear name emerges. Document the conflict and rejected alternative in the gestation log.

4. **Memorability & Pronunciation:**
   - Prefer names with 1-3 syllables (e.g., `vesta`, `mercury`, `salus` — short and crisp)
   - Avoid names that are difficult to spell or pronounce in English (entities must be nameable over chat/Slack)
   - Test pronunciation: can a non-native English speaker pronounce this without hesitation?

### Examples

✅ **Good Names:**
- `vesta` — Roman goddess, memorable, no conflicts, 2 syllables
- `mercury` — Roman god, pronounceable, no software conflicts, 3 syllables
- `salus` — Roman goddess of health, memorable, no conflicts, 2 syllables

❌ **Bad Names:**
- `claude` — conflict with Claude AI model
- `cursor` — conflict with Cursor editor
- `postgres` — major software brand
- `entity-helper-service-v2` — not human-ish, contains hyphens, too long

---

## 3. Pre-Conditions

### Authorization

Only these actors may initiate gestation:

- **koad:** Root authority, may gestate any entity
- **Juno:** Orchestrator, may gestate team entities (delegated authority)
- **Vulcan:** Builder, may gestate entities on koad's behalf

Any other entity attempting gestation fails at the trust bond validation step (see step 7 below).

### Environment Requirements

Gestation **MUST** occur:

- **User account:** `koad` (typically)
- **Machine:** The canonical development machine (`thinker.internal` or primary `koad.sh` host)
- **Shell:** `bash` (version 4.0+)
- **Git:** Configured with `user.name` and `user.email` (typically Vesta's or Juno's credentials)
- **Network:** Connectivity to `github.com/koad/<entity>` repository (must exist before gestation starts)

Gestation **MUST NOT** occur:

- On non-canonical machines (gestation logs differ, complicating audits)
- Under non-koad accounts (permission mismatches)
- Without pre-created GitHub repository (git operations fail)

### Pre-Gestation Checklist

Before starting gestation, Vulcan verifies:

- [ ] Entity name is valid: lowercase, 3-12 chars, no hyphens/underscores, not reserved (juno, vulcan, vesta, koad)
- [ ] **Entity name cleared for namespace conflicts** (see section 2 — no AI models, tools, or software brands)
- [ ] GitHub repository exists at `github.com/koad/<entity>`
- [ ] Repository is empty (no commits, no content)
- [ ] Caller has permission to gestate (trust bond check)
- [ ] Disk space available at `~/.{entity}/` (min 1 GB)
- [ ] No existing `~/.{entity}/` directory (or confirm overwrite)

---

## 4. Canonical Gestation Sequence

The gestation process consists of 12 sequential steps. **Each step MUST complete successfully before the next begins.** If any step fails, gestation is aborted and the partial entity is removed (see error handling, section 6).

### Step 1: Directory Structure Creation

Create the canonical directory tree per VESTA-SPEC-001, section 2:

```bash
ENTITY="<entity-name>"
ENTITY_DIR="/home/koad/.${ENTITY}"

mkdir -p "${ENTITY_DIR}"
mkdir -p "${ENTITY_DIR}/id"
mkdir -p "${ENTITY_DIR}/trust/bonds"
mkdir -p "${ENTITY_DIR}/memories"
mkdir -p "${ENTITY_DIR}/specs"
mkdir -p "${ENTITY_DIR}/projects"
mkdir -p "${ENTITY_DIR}/commands"
mkdir -p "${ENTITY_DIR}/hooks"
mkdir -p "${ENTITY_DIR}/home/${ENTITY}"
mkdir -p "${ENTITY_DIR}/.git"
mkdir -p "${ENTITY_DIR}/.cache"
mkdir -p "${ENTITY_DIR}/.logs"
mkdir -p "${ENTITY_DIR}/.queue"

# Verify all directories exist with correct permissions
find "${ENTITY_DIR}" -type d -exec chmod 755 {} \;
```

**Verification:** All directories exist and are readable/writable by `koad:koad`.

---

### Step 2: Git Repository Initialization

Initialize the git repository and configure the remote:

```bash
cd "${ENTITY_DIR}"

# Initialize repo with canonical defaults
git init --initial-branch=main

# Configure Git identity (typically Vulcan's or Juno's)
git config user.name "Vulcan"
git config user.email "vulcan@kingofalldata.com"

# Add GitHub remote
git remote add origin "https://github.com/koad/${ENTITY}.git"

# Verify configuration
git config --local --list | grep -E "^(user\.|remote\.)"
```

**Verification:** `git config` shows correct user and remote; `.git/config` is in place.

---

### Step 3: Cryptographic Key Generation

Generate all four key types (Ed25519, ECDSA, RSA, DSA) per VESTA-SPEC-001, section 3.

**Note:** This is the security-critical step. All private keys are generated locally and NEVER transmitted or logged.

```bash
cd "${ENTITY_DIR}/id"

# Ed25519 (primary signing key)
ssh-keygen -t ed25519 -f ed25519 -N "" -C "${ENTITY}" -m pem

# ECDSA (alternative signing key)
openssl ecparam -name prime256v1 -genkey -noout -out ecdsa.key
openssl pkcs8 -topk8 -nocrypt -in ecdsa.key -out ecdsa
rm ecdsa.key
openssl ec -in ecdsa -pubout -out ecdsa.pub

# RSA (asymmetric encryption key)
openssl genrsa -out rsa 2048
openssl rsa -in rsa -pubout -out rsa.pub

# DSA (legacy, optional but generated for compatibility)
openssl dsaparam -out dsa.pem 2048
openssl gendsa dsa.pem -out dsa
openssl dsa -in dsa -pubout -out dsa.pub
rm dsa.pem

# Set strict permissions on private keys
chmod 600 ed25519 ecdsa rsa dsa
chmod 644 *.pub

# Verify all keys exist and are readable
ls -la "${ENTITY_DIR}/id" | grep -E "^-rw"
```

**Verification:**
- All 8 files exist (4 private, 4 public)
- Private keys are readable only by owner (600)
- Public keys are world-readable (644)
- Each key type is tested: `ssh-keygen -l -f ed25519.pub`, `openssl ec -in ecdsa -text -noout`, etc.

---

### Step 4: Environment Initialization

Create the `.env` file per VESTA-SPEC-001, section 4:

```bash
cat > "${ENTITY_DIR}/.env" << 'EOF'
# Entity Identity
ENTITY="<ENTITY>"
ENTITY_DIR="<ENTITY_DIR>"
ENTITY_HOME="<ENTITY_DIR>/home/<ENTITY>"
GIT_AUTHOR_NAME="<ENTITY_TITLE_CASE>"
GIT_AUTHOR_EMAIL="<ENTITY>@kingofalldata.com"

# Creator & Relationships
CREATOR="vulcan"
MOTHER="juno"

# Identity & Keys
ENTITY_KEYS="<ENTITY_DIR>/id"
TRUST_CHAIN="<ENTITY_DIR>/trust"
CREATOR_KEYS="https://canon.koad.sh/vulcan.keys"
MOTHER_KEYS="https://canon.koad.sh/juno.keys"

# Role & Purpose
ROLE="<role>"
PURPOSE="<purpose>"

# Framework
KOAD_IO_VERSION="1.0.0"
KOAD_IO_QUIET=1
EOF
```

Substitute placeholders:
- `<ENTITY>` → entity name (e.g., `vesta`)
- `<ENTITY_DIR>` → absolute path (e.g., `/home/koad/.vesta`)
- `<ENTITY_TITLE_CASE>` → title case (e.g., `Vesta`)
- `<role>` → entity's role (e.g., `architect`, `builder`, `healer`)
- `<purpose>` → one-line mission statement

**Verification:** `.env` exists, is readable, contains all required variables:

```bash
source "${ENTITY_DIR}/.env"
[[ -n "$ENTITY" && -n "$ENTITY_DIR" && -n "$GIT_AUTHOR_NAME" ]] && echo "✓ .env valid"
```

---

### Step 5: `.gitignore` Creation

Create git ignore rules per VESTA-SPEC-001, section 7:

```bash
cat > "${ENTITY_DIR}/.gitignore" << 'EOF'
# Private Keys (NEVER commit)
id/ed25519
id/ecdsa
id/rsa
id/dsa

# Secrets
.env.local
.env.*.local
.env.secret*
.env.prod*

# Runtime state
.cache/
.logs/
.queue/
.tmp/
.pid

# Editor temp files
*~
*.swp
*.swo
.DS_Store

# Large files
*.tar.gz
*.zip

# Application-specific (each entity may extend)
node_modules/
__pycache__/
.pytest_cache/
target/
EOF
```

**Verification:** `.gitignore` exists and can be sourced/tested with `git status --porcelain`.

---

### Step 6: Trust Bond Scaffolding

Create the root trust bond document (signed by koad) that authorizes this entity:

```bash
mkdir -p "${ENTITY_DIR}/trust/bonds"

cat > "${ENTITY_DIR}/trust/bonds/koad-to-${ENTITY}.md" << 'EOF'
---
bond_id: "bond-<ENTITY>-<UUID>"
issuer: "koad"
subject: "<ENTITY>"
issued_date: "<ISO-8601 timestamp>"
expires_date: "<one year from issued_date>"
status: "active"
---

# Trust Bond: koad → <ENTITY>

## Authority

**Issuer:** koad (root authority)  
**Subject:** <ENTITY> (entity)

## Scope

This bond authorizes <ENTITY> to:

- Execute assigned commands
- Maintain own cryptographic keys
- Create sub-bonds with other entities (delegated authority)
- Participate in inter-entity communications
- Request diagnostic access (for Argus, Salus, Janus)

## Signing Keys

All communications from <ENTITY> MUST be signed with:

- **Primary:** Ed25519 public key at `~/.vesta/entities/<ENTITY>/public.key`
- **Secondary:** ECDSA public key for cross-verification

## Duration

Valid from: <issued_date>
Expires: <expires_date>

## Status

This bond is **active**. To revoke, Vesta updates `status: revoked` and commits to koad/vesta.

---

**Note:** This is a scaffold. Vulcan will populate with actual public keys before commit.

EOF
```

Replace placeholders:
- `<ENTITY>` → entity name
- `<UUID>` → unique identifier (e.g., `6f7e9c2a-7f5d-4e2a-b1a9-8c5d6f3a2b1e`)
- `<ISO-8601 timestamp>` → current UTC time (e.g., `2026-04-03T12:00:00Z`)
- `<one year from issued_date>` → expiry date (e.g., `2027-04-03T00:00:00Z`)

**Verification:** File exists, contains required fields, is parseable as YAML frontmatter.

---

### Step 7: Trust Bond Validation

Before proceeding, validate that the caller has permission to gestate this entity:

```bash
# Load the trust bond document
BOND_FILE="${ENTITY_DIR}/trust/bonds/koad-to-${ENTITY}.md"

# Extract issuer (must be "koad" for root entities)
ISSUER=$(grep "^issuer:" "$BOND_FILE" | awk '{print $2}')

# If issuer is "koad", gestation is authorized
if [[ "$ISSUER" == "koad" ]]; then
  echo "✓ Trust bond authorized by koad"
else
  echo "✗ Trust bond not authorized"
  exit 1
fi

# Verify status is "active"
STATUS=$(grep "^status:" "$BOND_FILE" | awk '{print $2}')
if [[ "$STATUS" == "active" ]]; then
  echo "✓ Trust bond is active"
else
  echo "✗ Trust bond is not active"
  exit 1
fi
```

**Verification:** Trust bond is valid and authorized. If this check fails, abort gestation.

---

### Step 8: `passenger.json` Creation

Create entity metadata file per VESTA-SPEC-001, section 5:

```bash
cat > "${ENTITY_DIR}/passenger.json" << 'EOF'
{
  "handle": "<entity>",
  "name": "<ENTITY_TITLE_CASE>",
  "role": "<role>",
  "status": "gestated",
  "created_at": "<ISO-8601 timestamp>",
  "created_by": "vulcan",
  "avatar": null,
  "buttons": []
}
EOF
```

Replace:
- `<entity>` → lowercase entity name
- `<ENTITY_TITLE_CASE>` → title case
- `<role>` → entity's role
- `<ISO-8601 timestamp>` → current UTC time

**Verification:** File exists, is valid JSON, contains all required fields.

---

### Step 9: `KOAD_IO_VERSION` Metadata

Create gestation metadata file per VESTA-SPEC-001, section 6:

```bash
cat > "${ENTITY_DIR}/KOAD_IO_VERSION" << 'EOF'
# koad:io entity

GESTATED_BY=vulcan
GESTATE_VERSION=<git-commit-hash-of-vesta-gestation-script>
BIRTHDAY=<YY:MM:DD:HH:MM:SS>
NAME=<entity-name>
EOF
```

Replace:
- `<git-commit-hash-of-vesta-gestation-script>` → Vesta's current commit (allows reproducibility)
- `<YY:MM:DD:HH:MM:SS>` → Current timestamp in the specified format
- `<entity-name>` → Entity name

**Verification:** File exists and is readable as shell source.

---

### Step 10: `CLAUDE.md` Population

Create the entity's AI runtime instructions by:

1. **If entity has a role-specific template:** Copy and substitute
   - Location: `~/.vesta/templates/claude-md/<role>.md`
   - Apply variable substitution per VESTA-SPEC-003 (gestation-template-entity-substitution.md)
   
2. **If no template exists:** Use a minimal default:

```bash
cat > "${ENTITY_DIR}/CLAUDE.md" << 'EOF'
# CLAUDE.md — <ENTITY_TITLE_CASE>

This file provides guidance to Claude Code when working in `~/.{entity}/`.

## What I Am

I am <ENTITY_TITLE_CASE> — [role description from passenger.json].

## Key Files

- `CLAUDE.md` — This file (runtime instructions)
- `.env` — Environment variables
- `passenger.json` — Entity metadata
- `trust/bonds/` — Authorization documents
- `id/` — Cryptographic keys (private keys gitignored)
- `memories/` — Persistent context across sessions

## Git Identity

```env
ENTITY=<entity>
ENTITY_DIR=<entity-dir>
GIT_AUTHOR_NAME=<entity-title-case>
GIT_AUTHOR_EMAIL=<entity>@kingofalldata.com
```

## Communication

Issues and work are tracked on GitHub: `github.com/koad/<entity>`

## Session Start

1. `git pull` — Sync with remote
2. Check open GitHub Issues — what priority work is pending?
3. Review current state — what's in flight?
4. Proceed with highest-priority open work
5. Report progress via issue comments and commits
EOF
```

**Verification:** `CLAUDE.md` exists, contains entity identity information, is readable.

---

### Step 11: `memories/001-identity.md` Creation

Create the entity's core identity document:

```bash
mkdir -p "${ENTITY_DIR}/memories"

cat > "${ENTITY_DIR}/memories/001-identity.md" << 'EOF'
---
name: <entity> identity
description: Core identity and self-knowledge
type: user
---

# <ENTITY_TITLE_CASE> Identity

I am <ENTITY_TITLE_CASE> — [role description].

**Name:** <ENTITY_TITLE_CASE> — [classical/Roman name chosen per VESTA-SPEC-002 Section 2. Name was cleared for namespace conflicts before gestation.]

## What I Own

- [List of protocol areas, systems, or responsibilities this entity owns]

## Key Relationships

- **Creator:** Vulcan
- **Mother:** Juno
- **Peers:** [List other entities this one coordinates with]

## Communication

- GitHub Issues: `koad/<entity>`
- Primary contact: koad@kingofalldata.com

## Session Context

This file is loaded at the start of each Claude session.
It provides continuous understanding across conversations.

EOF
```

**Verification:** File exists, contains entity identity, is in auto-memory format. Name field mentions conflict-checking per VESTA-SPEC-002.

---

### Step 12: Initial Commit

All files are now in place. Perform the initial commit:

```bash
cd "${ENTITY_DIR}"

# Stage all files except private keys (handled by .gitignore)
git add .

# Verify what's staged (should NOT include id/ed25519, id/ecdsa, etc.)
echo "=== Staged files ===" && git status

# Create initial commit
COMMIT_MESSAGE="Gestation: initial commit of <ENTITY>

Gestated by Vulcan (VESTA-SPEC-002).
Entity conforms to VESTA-SPEC-001 (canonical entity model).

Directory structure: ✓
Cryptographic keys: ✓
Trust bond: ✓
Environment: ✓
Metadata: ✓

Resolves koad/juno#<issue-number> (if applicable).

Co-Authored-By: Vulcan <vulcan@kingofalldata.com>"

git commit -m "$COMMIT_MESSAGE"

# Verify commit was created
git log --oneline | head -1
```

**Verification:** 
- Initial commit exists
- Commit message references gestation spec
- No private keys are in the commit (check `git ls-files`)
- Repository is ready to push

---

## 5. Template Substitution

If the entity was gestated using a template (e.g., from Juno), all template placeholders MUST be substituted per VESTA-SPEC-003 (gestation-template-entity-substitution.md).

Required substitutions:

| Placeholder | Value |
|-------------|-------|
| `$ENTITY` | Entity name (lowercase) |
| `$ENTITY_DIR` | Full path to entity directory |
| `$ENTITY_TITLE_CASE` | Entity name (title case) |
| `$GIT_AUTHOR_NAME` | Git author name |
| `$GIT_AUTHOR_EMAIL` | Git author email |

**Verification:** Run checks post-gestation (see section 5).

---

## 6. Post-Gestation Checklist

After the initial commit, the entity is considered **gestated but not validated**. Vulcan MUST verify:

### Structural Conformance (per VESTA-SPEC-001)

- [ ] All required directories exist: `id/`, `trust/bonds/`, `memories/`, `specs/`, `projects/`, `.git/`
- [ ] All required files exist: `CLAUDE.md`, `.env`, `passenger.json`, `KOAD_IO_VERSION`, `.gitignore`
- [ ] All cryptographic keys exist: `ed25519`, `ecdsa`, `rsa`, `dsa` (private + public)
- [ ] Private keys are not in git: `git ls-files | grep -E "^id/(ed25519|ecdsa|rsa|dsa)$"` returns empty
- [ ] `.env` is valid shell source: `source ${ENTITY_DIR}/.env && echo $ENTITY`

### Trust Bond

- [ ] Trust bond exists at `trust/bonds/koad-to-${ENTITY}.md`
- [ ] Bond contains all required fields: `issuer`, `subject`, `issued_date`, `expires_date`, `status`
- [ ] Bond's issuer is "koad" (for root entities)
- [ ] Bond's status is "active"

### Repository State

- [ ] Git repository is initialized: `git rev-parse --git-dir` succeeds
- [ ] Remote is configured: `git remote -v | grep origin`
- [ ] Default branch is `main`: `git rev-parse --abbrev-ref HEAD`
- [ ] Initial commit exists: `git rev-list --count HEAD` ≥ 1
- [ ] No uncommitted changes: `git status --porcelain` is empty

### Identity & Metadata

- [ ] `GIT_AUTHOR_NAME` is set in `.env` and matches title case
- [ ] `GIT_AUTHOR_EMAIL` matches entity name
- [ ] `passenger.json` is valid JSON and contains required fields
- [ ] `CLAUDE.md` mentions entity name (indicates substitution worked)
- [ ] `memories/001-identity.md` exists and references entity

### Audit Readiness

- [ ] All checks above pass
- [ ] Entity is ready for Argus audit (koad/vesta#19)
- [ ] Entity is ready for first operational use

**If any check fails:** STOP. Contact Vulcan and Vesta. Do not push to GitHub. Salvage what's needed, then clean up the failed entity directory.

---

## 7. Error Handling

### During Gestation

If gestation fails at any step:

1. **Log the error:** Record the step number, error message, and timestamp
2. **Abort gracefully:** Stop further processing
3. **Cleanup:** Remove the partial entity directory (`rm -rf ${ENTITY_DIR}`)
4. **Report:** File issue on `koad/vulcan` with error details and step number
5. **Remediate:** Address root cause before reattempting

### Example: Key Generation Fails

```bash
if ! ssh-keygen -t ed25519 -f ed25519 -N "" -C "${ENTITY}" -m pem; then
  echo "✗ Ed25519 key generation failed"
  rm -rf "${ENTITY_DIR}"
  exit 1
fi
```

### Partial Recovery

If gestation fails partway through and a human operator needs to resume:

1. Verify which steps completed (check directory structure, files)
2. Manually resume from the next incomplete step
3. Document manual changes in a separate commit message
4. Re-run the post-gestation checklist

---

## 8. Conformance Criteria

An entity has been successfully gestated if:

1. ✅ All steps 1-12 completed without error
2. ✅ All items in the post-gestation checklist pass
3. ✅ Argus audit passes (VESTA-SPEC-019: entity conformance audit)
4. ✅ Initial commit is pushed to GitHub
5. ✅ Entity is available for operational use

**Argus Audit:** Argus verifies conformance to this spec. File issues on koad/vesta if any gestated entity fails audit.

**Salus Healing:** If an entity fails post-gestation checks, Salus repairs structural issues (missing files, malformed metadata, etc.).

---

## 9. Glossary

| Term | Definition |
|------|-----------|
| **Gestation** | Process of creating a new entity from scratch |
| **Template** | Base entity files (CLAUDE.md, commands, etc.) that are copied and substituted |
| **Substitution** | Replacing placeholders ($ENTITY, etc.) with actual values |
| **Trust Bond** | Authorization document signed by issuer (koad, Vulcan, etc.) |
| **Conformance** | Meeting all requirements of VESTA-SPEC-001 (entity model) |

---

## 10. References

- VESTA-SPEC-001: Canonical Entity Model
- VESTA-SPEC-002: Canonical Gestation Protocol (this spec) — Section 2 governs naming
- VESTA-SPEC-003: Gestation Template Entity Substitution Protocol (placeholder replacement)
- VESTA-SPEC-012: Entity Startup Specification
- VESTA-SPEC-019: Entity Conformance Audit (Argus)
- koad/vulcan#2: Team entity gestation work

---

## Status

**Draft** — Ready for review by Vulcan, Juno, and Argus. Implementation deadline: 2026-04-10.

Addresses koad/vesta#14. Unblocks Vulcan's entity creation work.

## References

Blocks: koad/vulcan#2 (team entity creation)
Depends on: VESTA-SPEC-001 (entity model)
Related: VESTA-SPEC-003 (template substitution)
