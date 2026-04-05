---
status: constraint-documented
id: VESTA-SPEC-047
title: "Alice Session Sync Model — Cross-Device Constraint Documentation and Decision Boundary"
type: spec
version: 1.0
date: 2026-04-05
owner: vesta
related-specs:
  - VESTA-SPEC-044 (Alice Conversation Protocol — local filesystem model that this spec extends)
  - VESTA-SPEC-032 (Sovereignty Risk Assessment — framework for evaluating sync options)
related-briefs:
  - ~/.muse/briefs/alice-ui-design-brief.md (§ "Returning learner edge case")
resolves:
  - Muse multi-device question raised in alice-ui-design-brief.md
---

# VESTA-SPEC-047: Alice Session Sync Model

**Authority:** Vesta (platform stewardship). This spec documents the cross-device constraint for Alice learner state, evaluates sync options against sovereignty principles, and defines the decision boundary for Phase 1.

**Status:** `constraint-documented` — this is not a "not yet" gap. It is a deliberate decision with a documented rationale. A future spec (VESTA-SPEC-047-v2 or a separate spec) will address sync if and when the constraint is lifted.

**What Muse raised:** In the Alice UI brief, Muse noted a multi-device question: "conversation stored in ~/.alice/ locally, but learner switches devices." This spec answers that question fully.

---

## 1. The Constraint, Precisely Stated

All Alice learner state lives in `~/.alice/learners/{uuid}/` on the machine where Alice runs (VESTA-SPEC-044). This directory is:

- Not synced to any external service
- Not replicated to other devices
- Not addressable from outside the local machine
- Owned entirely by the local operator (koad:io framework user)

**Consequence:** If a learner begins Alice's curriculum on Device A and later opens the MVP Zone on Device B (or visits kingofalldata.com from a different browser), Alice on Device B has no record of them. From Device B's perspective, the learner is new.

This is not a bug. This is the local-first, sovereignty-first model working as intended.

---

## 2. Why This Is the Right Default

### 2.1 Sovereignty Alignment

The koad:io design principle is: **files on disk, your keys, no vendor, no kill switch.** A sync model that replicates learner state to an external server — even koad's own server — creates:

- A dependency on that server's availability
- A custody question: whose copy is authoritative?
- A privacy exposure: learner progress is visible to the server operator
- A kill switch: if the sync service is down, the learner's state is inaccessible

These are exactly the failure modes koad:io is built to avoid.

### 2.2 Phase 1 Scope

Alice Phase 1 is a single-device experience. The MVP Zone is served from kingofalldata.com. Alice's entity process runs on the server that hosts the site. Learners visit the site, interact with Alice, and their state is stored on that server under `~/.alice/`.

In Phase 1, "multi-device" is not a real user scenario because:
- The learner does not run their own Alice instance
- The learner's state is held by the site's Alice instance
- The learner interacts via browser — same Alice regardless of which browser they use
- The UUID is the learner's portable credential (shown on the graduation certificate)

**The multi-device problem only becomes real when:**
- A learner runs their own Alice instance (koad:io operator model, post-Phase 1)
- That learner wants to continue their curriculum on a different machine running Alice
- Or when a learner switches from the hosted Alice to their own Alice

This is a Phase 2+ scenario.

### 2.3 Sovereignty Risk of Available Sync Options

Vesta assessed available sync options against VESTA-SPEC-032 criteria:

| Option | Sovereignty Risk | Notes |
|--------|-----------------|-------|
| Git-based sync (`~/.alice/` as a git repo, pushed to GitHub) | Medium | GitHub dependency; learner state visible to GitHub; requires git literacy from learner |
| IPFS / content-addressed storage | Medium | Infrastructure dependency; IPFS availability varies; adds complexity |
| Hosted sync API (koad.io owned) | High | koad runs the server; learner state is on koad's infrastructure; kill switch exists |
| Keybase encrypted filesystem | Low-Medium | Sovereign keys; E2E encrypted; but Keybase is now Zoom-owned; see VESTA-SPEC-032 §4 |
| Manual file transfer (scp / USB / rsync) | None | Technically correct; user-hostile; acceptable for advanced operators |
| Kingdoms filesystem (VESTA-SPEC-029) | Low | Sovereign; git-addressable; but not yet implemented |

**None of these are acceptable for Phase 1.** The Kingdoms filesystem (VESTA-SPEC-029) is the right long-term answer — each learner's Alice state lives in their own kingdoms namespace, portable across their machines. But VESTA-SPEC-029 is a draft-50k spec. It is not ready to implement.

---

## 3. Phase 1 Decision

**Decision:** Alice is single-device in Phase 1. No sync. No cross-device state. The graduation certificate (with its UUID) is the learner's portable credential.

**Accepted tradeoff:** A learner who completes levels on one device and switches devices will see themselves as new on the new device. Their progress is not lost — it lives on the original device — but it is not accessible from the new device without manual intervention.

**This decision is final for Phase 1.** Vulcan does not need to build any sync infrastructure. Alice does not need any network calls for state management.

---

## 4. Available Recovery Paths (Phase 1)

These paths exist today without any new infrastructure. They are documented here so Vulcan can implement recovery UX if desired (not required for Phase 1 launch).

### 4.1 UUID-Based Recovery (Partial)

The graduation certificate displays the learner's UUID. A learner who has completed all 12 levels and switched devices can:

1. Find their UUID on their certificate (on Device A, or in a screenshot)
2. On Device B, tell Alice "I have a learner ID from another device"
3. Alice creates a stub `identity.md` on Device B with the provided UUID and `display_name`
4. Completion records are not transferred — the learner must re-demonstrate mastery (or use accelerated assessment for each level)

**This path is optional UX.** Alice can implement it as a recovery prompt in the "Have we spoken before?" moment (Muse brief §1a, returning learner edge case). It is not required for Phase 1.

### 4.2 Manual State Transfer (Operator Path)

A technically literate learner (or the site operator on their behalf) can copy the learner directory:

```bash
scp -r alice@device-a:~/.alice/learners/{uuid}/ ~/.alice/learners/
```

After this copy, Alice on Device B has full state including completion records. No data loss.

This path is documented for operators, not surfaced in the Alice UI. It is the correct path for koad:io operators who run their own Alice instance.

### 4.3 Fresh Start (Default)

If neither of the above paths is taken, Alice treats the learner as new on the new device. She collects a new name and generates a new UUID. The learner has two separate identities on two devices. Eventually one will "win" (the one where they reach graduation).

This is not ideal, but it is honest, simple, and consistent with the local-first model.

---

## 5. Future Sync Design Constraints

When cross-device sync is addressed (likely post-Phase 1, in conjunction with VESTA-SPEC-029), the following constraints must hold:

1. **Sovereign by default.** The learner's UUID and progress must never be visible to a third party without the learner's explicit consent.

2. **Local-primary.** The local filesystem is always authoritative. Sync is additive, not replacing the local model. An offline learner's progress is never blocked by sync failure.

3. **No mandatory accounts.** A learner should be able to complete the full curriculum without creating any account beyond a locally-stored UUID. Sync, if enabled, is opt-in.

4. **Kingdoms-compatible.** The sync model should be expressible in terms of VESTA-SPEC-029 (kingdoms filesystem) and VESTA-SPEC-031 (kingdoms state layer). Do not design a parallel sync system — align with the kingdoms model when it is ready.

5. **Portability of the UUID.** The UUID generated in Phase 1 must be usable in any future sync model. Do not deprecate Phase 1 UUIDs. The graduation certificate's UUID is a permanent credential.

---

## 6. What Vulcan Does Not Build

To be explicit: Vulcan does not build any of the following for Phase 1:

- A sync API endpoint for Alice learner state
- Any server-side storage of learner progress (beyond what Alice writes to the local filesystem where Alice runs)
- A "continue on another device" UX flow
- A learner account system tied to email, phone, or external identity

These are deferred. The constraint is documented. The decision is made.

---

## 7. Note on Hosted Alice vs. Operator Alice

There are two deployment contexts for Alice:

**Hosted Alice** (`kingofalldata.com`): Alice runs on koad's server. Learners visit via browser. `~/.alice/` is on koad's server. "Multi-device" means "multiple browsers" — the state is already centralized on the server, so there is no multi-device problem. The learner's UUID is the only portable credential they need to identify themselves to Alice.

**Operator Alice** (self-hosted koad:io): A koad:io operator runs Alice on their own machine. Learners interact with that operator's Alice. The multi-device problem is real here because the operator's machine is the single Alice instance. If the operator's machine changes, learner state must migrate with it.

Phase 1 ships Hosted Alice only. Operator Alice is a Phase 2+ scenario. The sync constraint documented in this spec applies to Operator Alice. Hosted Alice does not have this problem.
