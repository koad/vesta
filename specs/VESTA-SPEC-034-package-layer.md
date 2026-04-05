---
status: draft
id: VESTA-SPEC-034
title: "koad:io Package Layer — First-Class Framework Capabilities"
type: spec
version: 0.1
date: 2026-04-05
owner: vesta
description: "The ~/.koad-io/packages/ directory contains Meteor packages that are the foundational capability layer of the koad:io framework. This spec defines naming conventions, required structure, versioning policy, layering model, and the holographic pattern mapping."
related-specs:
  - VESTA-SPEC-001 (Entity Model)
  - VESTA-SPEC-006 (Commands System)
---

# VESTA-SPEC-034: koad:io Package Layer

**Authority:** Vesta. This spec defines the package layer: its structural role, naming conventions, required files, layering model, versioning policy, and relationship to the entity command system.

**Scope:** `~/.koad-io/packages/` — the 14 Meteor packages that ship with the koad:io framework. This spec does not cover Meteor application structure or deployment; it covers the package API contract that framework builders depend on.

**Consumers:**
- Vulcan (builds products on these packages)
- External builders (adopt koad:io to build their own applications)
- koad (maintains packages; ships with framework)
- Entity hook system (uses packages as runtime primitives)

---

## 1. The Package Layer's Role

The koad:io framework has a two-layer architecture:

```
~/.koad-io/    ← Framework layer (owned by Vesta's spec, maintained by koad)
~/.{entity}/   ← Entity layer (owned by each entity)
```

Within the framework layer, there is a further internal hierarchy:

```
~/.koad-io/
  bin/           ← CLI commands and shell wrappers
  commands/      ← Global commands (user-facing capabilities)
  packages/      ← Meteor package layer (framework capabilities for apps)
  templates/     ← Entity gestation templates
  lib/           ← Shared scripts and utilities
  daemon/        ← Always-on runtime
```

**The packages/ directory is the foundational capability layer for any app built on koad:io.** Every koad:io-powered web application (kingofalldata.com, Alice, community portals, Stream PWA) builds on these packages. They ship as part of the `koad/io` repository and are versioned with it.

The packages are Meteor packages. They are not npm packages, not standalone libraries. They are Atmosphere packages that implement the client-server-both isomorphic pattern native to Meteor's build system.

---

## 2. Holographic Pattern: Package = Capability

The koad:io framework uses a consistent holographic pattern across all layers:

| Layer | Unit of capability | Discovery |
|-------|--------------------|-----------|
| Framework commands (`~/.koad-io/commands/`) | Command | Directory traversal |
| Entity commands (`~/.{entity}/commands/`) | Command | Directory traversal |
| Framework packages (`~/.koad-io/packages/`) | Package | Meteor `api.use()` |
| Features (`~/.{entity}/features/`) | Feature spec | Directory + SPEC |

A package is to the application layer what a command is to the shell layer: a discrete, composable unit of capability that can be included or excluded. Adding a package to an app grants the app that capability. Removing it revokes it.

This means:

- Packages must be **independently includable** — adding `koad:io-search` to an app should not require adding an unrelated package
- Packages must be **composable** — apps may include any subset
- Packages should have **explicit exports** — what a package provides should be documented and stable

---

## 3. Naming Convention

### 3.1 Package Name Format

All koad:io framework packages follow the format:

```
koad:{descriptor}
```

- Prefix: `koad:`
- Descriptor: lowercase, hyphenated, descriptive of the capability

Examples:
```
koad:io            ← umbrella (imports all core packages)
koad:io-core       ← identity, IPFS, crypto, collections
koad:io-router     ← routing
koad:io-session    ← persistent sessions
```

### 3.2 Directory Name

The directory name in `~/.koad-io/packages/` mirrors the package name, with `:` replaced by `-` (Atmosphere convention for filesystem paths):

```
packages/
  koad-io/              ← koad:io
  koad-io-core/         ← koad:io-core
  koad-io-router/       ← koad:io-router
  ...
```

### 3.3 Naming for New Packages

New packages added to the framework must:

1. Use the `koad:io-` prefix (e.g., `koad:io-kingdoms`)
2. Use a descriptor that is a noun or noun phrase (not a verb)
3. Be lowercase and hyphenated
4. Not shadow existing Atmosphere package names

---

## 4. Required Package Structure

Every package in `~/.koad-io/packages/` must have the following structure:

```
packages/koad-io-example/
  package.js        ← REQUIRED: Atmosphere package manifest
  README.md         ← REQUIRED: what this package provides and how to use it
  client/           ← client-only code (optional if no client code)
  server/           ← server-only code (optional if no server code)
  both/             ← isomorphic code, runs on both client and server (optional)
```

### 4.1 package.js

The Atmosphere package manifest. Required fields:

```javascript
Package.describe({
  name: 'koad:io-example',
  version: 'X.Y.Z',
  summary: 'One sentence: what this package provides',
  git: 'https://github.com/koad/io',
  documentation: 'README.md'
});

Package.onUse(function(api) {
  api.versionsFrom('METEOR@3.0');     // Meteor 3 minimum
  api.use([...]);                      // explicit dependencies
  api.addFiles([...]);
  api.export([...]);                   // explicit exports — required
});
```

**`api.export()` is mandatory.** Every package must explicitly export its public API. Implicit globals are not acceptable.

### 4.2 README.md

Every package must have a README.md that documents:

1. **What it provides** — one-paragraph summary
2. **Usage** — `api.use('koad:io-example')` snippet
3. **Exports** — list of exported symbols with brief descriptions
4. **Dependencies** — which other koad:io packages are required

---

## 5. Package Inventory and Layering

### 5.1 Current Packages (as of 2026-04-05)

| Package | Version | Layer | Description |
|---------|---------|-------|-------------|
| `koad:io` | 8.8.8 | Umbrella | Imports all core packages; convenience entry point |
| `koad:io-core` | 3.6.9 | Foundation | Identity, IPFS, crypto, collections — the lowest level |
| `koad:io-router` | 3.6.9 | Foundation | Iron Router fork; client-side routing |
| `koad:io-session` | 3.6.9 | Foundation | Persistent reactive sessions |
| `koad:io-templating` | 3.6.9 | UI | Layout engine + Blaze helpers |
| `koad:io-navigation` | 1.0.0 | UI | Navigation UI components |
| `koad:io-theme-engine` | 3.6.9 | UI | CSS variables + theming |
| `koad:io-accounts` | 3.6.9 | Auth | Roles, invitations, authentication logic |
| `koad:io-accounts-ui` | 3.6.9 | Auth | QR login, social auth, BIP39 seed phrases |
| `koad:io-search` | 3.6.9 | Application | Reactive full-text search |
| `koad:io-event-logger` | 0.3.0 | Utilities | Error and event capture |
| `koad:io-worker-processes` | 0.0.1 | Utilities | Background job management |
| `koad:io-awesome-qr` | 0.0.1 | Utilities | QR code generation |
| `koad:io-plus-head-js` | 3.6.9 | Utilities | Browser detection, head injection |

### 5.2 Layering Model

Packages are organized in four layers. Each layer may depend on layers below it; never upward:

```
Umbrella
  └── koad:io (imports all)

Application
  ├── koad:io-search
  └── [future: kingdoms, stream, alice-specific]

UI
  ├── koad:io-templating
  ├── koad:io-navigation
  ├── koad:io-theme-engine
  ├── koad:io-accounts-ui
  └── koad:io-awesome-qr

Auth
  ├── koad:io-accounts
  └── (depends on Foundation)

Foundation
  ├── koad:io-core          ← lowest; no koad:io deps
  ├── koad:io-router        ← depends on core
  ├── koad:io-session       ← depends on core
  ├── koad:io-event-logger
  ├── koad:io-worker-processes
  └── koad:io-plus-head-js
```

An app including only `koad:io-core` and `koad:io-accounts` gets the minimum viable identity + auth stack. An app including `koad:io` gets everything. Builders choose the subset they need.

---

## 6. Versioning Policy

### 6.1 Version Scheme

Packages use semantic versioning (SemVer): `MAJOR.MINOR.PATCH`.

| Change type | Version bump |
|-------------|-------------|
| API addition (backward-compatible) | MINOR |
| Bug fix, no API change | PATCH |
| Breaking API change | MAJOR |
| Internal refactor, no external change | PATCH |

### 6.2 Current Version Inconsistency

The current inventory has inconsistent versioning:
- Core packages: `3.6.9` (suggesting significant API maturity)
- Some packages: `0.0.1` (suggesting pre-release)
- Umbrella: `8.8.8` (ceremonial versioning — not SemVer in the conventional sense)

**Policy for normalization:**

- `koad:io` (umbrella) may retain its ceremonial version; it is a meta-package and its version signals framework maturity, not API specifics
- All other packages must migrate to honest SemVer on their next meaningful change
- Packages at `0.0.1` should be bumped to `0.1.0` once they have a documented, stable API (even if pre-1.0)
- Packages at `3.6.9` may stay unless a breaking change warrants a MAJOR bump

### 6.3 Coordination

Because packages may depend on each other, version bumps must be coordinated. A breaking change in `koad:io-core` may require MAJOR bumps in dependent packages. koad maintains this coordination; Vulcan flags conflicts when building on these packages.

---

## 7. Meteor 3 Compatibility Requirements

### 7.1 Async Methods

Meteor 3 dropped Fibers. All server-side methods must be async:

```javascript
// Before (Meteor 2, Fibers-based):
Meteor.methods({
  myMethod: function() {
    return SomeCollection.findOne();
  }
});

// After (Meteor 3, async):
Meteor.methods({
  myMethod: async function() {
    return await SomeCollection.findOneAsync();
  }
});
```

All packages in the Foundation and Auth layers must be fully async-compatible.

### 7.2 `getTextAsync`

Meteor 3 introduces `getTextAsync` for text asset loading. Packages that use `Assets.getText()` must migrate to `Assets.getTextAsync()`.

### 7.3 Compatibility Tracking

Each package README.md must include a **Meteor 3 Compatibility** section:

```markdown
## Meteor 3 Compatibility
Status: ✓ fully async | ⚠ partial (list blocking items) | ✗ not yet migrated
```

Vulcan is responsible for tracking and upgrading Meteor 3 compatibility. koad approves major API changes.

---

## 8. External Builder Contract

When an external builder adopts koad:io, the package layer is what they inherit. The contract:

1. **Stable exports**: exported symbols from packages at `>= 1.0.0` do not break without a MAJOR bump
2. **Documentation**: every exported symbol is documented in the package README.md
3. **Discoverability**: the `koad:io` umbrella package is the entry point; `api.use('koad:io')` gets all stable capabilities
4. **Versioning**: packages follow SemVer; breaking changes are communicated with a CHANGELOG entry
5. **Dependencies**: all dependencies are declared in `package.js`; no implicit globals, no undeclared deps

External builders should not fork packages to add capabilities — they should file issues on `koad/io` for additions, or build their own packages that `api.use()` the koad:io foundation packages.

---

## 9. New Package Protocol

To add a new package to `~/.koad-io/packages/`:

1. **Name the package** following §3
2. **Create the directory** with the required structure (§4)
3. **Document exports** in `package.js` and `README.md`
4. **Assign a layer** (§5.2) and ensure no upward dependencies
5. **Set initial version**: `0.1.0` for new packages
6. **Add to umbrella**: if the package is general-purpose, add `api.use('koad:io-newpkg')` to `koad:io`
7. **Commit and push** to `koad/io`
8. **File issue on koad/vulcan** if implementation work is needed

Vesta is the approving authority for new packages that change the framework API contract. koad is the final approver.

---

## 10. Open Questions

1. **Package testing**: Meteor package tests (Tinytest)? Or full Meteor app integration tests? No testing standard currently exists for these packages.

2. **Distribution outside Atmosphere**: With Atmosphere's future uncertain post-Meteor 3, should packages have npm equivalents? Or stay Atmosphere-only since they depend on Meteor APIs?

3. **kingdoms package**: A `koad:io-kingdoms` package would expose the kingdoms filesystem to Meteor apps. When should this be created? (Depends on SPEC-029 Phase 1 implementation.)

4. **Package audit**: Which packages have undeclared globals or implicit deps? Needs a Vulcan audit pass before any breaking changes.

---

## References

- VESTA-SPEC-001: Entity Model (framework layer structure)
- VESTA-SPEC-006: Commands System (holographic pattern at the command layer)
- Meteor 3 documentation (async APIs, package system)
- Atmosphere package repository (existing published packages)
- `~/.koad-io/packages/` (the actual packages; this spec describes their contract)

---

*Spec originated 2026-04-05. Resolves koad/vesta#80. Package audit and Meteor 3 migration tracking assigned to Vulcan.*
