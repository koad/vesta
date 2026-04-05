---
status: canonical
id: VESTA-SPEC-045
title: "Daemon Dashboard Data Contract — DDP Subscriptions, HTTP Endpoints, PassengerJobs Collection"
type: spec
version: 1.0
date: 2026-04-05
owner: vesta
related-specs:
  - VESTA-SPEC-009-DAEMON (Daemon Specification — primary authority; this spec extends §8.3)
  - VESTA-SPEC-035 (Enriched PID Lock File — entity status source)
related-briefs:
  - ~/.muse/briefs/2026-04-05-daemon-dashboard.md
resolves:
  - Muse dashboard brief "Implementation Notes for Vulcan" — formalizes the data contracts
---

# VESTA-SPEC-045: Daemon Dashboard Data Contract

**Authority:** Vesta (platform stewardship). This spec defines the server-side data contracts the daemon must expose for the `/dashboard` route to function. It extends VESTA-SPEC-009-DAEMON §8.3 (`/api/health`) and introduces new DDP subscriptions and a `PassengerJobs` collection.

**Scope:** Four DDP subscriptions (`daemon.overview`, `entity.roster`, `entity.activity.feed`, `passenger.queue`), the extended `/health` HTTP endpoint for the dashboard's System Health section, and the `PassengerJobs` and `DaemonActivity` MongoDB collection schemas.

**Consumers:**
- Vulcan — implements the server-side publications and the `/dashboard` Meteor route
- Dashboard client — consumes these subscriptions; described in Muse brief (see `related-briefs`)
- Salus — may cross-consume `DaemonActivity` for anomaly detection

**Status:** Canonical. Derived from Muse brief 2026-04-05-daemon-dashboard.md. Cross-referenced against VESTA-SPEC-009-DAEMON §8.3. Vulcan can implement against this spec.

---

## 1. Relationship to VESTA-SPEC-009-DAEMON

VESTA-SPEC-009-DAEMON is the authoritative spec for the daemon. This spec **extends** it — it does not replace or conflict. Specifically:

- VESTA-SPEC-009 §8.3.1 defines `GET /api/health`. This spec extends that endpoint's response shape for dashboard consumption (§4 below).
- VESTA-SPEC-009 §4 defines worker state in MongoDB. This spec introduces `PassengerJobs` as the dashboard-facing surface of that state (§5).
- VESTA-SPEC-009 §2 defines `passenger.json`. This spec defines `entity.roster` as the live DDP projection of registered passengers with heartbeat status (§3.2).

If any conflict arises between this spec and VESTA-SPEC-009, VESTA-SPEC-009 governs. File a gap issue at `koad/vesta` to reconcile.

---

## 2. DDP Publication Overview

The dashboard requires four server-side Meteor publications. All are local-only (localhost:PORT/dashboard). No authentication gate — localhost access is the access control.

| Publication name | Collection | Purpose |
|-----------------|-----------|---------|
| `daemon.overview` | `DaemonOverview` (singleton) | Daemon identity, uptime, MongoDB status, DDP subscriber count, entity counts |
| `entity.roster` | `EntityRoster` | One document per registered entity: status, heartbeat, commit hash, lockfile |
| `entity.activity.feed` | `DaemonActivity` | Ordered activity feed of daemon-significant events |
| `passenger.queue` | `PassengerJobs` | Job queue state: queued, in-progress, completed (last 10), failed |

---

## 3. Publication Schemas

### 3.1 `daemon.overview` → `DaemonOverview` Collection

Singleton collection — always exactly one document. The dashboard subscribes and reads the one document.

**Collection:** `DaemonOverview`

**Schema:**

```javascript
{
  _id: "singleton",                           // fixed ID — there is always exactly one document
  daemon_version: "0.9.2",                    // from package.json or KOAD_IO_VERSION
  pid: 48291,                                 // process.pid
  started_at: ISODate("2026-04-05T10:14:38Z"), // daemon process start time
  hostname: "thinker",                         // os.hostname()
  mongodb: {
    status: "connected",                       // "connected" | "disconnected"
    url: "mongodb://localhost:27017",          // from daemon env
    mode: "spawned"                            // "spawned" | "external"
  },
  ddp: {
    status: "live",                            // "live" | "offline"
    subscriber_count: 12                       // current DDP subscriber count (Meteor.server.sessions)
  },
  entities: {
    total: 7,
    online: 4,
    idle: 1,
    locked: 1,
    offline: 1
  }
}
```

**Update frequency:** The daemon server updates this document in a `Meteor.setInterval` every 5 seconds. DDP reactivity propagates the delta to subscribers immediately.

**Entity count derivation:**
- `online` = `entity.roster` documents where `status === "active"`
- `idle` = `entity.roster` documents where `status === "idle"`
- `locked` = `entity.roster` documents where `status === "locked"` (lockfile exists)
- `offline` = `entity.roster` documents where `status === "offline"`
- `total` = all registered entities

### 3.2 `entity.roster` → `EntityRoster` Collection

One document per registered entity. Populated from `passenger.json` discovery (VESTA-SPEC-009 §2.4) plus live heartbeat and lockfile checks.

**Collection:** `EntityRoster`

**Schema:**

```javascript
{
  _id: "juno",                                // entity handle (from passenger.json)
  name: "Juno",                              // display name
  role: "coordinator",                        // role from passenger.json
  entity_dir: "/home/koad/.juno",            // resolved entity directory
  status: "active",                          // "active" | "idle" | "locked" | "offline"
  last_heartbeat_at: ISODate("..."),         // last time daemon detected activity
  heartbeat_age_seconds: 12,                 // derived: now - last_heartbeat_at
  commit_hash: "7d95c39",                    // last 7-char git hash (see §3.2.1)
  lockfile: null,                            // null if none; filename string if present
  pid: 91244,                               // process PID if running (null if offline)
  trust_bond: {
    from: "koad",
    to: "juno",
    type: "authorized-agent",
    verified: true
  },
  passenger_registered: true                 // whether entity has passenger.json and is registered
}
```

**Status derivation (from Muse brief Implementation Notes):**

| Status | Condition |
|--------|-----------|
| `active` | Heartbeat within last 5 minutes AND no lockfile |
| `idle` | Heartbeat 5–30 minutes ago AND no lockfile |
| `offline` | No heartbeat OR heartbeat >30 minutes ago |
| `locked` | Lockfile exists in `entity_dir` — regardless of heartbeat age |

`locked` takes precedence over all other status values. If a lockfile exists, status is `locked`.

#### 3.2.1 Commit Hash Resolution

The daemon resolves each entity's last commit hash by running:
```
git -C {entity_dir} log --format="%h" -1
```

This is run on a **60-second TTL cache per entity** — not on every DDP refresh. The cache avoids blocking git processes on every subscription update. When the cache entry is missing or expired, the daemon schedules an async resolution. The dashboard renders `—` (em dash) while a hash is pending.

**Vulcan implementation note:** Run commit hash resolution in a Fiber or `async/await` wrapper — do not block the DDP publication on git subprocess calls.

#### 3.2.2 Heartbeat Source

The daemon tracks heartbeat via the entity's PID lock file (`{entity_dir}/{entity}.lock`). When a lockfile exists, the daemon reads its `mtime` as the last heartbeat. If no lockfile: the daemon falls back to the last `DaemonActivity` document for the entity (any event from the entity counts as a heartbeat signal).

Heartbeat is not a push protocol — entities do not call a heartbeat endpoint. The daemon infers it from observable signals.

### 3.3 `entity.activity.feed` → `DaemonActivity` Collection

Live event log. The dashboard's right-rail Activity Feed subscribes to this.

**Collection:** `DaemonActivity`

**Schema:**

```javascript
{
  _id: ObjectId(),                           // auto-generated
  timestamp: ISODate("2026-04-05T14:24:00Z"), // event time
  entity: "juno",                            // entity handle
  action: "committed",                       // see action vocabulary below
  reference: "~/.juno",                     // repo, file path, or issue reference
  detail: "de471ae  docs: correct Alice PR status", // optional second line (44-char truncate in UI)
  metadata: {                               // optional; action-specific structured data
    commit_hash: "de471ae",
    commit_message: "docs: correct Alice PR status"
  }
}
```

**Action vocabulary** (from Muse brief):

| `action` value | Meaning |
|---------------|---------|
| `committed` | Entity committed to a git repo |
| `closed` | Entity closed a GitHub issue or PR |
| `opened` | Entity opened a GitHub issue or PR |
| `pushed` | Entity pushed to a remote |
| `commented` | Entity commented on a GitHub issue/PR |
| `spawned` | Entity was spawned (process started) |
| `blocked` | Entity reported a blocked state |
| `merged` | Entity's PR was merged |
| `hook_fired` | Daemon fired a hook to this entity |
| `worker_completed` | A PassengerJob completed for this entity |
| `worker_failed` | A PassengerJob failed for this entity |

**Publication parameters:** `entity.activity.feed` accepts an optional `{ limit: N }` argument. Default: 50 documents, sorted by `timestamp` descending. Client can request older events via `{ limit: N, before: timestamp }`.

**Emission:** Daemon server code emits `DaemonActivity` documents on each significant event. Individual entities do not write to this collection directly. The daemon observes entity-facing events (git pushes, GitHub webhook callbacks, hook invocations, worker completions) and writes the document. This keeps the collection authoritative and prevents entity misbehavior from polluting the feed.

### 3.4 `passenger.queue` → `PassengerJobs` Collection

Worker job queue. The dashboard's Passenger Queue section subscribes to this.

**Collection:** `PassengerJobs`

**Schema:**

```javascript
{
  _id: ObjectId(),
  entity: "vulcan",                          // entity handle the job is for
  type: "build",                             // "build" | "task" | "hook" | "research"
  description: "compile alice-curriculum v2", // human-readable, 60-char max
  status: "queued",                          // see status values below
  submitted_at: ISODate("..."),              // when job entered the queue
  started_at: ISODate("..."),                // null if not yet started
  completed_at: ISODate("..."),              // null if not complete
  elapsed_ms: null,                          // null while running; set on complete/fail
  error: null,                               // null if no error; string error message on fail
  issue_ref: "koad/vulcan#48"               // optional GitHub issue this job relates to
}
```

**Status values:**

| Status | Meaning |
|--------|---------|
| `queued` | Submitted but not yet started |
| `in_progress` | Currently running |
| `completed` | Finished successfully |
| `failed` | Finished with error |

**Publication scope:** The `passenger.queue` publication returns:
- All documents with `status: "queued"` or `status: "in_progress"` (no limit)
- Last 10 documents with `status: "completed"` (sorted by `completed_at` desc)
- All documents with `status: "failed"` (no limit — operator should see all failures)

**Relationship to VESTA-SPEC-009 workers:** `PassengerJobs` is the dashboard-facing surface of the daemon's worker system (VESTA-SPEC-009 §4). The daemon's internal worker system uses its own MongoDB collection structure. `PassengerJobs` is a separate, simplified collection maintained by the daemon for UI consumption. The daemon writes `PassengerJobs` documents when:
- A job is submitted (status: `queued`)
- A worker picks it up (status: `in_progress`, `started_at` set)
- A worker completes it (status: `completed` or `failed`, timing fields set)

Vulcan may choose to derive `PassengerJobs` from the existing worker collection instead of maintaining a separate collection. Either approach is acceptable as long as the dashboard can subscribe to `passenger.queue` and receive documents matching the schema above.

---

## 4. Extended `/health` HTTP Endpoint

VESTA-SPEC-009 §8.3.1 defines `GET /api/health`. The dashboard's System Health section consumes a superset of that response. This section defines the extended shape.

**Endpoint:** `GET /health` (note: dashboard uses `/health` not `/api/health` — both should resolve; the daemon may alias)

**Extended response (superset of VESTA-SPEC-009 §8.3.1):**

```json
{
  "status": "healthy | degraded | unhealthy",
  "uptime_seconds": 15132,
  "daemon_version": "0.9.2",
  "pid": 48291,
  "started_at": "2026-04-05T10:14:38Z",
  "hostname": "thinker",

  "mongodb": {
    "status": "connected",
    "collections": 12,
    "documents": 48291,
    "data_size_bytes": 25269248,
    "index_size_bytes": 4404224,
    "connections_active": 3
  },

  "ddp": {
    "status": "live",
    "subscriber_count": 12,
    "message_rate_per_second": 4.2,
    "latency_ms_avg": 8
  },

  "process": {
    "memory_rss_bytes": 155189248,
    "cpu_percent": 2.1,
    "node_version": "v20.11.0"
  },

  "workers": {
    "total": 11,
    "healthy": 9,
    "failed": 2
  }
}
```

**New fields vs VESTA-SPEC-009:**

| Field | Source | Notes |
|-------|--------|-------|
| `mongodb.collections` | `db.stats().collections` | |
| `mongodb.documents` | `db.stats().objects` | |
| `mongodb.data_size_bytes` | `db.stats().dataSize` | |
| `mongodb.index_size_bytes` | `db.stats().indexSize` | |
| `mongodb.connections_active` | `db.serverStatus().connections.current` | |
| `ddp.message_rate_per_second` | Rolling 10s window | Derived from DDP message counter |
| `ddp.latency_ms_avg` | Meteor DDP ping/pong | Average of last 10 pings |
| `process.memory_rss_bytes` | `process.memoryUsage().rss` | |
| `process.cpu_percent` | `process.cpuUsage()` rolling | Updated every 2s |
| `process.node_version` | `process.version` | |

**Refresh:** The dashboard polls `/health` every 10 seconds via `Meteor.setInterval`. This is appropriate for dashboard use. Salus continues to use `/api/health` at its own polling rate (VESTA-SPEC-009 §8.3.2).

**Error state:** If `/health` returns a non-200 response or network error, the System Health section renders: `✗ /health unreachable — metrics unavailable` (per Muse brief).

---

## 5. Implementation Checklist for Vulcan

The following items are required to ship the daemon dashboard:

- [ ] Introduce `DaemonOverview` collection; update on 5s interval
- [ ] Introduce `EntityRoster` collection; populate from `passenger.json` discovery + heartbeat logic
- [ ] Introduce `DaemonActivity` collection; emit documents on significant daemon events
- [ ] Introduce `PassengerJobs` collection; maintain from existing worker state
- [ ] Publish `daemon.overview`, `entity.roster`, `entity.activity.feed`, `passenger.queue` as Meteor publications
- [ ] Extend `/health` response with new fields defined in §4
- [ ] Mount `/dashboard` as a Meteor route (FlowRouter or iron:router per existing daemon routing)
- [ ] Implement commit hash resolution with 60s TTL cache (async, non-blocking)
- [ ] Implement heartbeat status derivation from lockfile mtime and activity feed

**Meteor package note:** All DDP publications must be in `Meteor.publish` on the server. The dashboard client subscribes via `Meteor.subscribe`. Use `ReactiveVar` or `Tracker` for client-side reactivity in the existing daemon Meteor codebase.

---

## 6. What This Spec Does Not Cover

- The dashboard UI implementation — see Muse brief `2026-04-05-daemon-dashboard.md`
- Authentication or authorization for the dashboard — not required (localhost only)
- The Stream PWA activity feed — the Stream PWA uses separate DDP subscriptions and is a different surface
- Multi-machine dashboard federation — the dashboard is local to one daemon instance
