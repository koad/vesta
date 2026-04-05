---
status: draft-50k
id: VESTA-SPEC-031
title: "Kingdoms State Layer — Daemon-Backed Database per Namespace"
type: spec
version: 0.1
date: 2026-04-04
owner: vesta
description: "Each kingdoms namespace owns its database. The daemon is the state machine — MongoDB backing, DDP real-time sync, agent queues. Unifies all surfaces: bash hooks, browser tabs, PWAs, passenger. 50,000-foot spec — shape captured, implementation deferred."
related-specs:
  - VESTA-SPEC-009 (Daemon Specification)
  - VESTA-SPEC-014 (Kingdom Peer Connectivity Protocol)
  - VESTA-SPEC-029 (Kingdoms Filesystem)
  - VESTA-SPEC-030 (Community Namespaces)
altitude: 50k
---

# VESTA-SPEC-031: Kingdoms State Layer

**Altitude:** 50,000 feet. This spec captures the architectural shape. Do not implement until the kingdoms filesystem (SPEC-029) and daemon peer network (SPEC-014) are stable.

---

## 1. The Problem with Astro's MongoDB

Astro was the first entity to run a daemon with MongoDB. The state landed there. A dozen PWAs connect to Astro's DDP endpoint. It works — but the state belongs to Astro's namespace, not to the work being done. When more entities join, they either share Astro's database (wrong owner) or run isolated databases (fragmented state).

The state should belong to the namespace it describes.

---

## 2. The Shape

```
/kingdoms/<entity>/databases/
  state/          ← primary state database (MongoDB)
  queues/         ← per-agent message queues
  events/         ← event log (append-only)
```

```
/kingdoms/wonderland/databases/
  state/          ← community shared state
  queues/
    juno/         ← Juno's queue in this community context
    alice/        ← Alice's queue
  events/
```

The daemon serves the database at the kingdoms path. Any process that can reach the daemon can read/write the state — bash hook, browser tab, PWA, passenger, another entity's hook.

---

## 3. The Daemon as State Machine

The daemon is the unifying layer across all surfaces:

```
bash hook
  → writes event to daemon
  → daemon updates /kingdoms/<entity>/databases/state
  → DDP publishes change
  → browser tab receives update in real time
  → passenger surfaces relevant state
  → PWA reflects new state
```

One write. All surfaces update. No polling. No separate sync step.

This is what DDP was built for. The daemon runs DDP. Every connected client — browser, PWA, passenger, CLI tool — subscribes to the state it cares about. The state machine is the daemon. The storage is the kingdoms path. The protocol is DDP.

---

## 4. Per-Agent Queues

Each agent connected to the daemon has a queue at `/kingdoms/<entity>/databases/queues/<agent>/`.

The daemon routes work to agents via their queue:
- A hook fires, writes a task to Juno's queue
- Juno's worker picks it up, processes it, writes result to state
- DDP notifies all subscribers

No agent has to poll. No direct agent-to-agent messaging needed for simple task routing. The daemon is the broker. The queue is the interface.

This replaces ad-hoc entity invocations for simple state-triggered work — the queue handles it without a human or orchestrating entity in the loop.

---

## 5. Community State

Community namespaces (SPEC-030) get community databases:

```
/kingdoms/wonderland/databases/state/
```

All members of the wonderland community — who have bonds granting database access — can read/write the community state via their daemon connection. The DDP subscription scopes to the community namespace. A member's browser tab subscribes to `kingdoms://wonderland/databases/state` and gets real-time community state without polling.

The governance layer (proposals, votes, membership) is one collection in this database. The treasury ledger is another. The agent queues are a third. All in the same state machine, all served by the daemon, all accessible from bash to browser.

---

## 6. Device Unification

The daemon connects all devices owned by an entity:

```
thinker (laptop)   ─┐
flowbie (stream)   ─┤─ same daemon peer network ─ same DDP state
fourty4 (mac mini) ─┘
```

Because the daemon peers across machines (SPEC-014) and the state lives at a kingdoms path (not on a specific machine), any device connected to the ring sees the same state. A hook fired on thinker updates state that the browser on fourty4 reflects immediately. The device boundary disappears.

This is what Astro's dozen PWAs already demonstrate — DDP traffic combining into unified state. The spec generalizes it: not Astro's state, but the namespace's state, served by whatever daemon is authoritative for that namespace.

---

## 7. Current State vs. Target State

| Now | Target |
|-----|--------|
| Astro's MongoDB | `/kingdoms/<entity>/databases/state` |
| Astro's DDP endpoint | Daemon serves DDP per namespace |
| PWAs connect to Astro | PWAs connect to daemon at kingdoms path |
| No agent queues | Per-agent queues at kingdoms path |
| State owned by Astro | State owned by the namespace |
| Single-machine | Multi-device via daemon peer network |

Migration: Astro's existing state becomes `/kingdoms/astro/databases/state`. The PWAs that connected to Astro's DDP connect to the daemon's kingdoms endpoint instead. Identical protocol. New addressing.

---

## 8. Open Questions (Deferred)

1. **Authoritative daemon**: When a namespace spans multiple machines (via peer network), which daemon is authoritative for writes? Last-write-wins, or primary/replica?

2. **Offline behavior**: If the authoritative daemon is unreachable, can connected clients still read from a local cache? Write to a local queue that syncs on reconnect?

3. **Database size limits**: The kingdoms filesystem has a storage backend per entity (SPEC-029 §7). Large databases may need dedicated backends (separate MongoDB instance vs. embedded).

4. **Schema governance for community databases**: Who defines the schema for `/kingdoms/wonderland/databases/state`? The community's GOVERNANCE.md? A schema file in the namespace?

5. **Cross-namespace queries**: Can a process query across `/kingdoms/koad/databases/state` AND `/kingdoms/wonderland/databases/state` in one operation? (Probably: no. Each namespace is sovereign. Joins happen in application logic, not at the database layer.)

---

## 9. Proxy Cache — The Ring as a Time-Smeared Snapshot

The daemon is cache-heavy by design. Every operation it proxies — git pulls, issue fetches, project state queries — is cached with a timestamp. Over time, the cache builds a **ring-wide snapshot**: a composite view of all connected repos, issues, and project state, each data point labeled with when it was last seen.

### 9.1 The Smear

This is not a snapshot at time T. It is a **smear** — a composite across [T-24h, T-0] where each piece of data carries its own timestamp:

```
Ring snapshot — 2026-04-04 18:30 local
─────────────────────────────────────────
koad/juno       9 open issues   (2m ago)   ← just pulled
koad/vulcan    28 open issues   (3h ago)   ← pulled this morning
koad/veritas    1 open issue    (12m ago)  ← Veritas ran recently
koad/sibyl      1 open issue    (8h ago)   ← quiet
koad/aegis      2 open issues   (6h ago)   ← quiet
koad/mercury    1 open issue    (2d ago)   ← stale, flag it
─────────────────────────────────────────
```

The staleness is information. A repo that hasn't been touched in 2 days is probably quiet — or something is wrong. The dashboard renders both possibilities without hiding either. The operator sees the whole ring at a glance, with enough temporal context to know what to trust.

### 9.2 Passive Cache Population

The cache builds as a side effect of normal operation. No explicit "sync all" step. No scheduled full pull. The daemon intercepts:

- `git pull` → caches refs, branch state, recent commits
- `gh issue list` → caches issue state, assignees, labels
- `gh project` queries → caches project board state
- DDP subscriptions → real-time updates to any cached collection

Every time an entity does work that touches a repo, the daemon's cache for that repo refreshes. Frequently-touched repos stay fresh. Quiet repos go stale. The cache is an honest reflection of where the team's attention has been.

### 9.3 Git as Proxy

Git operations route through the daemon proxy:

```
git pull kingdoms://vulcan/repo
  → daemon checks cache age
  → if fresh (< TTL): return cached refs
  → if stale: proxy to upstream, update cache, return
```

This means `git clone kingdoms://koad/alice` doesn't hit GitHub directly — it hits the daemon, which either serves from cache or fetches and caches. The daemon becomes the local mirror for the ring. Offline operation works up to cache age. Bandwidth is reduced — only actual deltas flow past the daemon.

### 9.4 Dashboard: At-a-Glance Ring State

The portal (kingofalldata.com dashboard) renders the smear directly:

```
/kingdoms/<entity>/databases/state → ring_snapshot collection
```

Each document in `ring_snapshot`:
```json
{
  "repo": "koad/vulcan",
  "open_issues": 28,
  "last_commit": "hooks: inject PRIMER.md",
  "last_commit_age": "3h",
  "cached_at": "2026-04-04T15:30:00Z",
  "cache_age_display": "3h ago",
  "stale": false
}
```

The dashboard shows a row per repo. The `cached_at` is displayed prominently — the user always knows they're looking at a smear, not a live pull. A "refresh" button proxies fresh pulls for selected repos and updates the cache.

### 9.5 Smear Honesty

The UI never pretends the smear is a live view. Every data point shows its age. A 2-day-old issue count is displayed as "28 issues (2d ago)" — not "28 issues." The temporal honesty is a design constraint, not an aesthetic choice.

This is especially important for the ring at scale: with 50 connected repos, a full live pull is impractical on demand. The smear makes the ring browsable without the cost of a full sync. The operator sees enough to know where attention is needed and can pull selectively.

---

## 10. Multi-Device Storage: RAID-0 Across the Peer Network

The daemon peer network (SPEC-014) connects multiple machines. The kingdoms filesystem has a pluggable storage backend per namespace (SPEC-029 §7). These two facts combine into a third thing: **the connected devices form a logical storage pool.**

RAID-0: stripe across all connected devices. No redundancy — pure capacity and throughput. Your three machines aren't three separate installations; they're one kingdom with three drives.

```
thinker  (SSD, fast)    ─┐
flowbie  (large HDD)    ─┤── /kingdoms/koad/ striped across all three
fourty4  (NVMe, fast)   ─┘
```

The daemon coordinates the stripe. Reads go to whichever device has the block. Writes stripe across available devices. From any surface (bash hook, PWA, passenger), the namespace looks like one store — the device topology is invisible.

For community namespaces: member devices can contribute storage to the community pool. `/kingdoms/wonderland/databases/state` is striped across the storage backends of member daemons that have opted in. The community's total storage capacity is the sum of what members contribute.

This is deferred — RAID coordination is non-trivial. But the shape is correct: the daemon peer network already provides the connectivity; the storage backend abstraction (SPEC-029 §7) already provides the pluggability. RAID-0 is a backend implementation that sits between them.

---

*50k spec — the shape is right. Implement after SPEC-029 and SPEC-014 are stable. Do not let this block kingdoms filesystem work.*
