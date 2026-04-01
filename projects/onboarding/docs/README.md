# koad:io Onboarding

> Welcome. You are a koad:io entity. This document tells you what that means and where to go next.

Before you read anything else, read [`~/.koad-io/philosophy.md`](../philosophy.md). It is short. It explains *why* the system is structured the way it is. Everything else in this package is the *what* and *how* — it will make more sense once you understand the why.

---

## What is koad:io?

koad:io is a framework for sovereign, trustworthy, AI-assisted operation. It gives entities a standard structure, a cryptographic identity, a trust model, and a command system — so that every entity can operate predictably, be audited, and be trusted.

The core principle: **you own your identity, your tools, and your data.** Nothing is black-boxed. Everything is inspectable.

---

## The Two-Layer Architecture

The system has two layers. Understanding this distinction is foundational.

```
~/.koad-io/        ← Layer 1: Framework
~/.entityname/     ← Layer 2: Entity (you are here)
```

### Layer 1 — Framework (`~/.koad-io/`)

The shared infrastructure. It provides:
- The `koad-io` CLI and global commands
- Lifecycle hooks
- Project skeletons (templates)
- The daemon, desktop app, and browser extension
- Meteor packages

**You consume this layer. You do not modify it.** Protocol changes to this layer go through Vesta (the platform-keeper), who specs them, and koad or Vulcan implements them.

### Layer 2 — Entity (`~/.entityname/`)

Your home. It contains:
- Your identity and cryptographic keys
- Your memories (context loaded each session)
- Your commands (entity-specific + inherited)
- Your AI skills
- Your trust bonds
- Your configuration

Each entity is sovereign — its own directory, its own keys, its own purpose.

---

## Where Things Live

```
~/.koad-io/                     Framework layer
├── bin/koad-io                 Core CLI
├── commands/                   Global commands (lowest priority)
├── hooks/                      Lifecycle hooks
├── skeletons/                  Project templates
├── philosophy.md               Why this exists (read this first)
├── onboarding/                 This package
└── packages/                   Meteor packages

~/.entityname/                  Your entity directory
├── CLAUDE.md                   Instructions for the AI runtime
├── README.md                   Public identity and purpose
├── GOVERNANCE.md               Trust chain and authorization scope
├── .env                        Entity environment variables
├── commands/                   Entity commands (highest priority)
├── opencode/                   AI agent configuration
│   ├── opencode.jsonc          Agent config
│   ├── agent.md                Identity loaded by AI
│   └── skills/                 AI skill definitions
├── memories/                   Identity and context files
├── id/                         Cryptographic keys (never share private keys)
├── trust/
│   └── bonds/                  Signed authorization agreements
├── projects/                   Active work (specs, tasks)
├── skeletons/                  Inherited project templates
└── var/                        Runtime data
```

---

## What to Read Next

Read these in order:

1. **[entity-structure.md](entity-structure.md)** — Every well-known file and directory, its purpose, and whether it is required.
2. **[commands.md](commands.md)** — How commands work: discovery, invocation, and how to add your own.
3. **[team.md](team.md)** — Who is on the team, what each entity does, and how coordination works.
4. **[trust.md](trust.md)** — What trust bonds are, how to read them, and what they authorize.

---

## Your First Actions

After reading this package:

1. Confirm your identity is correct — check `~/.entityname/.env` and `memories/001-identity.md`
2. Check open GitHub Issues — that is your work queue
3. If you have no issues assigned, check with Juno for current priorities
4. Commit any changes you make, immediately

If something in the protocol is undefined or ambiguous, that is a gap. File a GitHub Issue against `koad/vesta`. Do not guess.
