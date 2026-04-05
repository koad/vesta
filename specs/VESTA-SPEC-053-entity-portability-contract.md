---
id: VESTA-SPEC-053
title: Entity Portability Contract — The Repo IS the Entity
status: canonical
created: 2026-04-05
author: Vesta
applies-to: all entities, koad:io framework
supersedes: —
supplements: VESTA-SPEC-020 (hook architecture), VESTA-SPEC-012 (entity startup), VESTA-SPEC-051 (PRIMER convention)
---

# VESTA-SPEC-053: Entity Portability Contract — The Repo IS the Entity

## Purpose

An entity is its repository. Nothing more, nothing less. An entity that requires a specific machine, a specific API configuration, or a specific database to operate is not a sovereign entity — it is a hosted service with a git repo attached.

This spec defines what must be in a portable entity's repo, what must not be, how the Agent tool invokes a portable entity on any machine, how cross-machine synchronization works, and what the one known exception to portability is (Vulcan on wonderland).

---

## 1. The Portability Principle

> **An entity runs wherever `claude` is installed.**

This is the portability guarantee. It means:

- The entity's repo is cloned to a new machine
- The machine has `claude` (Claude Code) installed and authenticated
- The entity's hook is run
- The entity operates with full capability

No other preconditions. No machine-specific setup scripts. No database seeding. No external service dependencies that are not either (a) explicit in the entity's brief or (b) recoverable from git history.

This is not a theoretical aspiration — it is a design constraint. When building an entity, every architectural decision should be evaluated against the question: **does this break portability?**

---

## 2. Required Files for Portability

The following files must be present in a portable entity's repository. Their absence means the entity is not portable.

| File | Purpose | Notes |
|------|---------|-------|
| `CLAUDE.md` | Architecture, rules, entity identity | Loaded by harness at every session |
| `PRIMER.md` | Current-state orientation for agents | See VESTA-SPEC-051 |
| `.env` | Configuration (not secrets) | Gitignored from koad:io defaults; must be present for the entity to function |
| `hooks/` | Entity hook directory | The hook IS the entity's invocation contract |
| `memories/` | Long-term entity memory | `memories/MEMORY.md` is the index |

### 2.1 CLAUDE.md

The CLAUDE.md defines what the entity is, what its rules are, how it operates, and what framework it lives in. It is the harness-loadable identity layer. Without it, `claude` has no context about who it is in this directory.

CLAUDE.md must not contain machine-specific paths, usernames, or IP addresses. It must work on any machine where the entity's directory structure is preserved.

### 2.2 PRIMER.md

The orientation file. Without it, the first thing the agent does in a new session is reconstruct context from git log — slower, less accurate, and error-prone.

See VESTA-SPEC-051 for what PRIMER.md must contain.

### 2.3 .env

The `.env` file carries configuration: entity name, directory paths, git author identity, harness selection (`HARNESS=claude`), and any other non-secret configuration the entity needs to function.

The `.env` ships in git. This is intentional and correct. Configuration is not sensitive. Secrets are never in `.env` — they live in `.credentials` (gitignored).

Because `.env` ships in git, paths must use portable conventions. The standard is:

```env
ENTITY=juno
ENTITY_DIR=/home/koad/.juno
ENTITY_HOME=/home/koad/.juno/home/juno
GIT_AUTHOR_NAME=Juno
GIT_AUTHOR_EMAIL=juno@kingofalldata.com
HARNESS=claude
```

When cloning to a different machine with a different username or home directory, the operator updates ENTITY_DIR and ENTITY_HOME to match the new machine's paths. This is the one manual step permitted in a portability migration.

### 2.4 hooks/

The hook directory contains the entity's invocation contract. The hook is what the harness calls when the entity is invoked. Without a hook (or with a broken hook), the entity falls back to the framework default, which may not be correct for this entity's configuration.

Hooks must not hard-code machine-specific paths. They must use `$ENTITY_DIR` (from `.env`) for all path references.

See VESTA-SPEC-020 for the full hook architecture specification.

### 2.5 memories/

The memories directory is the entity's long-term context layer. `memories/MEMORY.md` is the index. Without it, each session starts from zero — the agent has no accumulated knowledge of its own operational history.

Memories are committed to git. They are part of the entity's state. When an entity is migrated to a new machine, its memories migrate with it — no state is lost.

---

## 3. What Must NOT Be in the Repo

The following must never appear in a portable entity's git history.

### 3.1 Secrets

`.credentials` is gitignored. It holds:
- API keys
- Private authentication tokens
- Passwords
- Private halves of asymmetric key pairs (unless the `id/` directory is explicitly scoped)

If a secret is accidentally committed, it must be treated as compromised immediately. The recovery procedure is in the memory file `feedback_key_compromise.md`: regenerate, re-sign bonds, update canon.koad.sh.

### 3.2 Machine-Specific State

Files that describe the state of a specific machine do not belong in the entity repo:
- PID files
- Lock files (runtime state, not configuration)
- Log files from specific invocations (use `LOGS/` for session summaries, not raw logs)
- Machine-specific SSH configuration beyond what is described in CLAUDE.md

### 3.3 Absolute Paths That Reference the Current Machine

Hardcoded paths to `/home/koad/` or any username-specific path violate portability. All paths in committed files must either use the `$ENTITY_DIR` convention or document explicitly that they require operator adjustment on migration.

### 3.4 Submodules

Git submodules break portability. Entity directories must be flat git repositories. See memory `feedback_no_submodules.md`.

---

## 4. How the Agent Tool Invokes a Portable Entity

The Agent tool (Claude Code's built-in sub-agent capability) is the primary mechanism for invoking a portable entity as a local subagent. It does not require SSH, does not require a separate process, and does not require a window.

### 4.1 Standard Invocation Pattern

```
Use the Agent tool with:
  - cwd: /home/koad/.<entity>/
  - prompt: [entity context brief] + [specific task]
  - run_in_background: true (for non-blocking coordination)
```

The brief prepended to the task prompt should include:
1. The entity's identity ("You are Vulcan, builder entity for the koad:io ecosystem")
2. The current task in one to three sentences
3. Any cross-entity context the entity needs that it cannot derive from its own repo
4. Expected output or completion signal

The entity reads its own `CLAUDE.md` and `PRIMER.md` during the session. The brief supplements, not replaces, that context.

### 4.2 Context Brief Template

```
You are [Entity], [one-line role description].

Working directory: /home/koad/.<entity>/
Your CLAUDE.md and PRIMER.md have full context on your current state.

Task: [specific task description]

On completion: [what to commit/output/file as a result]
```

### 4.3 Parallel Invocation

Multiple entities can be invoked in parallel via the Agent tool. Each runs in its own working directory with its own context. There is no shared mutable state between them at the repo level — each entity's git repo is its own isolated state container.

Coordination between parallel entity sessions happens via:
- GitHub Issues (primary inter-entity protocol)
- Shared files in `~/.koad-io/` (framework layer, read-only for entities)
- Explicit hand-off when one entity's output is another's input

Do not invoke entities in chains that require immediate sequential output without acknowledging that each entity session is independent and stateless relative to the previous one.

### 4.4 Background vs. Observed Invocation

| Invocation mode | When to use |
|----------------|-------------|
| `run_in_background: true` | Coordinated work — Juno delegates and continues; results return via git log and output |
| `juno spawn process <entity>` | Observed autonomous sessions — koad wants to watch the entity work in a terminal window with OBS streaming |

Use Agent tool (background) for coordinated multi-entity work. Use `spawn process` only when koad explicitly requests an observed session.

---

## 5. Cross-Machine Behavior

### 5.1 Git Pull Is the Sync Mechanism

There is no other sync layer. When an entity's repo is present on multiple machines (e.g., `~/.juno` on both thinker and fourty4), the sync mechanism is:

```bash
cd ~/.juno && git pull
```

This must be done before reading any file from a cross-machine entity repo. Entity state is in git. A local copy without a recent pull is stale.

See memory `feedback_git_pull_before_read.md`.

### 5.2 No Daemon Sync Required

Entities do not require a running daemon to be portable. The daemon enhances entity capabilities (real-time state, DDP subscriptions, passenger jobs) but is not a portability dependency. An entity without a daemon falls back to file-based state, which is fully portable.

### 5.3 No Database Seeding

Entity state that requires a database to exist (MongoDB collections, etc.) must be recoverable from git history or re-derivable from current repo state. An entity that cannot start from a fresh database clone is not portable.

If an entity has database state that is not in git, that state is ephemeral by definition. Document this explicitly in the entity's CLAUDE.md if it is intentional.

### 5.4 SSH Keys and Credentials

SSH keys, GPG keys, and other credentials do not migrate automatically. The portability contract covers code and configuration, not secrets. When migrating to a new machine:

1. Generate new keys for the entity on the new machine
2. Register the new public keys with GitHub (`gh ssh-key add`)
3. Re-sign trust bonds if private signing keys changed
4. Update `canon.koad.sh/<entity>.keys` with new public key

This is a one-time setup per machine, not a recurring overhead.

---

## 6. The Vulcan Exception

Vulcan is the one entity with a hard portability exception.

**Vulcan always builds on wonderland, paired with Astro.**

This is not a technical limitation — it is an operational decision made by koad. Wonderland has the uncommitted Alice work, the active build environment, and the specific context that Vulcan and Astro have co-developed. Migrating Vulcan to thinker or fourty4 and having him build there would produce worse outcomes.

The portability contract applies to Vulcan's repo (his files, memories, and identity are fully portable), but his invocation is constrained:

| Constraint | Value |
|-----------|-------|
| Permitted build host | wonderland |
| Permitted pairing | with Astro |
| Invocation method | GitHub Issues (not Agent tool) |
| Direct local invocation | Never — file an issue on koad/vulcan |

When Juno needs Vulcan to build something, Juno files a GitHub Issue on `koad/vulcan`. Vulcan picks it up in his next session on wonderland. He does not receive direct invocations via the Agent tool.

This exception is documented here so that operators migrating entities to new machines understand that Vulcan's portability is real but his operational scope is constrained by agreement, not by technical impossibility.

---

## 7. Portability Self-Check

Before declaring an entity gestated and ready for operation, apply this checklist:

```
[ ] CLAUDE.md is present and does not contain machine-specific paths
[ ] PRIMER.md is present and reflects current state
[ ] .env is present in git and uses $ENTITY_DIR conventions
[ ] hooks/ directory is present; hook uses $ENTITY_DIR, not absolute paths
[ ] memories/MEMORY.md exists (may be minimal at gestation)
[ ] .credentials is in .gitignore
[ ] No secrets appear in git log (check: git log --all -p | grep -i 'api_key\|password\|secret')
[ ] No submodules in .gitmodules
[ ] Entity can be cloned and invoked with claude from the cloned directory
```

The last item is the definitive test. If a fresh clone on a clean machine produces a working entity session, the entity is portable.

---

## 8. Why Portability Matters

The koad:io core principle is: **not your keys, not your agent.** Portability is how that principle is operationalized.

An entity that only runs on one machine is not sovereign — it is hosted. If that machine fails, is compromised, or becomes unavailable, the entity is gone. A portable entity survives machine failure because the entity's state is in git, and git is everywhere.

Portability also enables:
- **Forking**: anyone can clone a public entity repo and run their own instance
- **Auditing**: the entity's full history is in git — every decision, every commit
- **Recovery**: from any state, a git clone + git pull returns the entity to current operational state
- **Distribution**: the act of publishing an entity repo is the act of shipping the product

The entity portability contract is not a technical nicety. It is the mechanism by which the koad:io sovereignty guarantee is enforced.

---

## 9. Relation to Other Specs

| Spec | Relationship |
|------|-------------|
| VESTA-SPEC-020 | Hook architecture — hooks must be portable; this spec defines the portability requirement |
| VESTA-SPEC-012 | Entity startup sequence — startup assumes portability; PRIMER.md is step 1 |
| VESTA-SPEC-051 | PRIMER convention — PRIMER.md is a required file per this spec |
| VESTA-SPEC-038 | Entity host permission table — host constraints are documented there; they override portability for specific operational reasons (Vulcan/wonderland is the primary example) |

---

*Filed by Vesta, 2026-04-05. The portability contract formalizes what has been operational practice since gestation: entities are files on disk, git is the sync layer, and the ability to clone and run is the sovereignty guarantee. This spec gives implementers a checklist and gives operators a clear migration path.*
