---
status: draft
id: VESTA-SPEC-009-DAEMON
title: "Daemon Specification — Passenger Registry, Worker System, Lifecycle, Dark Passenger Integration"
type: spec
version: 1.0
date: 2026-04-03
owner: vesta
related-issues:
  - koad/vesta#17
  - koad/vulcan#22
related-specs:
  - VESTA-SPEC-001 (Entity Model)
  - VESTA-SPEC-005 (Cascade Environment)
  - VESTA-SPEC-009 (Hooks Catalog)
---

# VESTA-SPEC-009-DAEMON: Daemon Specification

**Authority:** Vesta (platform stewardship). This spec defines the daemon system that runs on each koad:io machine, managing entity workers, passenger registration, and Dark Passenger browser extension integration.

**Scope:** Daemon initialization, `passenger.json` schema, worker lifecycle, Dark Passenger protocol, multi-machine topology via ZeroTier, entity isolation, and health indicators for Salus monitoring.

**Consumers:** 
- Vulcan (worker firing system, daemon deployment)
- Salus (health diagnosis, daemon healing)
- Juno (entity orchestration)
- Entities (passive consumers of daemon services)

**Status:** Draft. Completes daemon implementation spec; pending Vulcan/Salus review before canonical promotion.

---

## 1. Daemon Architecture Overview

### 1.1 Design Principles

1. **One daemon per machine:** A single daemon process runs on each machine (thinker, dotsh, flowbie, fourty4) as a system service or foreground process
2. **Entity-passive:** Entities do not start the daemon; the daemon is started by system (systemd, supervisor, or user shell session)
3. **Passenger-aware:** Daemon discovers and registers all entities with `passenger.json` (these are "passengers" that can be selected in Dark Passenger browser extension)
4. **Worker-centric:** The daemon's primary job is scheduling and executing workers (Meteor-based scheduled tasks)
5. **Hook-responsive:** Daemon fires lifecycle hooks to notify entities of startup, shutdown, DDP connections, and Passenger events
6. **Health-observable:** All worker state is stored in MongoDB for Salus and other diagnostics to consume

### 1.2 Daemon Process Lifecycle

```
1. Start: daemon process invoked (systemd, user shell, or supervisor)
2. Init: Load .env, read ZeroTier config, initialize MongoDB connection
3. Upstart: Fire entity-upstart hook for all entities
4. Startup: Load Meteor startup sequences, register passengers
5. DDP: Establish DDP connection to Meteor on localhost:28282
6. Connected: Fire daemon-connected hook for all entities
7. Run: Start all workers, listen for Dark Passenger messages
8. Monitor: Health checks every 60s, retry failed workers
9. Shutdown: Fire entity-shutdown hook, graceful worker termination
```

---

## 2. `passenger.json` Schema

Entities declare themselves as "passengers" by creating `ENTITY_DIR/passenger.json`. The daemon auto-discovers and registers these at startup.

### 2.1 Required Fields

```json
{
  "handle": "string (lowercase, alphanumeric, no spaces)",
  "name": "string (display name)",
  "role": "string (functional role: architect, builder, healer, etc.)"
}
```

| Field | Type | Required | Example | Purpose |
|-------|------|----------|---------|---------|
| `handle` | string | **Yes** | `vesta` | Unique entity identifier; matches directory name (without leading `.`) |
| `name` | string | **Yes** | `Vesta` | Display name shown in Dark Passenger UI |
| `role` | string | **Yes** | `architect` | Entity's functional role; affects UI presentation |

**Validation Rules:**
- `handle`: Must match regex `^[a-z0-9-]+$` (lowercase, digits, dashes only)
- `name`: Must be non-empty; max 64 characters
- `role`: One of: `architect`, `builder`, `guardian`, `healer`, `observer`, `coordinator`, `researcher`, `messenger`
- File must be valid JSON; malformed files are logged but do not crash daemon

### 2.2 Optional Fields

```json
{
  "avatar": "string (path to image or data URI)",
  "outfit": "string (color name for UI theming)",
  "buttons": [
    {
      "label": "string (button label)",
      "action": "string (handler function or command)",
      "description": "string (tooltip text)"
    }
  ],
  "status": "string (active | paused | dormant)"
}
```

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `avatar` | path or data URI | `null` | Image file path or base64 data URL; daemon embeds as data URI |
| `outfit` | string | auto-generated | Color name (e.g., "red", "blue") for UI theming; if not set, daemon computes hash of handle |
| `buttons` | array | `[]` | Custom action buttons shown in Dark Passenger UI |
| `status` | string | `active` | Passenger operational status; affects UI presentation |

### 2.3 Buttons Array Structure

Each button object:

```json
{
  "label": "string",
  "action": "string (command or function name)",
  "description": "string (optional tooltip)"
}
```

- `label`: Button text (max 20 characters)
- `action`: Handler function name or command to invoke when clicked
  - If matches a hook name (`specs`, `gap`, `reconcile`), daemon looks for hook
  - Otherwise treated as command name (invokes `entity <action>`)
- `description`: Tooltip shown on hover

**Example:**

```json
{
  "handle": "vesta",
  "name": "Vesta",
  "role": "architect",
  "avatar": "avatar.png",
  "outfit": "purple",
  "buttons": [
    { "label": "Specs", "action": "specs", "description": "View active specs" },
    { "label": "Gap", "action": "gap", "description": "File a structural gap" },
    { "label": "Reconcile", "action": "reconcile", "description": "Reconcile spec vs reality" }
  ],
  "status": "active"
}
```

### 2.4 Daemon Processing of `passenger.json`

**Discovery:** At startup and at 60-second refresh intervals, daemon:
1. Scans `$HOME/.*` directories (entities are dot-folders)
2. Reads `.env` from each to find `KOAD_IO_VERSION` (koad:io marker)
3. Looks for `passenger.json` in directories with valid `.env`
4. Reads and parses `passenger.json`

**Avatar Embedding:**
- If `avatar` field is a file path (not already data URI), daemon:
  1. Attempts to read file as image (PNG, JPEG, SVG)
  2. Converts to base64
  3. Replaces field with data URI: `data:image/png;base64,...`
  4. Stores in MongoDB so it doesn't need re-embedding on each request

**Registration:**
- Inserts/updates document in MongoDB `Passengers` collection:
  ```javascript
  {
    handle: "vesta",
    name: "Vesta",
    role: "architect",
    image: "data:image/png;base64,...",
    outfit: "purple",
    buttons: [ /* ... */ ],
    status: "active",
    _lastUpdated: <timestamp>
  }
  ```

**Deletion:**
- If `passenger.json` is deleted or `.env` no longer exists, daemon removes from collection

---

## 3. Daemon Startup Sequence

The daemon follows this initialization order when started:

### 3.1 Pre-Flight (first 5 seconds)

```
1. Read DAEMON_PID from startup arguments or /proc/self
2. Load .env from daemon config location (~/.koad-io/.env, /etc/koad-io/.env, or $KOAD_IO_ENV)
3. Source cascade environment (see VESTA-SPEC-005)
4. Initialize daemon logging (output to ~/.koad-io/logs/daemon.log)
5. Log: "Daemon starting PID=<pid> at <timestamp>"
6. Verify ZeroTier network membership (if configured)
```

**Required env vars for daemon:**
- `DAEMON_PID`: Current process ID
- `DAEMON_VERSION`: Daemon version (e.g., "1.0.0")
- `KOAD_IO_BIND_IP`: Bind address for services (default: `127.0.0.1`)
- `ZEROTIER_NETWORK_ID`: (optional) ZeroTier network to join for this machine

**Env vars available to hooks and workers:**
- All vars from cascade environment (see VESTA-SPEC-005)
- `DAEMON_UPSTART_TIME`: ISO 8601 timestamp when daemon started
- `DAEMON_LISTEN_PORT`: Port daemon listens on for DDP (default: 28282)

### 3.2 Core Initialization (5-15 seconds)

```
1. Verify MongoDB is accessible
   - If not running: attempt to auto-start (if KOAD_IO_AUTO_SPAWN_MONGO=1)
   - If still unavailable: log warning, continue (workers will fail, but daemon runs)

2. Initialize DDP Server (Meteor)
   - Start on localhost:28282 (configurable via DAEMON_LISTEN_PORT)
   - Create collections: Passengers, Workers, DDP_Sessions
   - Register RPC methods: passenger.check-in, worker.heartbeat, worker.register

3. Initialize ZeroTier (if ZEROTIER_NETWORK_ID is set)
   - Join network: zerotier-cli join <ZEROTIER_NETWORK_ID>
   - Confirm membership established
   - Log: "Joined ZeroTier network <id> with IP <ip>"

4. Load Passport Registry
   - Scan all entity directories (~/.*)
   - Load passenger.json from each (embed avatars)
   - Insert/update into Passengers collection
   - Log count: "Registered <N> passengers"
```

### 3.3 Hook Firing (15-20 seconds)

```
1. Fire entity-upstart hook for all entities
   - Execute ~/.entity/hooks/entity-upstart.sh (if exists)
   - Pass: DAEMON_PID, DAEMON_VERSION, DAEMON_UPSTART_TIME
   - Timeout: 30 seconds per entity
   - Log failures but continue (don't block startup)

2. Emit Meteor startup event
   - Trigger Meteor.startup() callbacks
   - Any workers defined in Meteor.startup() begin initialization
```

### 3.4 Connection Phase (20-30 seconds)

```
1. Fire daemon-connected hook for all entities
   - Execute ~/.entity/hooks/daemon-connected.sh (if exists)
   - Pass: DDP_HOST, DDP_PORT, DDP_SESSION_ID, CONNECTED_AT
   - Log: "Connected to Meteor DDP"

2. Set daemon status: READY
   - Worker registration can begin
   - Worker task execution begins
```

**Full startup log example:**

```
[2026-04-03T10:15:30Z] Daemon starting PID=1234 version=1.0.2
[2026-04-03T10:15:32Z] Environment loaded: KOAD_IO_VERSION=1.0.0, ZEROTIER_NETWORK_ID=eed6c8cfe0a08a8d
[2026-04-03T10:15:34Z] MongoDB connected: mongodb://localhost:27017/koad-io
[2026-04-03T10:15:36Z] DDP server listening on 127.0.0.1:28282
[2026-04-03T10:15:38Z] Joined ZeroTier network eed6c8cfe0a08a8d with IP 172.28.106.217
[2026-04-03T10:15:40Z] Registered 8 passengers: vesta, vulcan, salus, argus, juno, sibyl, muse, aegis
[2026-04-03T10:15:42Z] entity-upstart hooks fired for 8 entities
[2026-04-03T10:15:44Z] Meteor startup complete
[2026-04-03T10:15:46Z] daemon-connected hooks fired for 8 entities
[2026-04-03T10:15:48Z] Daemon READY (uptime: 18 seconds)
```

---

## 4. Worker System Specification

Workers are scheduled, persistent tasks executed by the daemon. They are powered by the `koad:io-worker-processes` Meteor package.

### 4.1 Worker Definition & Registration

Workers are registered via `koad.workers.start()` in Meteor startup code:

```javascript
// In ~/.entity/startup-workers.js or similar
Meteor.startup(async () => {
  await koad.workers.start({
    service: 'my-service',      // Unique identifier
    interval: 60,               // Run every 60 minutes
    delay: 1,                   // Start 1 minute after interval boundary
    runImmediately: false,      // Don't run on startup
    task: async () => {
      // Worker task logic
      console.log('[MY-SERVICE] Running...');
      const result = await doWork();
      return result;
    }
  });
});
```

### 4.2 Worker Configuration Schema

| Parameter | Type | Required | Range | Purpose |
|-----------|------|----------|-------|---------|
| `service` | string | **Yes** | unique | Identifier for this worker; must be unique across all workers |
| `interval` | number | **Yes** | 1-1440 | Execution interval in minutes (1 minute to 24 hours) |
| `delay` | number | No | 0-N | Delay in minutes after interval boundary before first execution |
| `task` | async function | **Yes** | N/A | Async function to execute; receives no arguments; must handle errors |
| `runImmediately` | boolean | No | default: false | If true, run task once on registration; don't wait for interval |
| `type` | string | No | enum | Worker type: `cron`, `event`, `hook`, or `manual`; determines execution model |
| `maxAttempts` | number | No | 1-3 | Max retry attempts on failure (default: 3) |
| `timeout` | number | No | 1000+ | Task timeout in milliseconds (default: 300000 = 5 min) |
| `concurrency` | string | No | enum | Concurrency model: `no-parallel` (default) or `allow-parallel` |

**Returns:** Worker registration object:
```javascript
{
  workerId: "<auto-generated UUID>",
  service: "my-service",
  interval: 60,
  stop: async () => { /* unregister */ }
}
```

### 4.2.1 Worker Type Enumeration

Valid values for `type` field:

| Type | Description | Execution Model | Use Cases |
|------|-------------|-----------------|-----------|
| `cron` | Time-based scheduled task | Executes on fixed interval (e.g., hourly, daily) | Cleanup jobs, cache refresh, periodic reporting |
| `event` | Event-driven task | Executes when specific event fires in entity system | Webhook handlers, real-time processors, reactive tasks |
| `hook` | Lifecycle hook task | Executes in response to daemon or entity lifecycle events (startup, shutdown, etc.) | Initialization, cleanup, synchronization |
| `manual` | User-triggered task | Executes only when explicitly invoked by user or external caller | Admin actions, diagnostics, recovery procedures |

**Default:** If `type` is not specified, defaults to `cron`.

### 4.2.2 Concurrency Model

The `concurrency` field determines how the daemon handles overlapping task executions:

| Model | Behavior | When Next Execution Fires |
|-------|----------|--------------------------|
| `no-parallel` (default) | If a worker task is already running, skip the scheduled execution. Log a `skipped` event with reason. | When current execution completes, next execution is scheduled from current time + interval |
| `allow-parallel` | Allow multiple instances of the same worker to run concurrently. | All scheduled executions fire, even if previous is still running |

**Default:** `no-parallel`. This prevents queue buildup and avoids duplicate work if a task runs longer than its interval.

**Example: Skip Detection**

Worker configured with:
```javascript
{
  service: "cleanup",
  interval: 5,        // Run every 5 minutes
  timeout: 600000,    // 10 minute timeout (longer than interval!)
  concurrency: "no-parallel"
}
```

Timeline:
```
10:00:00 - Task starts (will take ~8 minutes)
10:05:00 - Next execution scheduled
  → But task still running from 10:00:00
  → Daemon logs: 'skipped' event with reason="worker-already-running"
  → No execution happens
10:08:00 - Task completes
  → Next execution recalculated: 10:08:00 + 5 min = 10:13:00
10:13:00 - Task runs again
```

Skipped events are logged to the worker document with timestamp and reason, visible to Salus monitoring.

### 4.3 Worker Collection Document Structure

When registered, worker creates a MongoDB document in `workers` collection:

```javascript
{
  _id: ObjectId,
  service: "my-service",
  host: "thinker",                    // Machine hostname
  pid: 1234,                          // Daemon process ID
  instanceId: "inst-abc123def456",    // Current Meteor instance (changes on reload)
  workerId: "worker-uuid-here",
  
  // Configuration
  interval: 60,                       // Minutes
  delay: 1,
  type: "cleanup",
  maxAttempts: 3,
  timeout: 300000,
  
  // State
  state: "running",                   // starting|running|stopped|error
  enabled: true,
  insane: false,                      // Marked failed after max retries
  
  // Health & History
  lastHeartbeat: ISODate("2026-04-03T10:45:00Z"),
  asof: ISODate("2026-04-03T10:45:00Z"),
  nextExecution: ISODate("2026-04-03T11:45:00Z"),
  lastExecution: ISODate("2026-04-03T10:00:00Z"),
  lastExecutionDuration: 1234,        // Milliseconds
  successCount: 45,
  errorCount: 2,
  
  // Error Tracking
  errors: [
    {
      timestamp: ISODate("2026-04-03T08:15:00Z"),
      message: "Task timeout after 5 minutes",
      stack: "...",
      attempt: 1
    }
  ],
  
  // Metadata
  createdAt: ISODate("2026-04-02T14:30:00Z"),
  updatedAt: ISODate("2026-04-03T10:45:00Z")
}
```

**Key fields for health monitoring (Salus):**
- `state`: Current state of worker
- `insane`: If true, worker has failed max attempts; needs manual intervention
- `lastHeartbeat`: When worker last reported alive
- `errorCount`: How many times worker has failed
- `errors[]`: Full error history with stack traces
- `nextExecution`: Predicted next run time

### 4.4 Worker Lifecycle

```
1. Register: Entity calls koad.workers.start()
   → Document created in MongoDB
   → Worker state = "starting"

2. Schedule: Daemon calculates next execution time
   → nextExecution = now + delay + interval
   → Worker state = "running"

3. Execute: At scheduled time, daemon invokes task()
   → Captures start time, duration, success/failure
   → Updates lastExecution, lastHeartbeat

4. Retry: If task fails, daemon retries with exponential backoff
   → Attempt 1: immediate
   → Attempt 2: 1 second delay
   → Attempt 3: 4 second delay
   → If all fail: mark as "insane" (errorCount++)

5. Monitor: Every 60 seconds, daemon checks health
   → stale worker? (no heartbeat for 5+ minutes) → log warning
   → insane worker? (errorCount >= maxAttempts) → alert Salus
   → missing worker? (registered but not alive) → attempt restart

6. Stop: Entity calls worker.stop()
   → Worker state = "stopped"
   → No future executions scheduled
   → Document remains in MongoDB (for history)

7. Unload: If entity is unloaded (Meteor reload), worker survives
   → instanceId changes when daemon reloads
   → New instance queries MongoDB for "my" workers
   → Resumes execution with new instanceId
```

### 4.5 Worker Health Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `MIN_INTERVAL_MINUTES` | 1 | Minimum task interval |
| `MAX_INTERVAL_MINUTES` | 1440 | Maximum task interval (24 hours) |
| `MAX_RETRY_ATTEMPTS` | 3 | Retry attempts before marking insane |
| `RETRY_BACKOFF_BASE_MS` | 1000 | Initial backoff delay (1 second) |
| `RETRY_BACKOFF_EXPONENT` | 2 | Exponential backoff multiplier |
| `HEALTH_CHECK_INTERVAL_MS` | 60000 | Daemon health check interval (60 seconds) |
| `STALE_WORKER_THRESHOLD_MS` | 300000 | Worker stale after 5 minutes no heartbeat |
| `DEFAULT_TASK_TIMEOUT_MS` | 300000 | Default task timeout (5 minutes) |

### 4.6 Error Handling for Workers

**Task exceptions:**
- If task throws error, worker catches it, logs to document, increments errorCount
- If errorCount < maxAttempts: retry with backoff
- If errorCount >= maxAttempts: mark insane, alert Salus

**Task timeout:**
- If task doesn't complete within timeout, worker forces termination
- Logged as timeout error in `errors[]` array
- Counts as single retry attempt

**Stale detection:**
- If worker hasn't reported heartbeat for 5 minutes, daemon marks as stale
- Salus monitoring receives alert
- Daemon may attempt to restart worker

---

## 5. Dark Passenger Browser Extension Protocol

Dark Passenger is a browser extension running on the user's machine that connects to the daemon for entity/passenger interaction.

### 5.1 Discovery & Connection

**Extension startup:**

1. Extension loads configuration from `~/.koad-io/passenger-config.json`:
   ```json
   {
     "daemon_host": "127.0.0.1",
     "daemon_port": 28282,
     "auto_connect": true,
     "reconnect_interval": 5000
   }
   ```

2. Extension connects to daemon via DDP at `ws://127.0.0.1:28282`
   - Uses Meteor DDP protocol (WebSocket-based)
   - Authenticates with browser session token (or anonymous if no auth)

3. On connection, extension subscribes to:
   - `passengers` collection (list of active passengers)
   - `passenger.events` channel (for real-time updates)

### 5.2 Message Protocol

All Dark Passenger events are DDP method calls. Format:

```javascript
Meteor.call('passenger.method-name', { args }, (err, result) => {
  if (err) console.error(err);
  else console.log(result);
});
```

#### 5.2.1 `passenger.select(handle)`

**When:** User clicks a passenger in the extension UI  
**Arguments:** `handle` (string) — passenger handle  
**Expected result:** `{ success: true, previousHandle: "..." }`

**Daemon action:**
1. Update `currentPassenger` in DDP session state
2. Fire `passenger-selected` hook for new passenger entity
3. Fire `passenger-deselected` hook for previous passenger entity (if any)

**Hook environment:**
```bash
ENTITY=<new-handle>
ENTITY_DIR=/home/koad/.<new-handle>
SELECTED_AT=<ISO timestamp>
PREVIOUS_PASSENGER=<old-handle>
```

#### 5.2.2 `passenger.url-received(url, title, domain)`

**When:** User sends a URL from browser to the daemon  
**Arguments:**
- `url` (string) — full URL
- `title` (string) — page title from `<title>` tag  
- `domain` (string) — extracted domain  

**Expected result:** `{ received: true, passengerId: "..." }`

**Daemon action:**
1. Fire `passenger-url-received` hook for current passenger entity
2. Log URL to `~/.koad-io/logs/passenger-urls.log`

**Hook environment:**
```bash
ENTITY=<current-passenger>
ENTITY_DIR=/home/koad/.<current-passenger>
PASSENGER_URL=<full-url>
PASSENGER_TITLE=<page-title>
PASSENGER_DOMAIN=<extracted-domain>
PASSENGER_RECEIVED_AT=<ISO timestamp>
BROWSER_CONTEXT=<browser-name>:<tab-id>
```

#### 5.2.3 `passenger.identity-request(requestId)`

**When:** Extension needs to identify the current user  
**Arguments:** `requestId` (string) — unique ID for correlation  
**Expected result:** Identity object (from hook or default)

**Daemon action:**
1. Fire `passenger-identity-request` hook for current passenger
2. Expect hook to output JSON with identity
3. If hook doesn't respond or outputs invalid JSON, return default

**Hook output (to stdout):**
```json
{
  "request_id": "<matching requestId>",
  "identity": "koad",
  "entity": "vesta",
  "verified": true,
  "expires": "2026-04-03T12:00:00Z"
}
```

**Default response (if hook absent):**
```json
{
  "verified": false,
  "identity": "unknown"
}
```

#### 5.2.4 `passenger.button-click(handle, action)`

**When:** User clicks a custom button in the extension  
**Arguments:**
- `handle` (string) — passenger handle
- `action` (string) — action name from button config  

**Expected result:** `{ executed: true }`

**Daemon action:**
1. Determine what `action` means:
   - If it matches a hook name: invoke hook
   - Otherwise: invoke `entity <action>` command

2. Execute asynchronously (don't wait for result)

3. Result is logged; may trigger further hooks

---

## 6. Multi-Machine Topology via ZeroTier

The daemon supports distributed operation across multiple machines (thinker, dotsh, flowbie, fourty4) via ZeroTier virtual networking.

### 6.1 Machine Configuration

Each machine has a daemon that may be on a different ZeroTier network:

| Machine | Role | ZeroTier Network | Daemon Host |
|---------|------|------------------|-------------|
| thinker | Primary workstation | `eed6c8cfe0a08a8d` | 172.28.106.1 |
| dotsh | Secondary compute | `eed6c8cfe0a08a8d` | 172.28.106.5 |
| flowbie | Mobile device | `eed6c8cfe0a08a8d` | 172.28.106.10 (dynamic) |
| fourty4 | Testing rig | `eed6c8cfe0a08a8d` | 172.28.106.20 |

**All machines share the same ZeroTier network** for inter-daemon communication.

### 6.2 Network Setup

Before daemon starts, ZeroTier must be installed and configured:

```bash
# Install ZeroTier
curl https://install.zerotier.com | bash

# Join network
sudo zerotier-cli join eed6c8cfe0a08a8d

# Wait for authorization (done via ZeroTier Central or CLI)
zerotier-cli status

# Daemon reads ZEROTIER_NETWORK_ID from .env
ZEROTIER_NETWORK_ID=eed6c8cfe0a08a8d
```

**Daemon validates at startup:**
1. Checks if ZeroTier is running
2. Confirms machine is a member of configured network
3. Obtains assigned IP address
4. Logs network membership

### 6.3 Inter-Daemon Communication

Daemons on different machines can communicate:

**Use case 1: Worker delegation**
- Daemon on thinker could invoke a remote worker on dotsh
- Via DDP method call across ZeroTier network

**Use case 2: Passenger discovery**
- Extension on thinker connects to daemon on thinker
- But could query passengers registered on dotsh daemon
- Via inter-daemon RPC call

**Current implementation:** Simple, machine-local
- Each machine's daemon manages only its local entities
- No cross-machine worker delegation (possible future enhancement)

---

## 7. Entity Isolation Model

### 7.1 Why One Daemon Per Machine (Not Per Entity)

**Single daemon per machine** (not one per entity):
- **Simpler:** One DDP server, one ZeroTier membership, one MongoDB connection
- **Efficient:** Shared infrastructure (MongoDB, ZeroTier) reduces footprint
- **Observable:** Single daemon process to monitor; clear startup/shutdown

**All entities on that machine share the daemon:**
- One daemon on thinker manages vesta, vulcan, salus, juno, etc.
- One daemon on dotsh manages a subset of entities

### 7.2 Isolation Mechanisms

**Hook isolation:**
- Each entity's hooks run in its own environment with entity-specific vars
- Entity A's hook cannot affect Entity B's hooks
- Hooks timeout individually; one timeout doesn't crash daemon

**Worker isolation:**
- Each worker document tagged with its entity/service name
- Worker task failures isolated per worker
- One worker's error doesn't affect others

**ZeroTier network isolation:**
- If `ZEROTIER_NETWORK_ID` differs per entity, each entity could join separate networks
- Current design: shared network for all entities on same machine
- Future: per-entity networks for higher isolation

**MongoDB collection isolation:**
- All workers in single `workers` collection, but queryable by service name
- Passengers in single `Passengers` collection
- Query scoping ensures entities see only their own state

### 7.3 No Direct Entity-to-Entity Communication

- Entities **cannot directly call each other's workers**
- Entities **cannot directly trigger other entities' hooks**
- **Inter-entity communication:** Via GitHub Issues, comms channels, or signed messages (see VESTA-SPEC-008)

---

## 8. Health and Restart Behavior

### 8.1 Daemon Crash Recovery

**When daemon crashes:**

1. **Process termination detected** (systemd, supervisor, or user notices)
2. **Service manager restarts daemon:**
   ```bash
   # systemd example
   [Service]
   Restart=on-failure
   RestartSec=5
   ```

3. **Daemon cold-starts:**
   - Re-runs full startup sequence (section 3)
   - Re-fires `entity-upstart` hooks
   - Queries MongoDB for existing workers
   - Resumes execution of workers with updated `instanceId`

4. **Workers resume:**
   - Existing worker documents are preserved
   - New daemon instance checks `nextExecution` for each worker
   - Resumes scheduling from that point
   - No task loss (workers state is persistent)

### 8.2 Health Indicators for Salus

Salus monitors daemon health by querying these indicators:

**Daemon process health:**
- Is `daemon` process running? (check `/proc/` or `ps`)
- Uptime: Compare startup time vs. current time
- DDP connection status: Can we reach DDP server?

**Worker health (from `workers` collection):**

```javascript
// Query all workers
db.workers.find({})

// Identify concerning states
db.workers.find({ state: "error" })          // Failed workers
db.workers.find({ insane: true })             // Max retries exceeded
db.workers.find({ errorCount: { $gte: 2 } }) // High error count
db.workers.find({
  lastHeartbeat: { $lt: new Date(Date.now() - 5*60*1000) }
})  // Stale workers (no heartbeat for 5+ minutes)

// Calculate worker success rate
db.workers.aggregate([
  { $group: {
      _id: "$service",
      successCount: { $sum: "$successCount" },
      errorCount: { $sum: "$errorCount" },
      totalRuns: { $add: [ "$successCount", "$errorCount" ] }
    }
  },
  { $project: {
      successRate: { $divide: [ "$successCount", "$totalRuns" ] }
    }
  }
])
```

**Daemon-level metrics:**

```javascript
// Last heartbeat from daemon
db.workers.findOne(
  { lastHeartbeat: { $exists: true } },
  { sort: { lastHeartbeat: -1 } }
)
// If this is recent, daemon is alive

// Worker registration count
db.workers.countDocuments({ enabled: true })

// Average task duration
db.workers.aggregate([
  { $group: {
      _id: null,
      avgDuration: { $avg: "$lastExecutionDuration" },
      maxDuration: { $max: "$lastExecutionDuration" }
    }
  }
])
```

### 8.3 Health Check Protocol

**Daemon self-check every 60 seconds:**

```javascript
// In daemon code
setInterval(() => {
  // Check 1: MongoDB alive
  Workers.findOne({}, (err) => {
    if (err) logger.error('MongoDB unreachable');
  });

  // Check 2: Stale workers
  Workers.find({ lastHeartbeat: { $lt: 5minsAgo } }).forEach(w => {
    logger.warn(`Stale worker: ${w.service}`);
  });

  // Check 3: Insane workers
  Workers.find({ insane: true }).forEach(w => {
    logger.error(`Insane worker (maxed out): ${w.service}`);
    // Could emit alert to Salus here
  });

  // Check 4: DDP session alive
  if (!ddpSession.isConnected) {
    logger.warn('DDP connection lost, attempting reconnect');
  }
}, 60000);
```

### 8.3.1 `/api/health` HTTP Endpoint

The daemon exposes a health check endpoint for Salus and external monitoring systems. This is a Meteor WebApp middleware route on the same port as DDP (default: 28282).

**Endpoint:** `GET /api/health`  
**Authentication:** None required (health checks must be accessible)  
**Response Type:** JSON  
**Implementation:** Meteor WebApp middleware registered at daemon startup

**Example request:**
```bash
curl -s http://127.0.0.1:28282/api/health | jq .
```

**Response shape (all fields required):**
```json
{
  "status": "healthy|degraded|unhealthy",
  "passengers": 8,
  "workers": {
    "total": 12,
    "healthy": 11,
    "insane": 0,
    "stale": 1
  },
  "uptime": 3600,
  "version": "1.0.0"
}
```

**Field definitions:**

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | One of: `healthy` (all systems nominal), `degraded` (some workers failing but daemon operating), `unhealthy` (daemon or MongoDB offline) |
| `passengers` | number | Count of registered passengers (entities with valid `passenger.json`) |
| `workers` | object | Worker state summary (see below) |
| `workers.total` | number | Total registered workers (enabled and disabled) |
| `workers.healthy` | number | Workers with `state: "running"` and `errorCount < maxAttempts` |
| `workers.insane` | number | Workers with `insane: true` (maxed retry attempts) |
| `workers.stale` | number | Workers with no heartbeat for 5+ minutes |
| `uptime` | number | Daemon uptime in seconds (current time - `DAEMON_UPSTART_TIME`) |
| `version` | string | Daemon version (from `DAEMON_VERSION` env var) |

**Status logic:**
- `healthy`: All workers `healthy`; MongoDB and DDP responsive; no stale workers
- `degraded`: Some workers stale or insane, but daemon operating; MongoDB accessible; can accept new task registrations
- `unhealthy`: MongoDB unreachable OR daemon process not responsive OR DDP server down

**Salus uses this endpoint to:**
- Monitor daemon availability (GET /api/health succeeds)
- Detect worker failures (if `workers.insane > 0`, alert immediately)
- Detect stale workers (if `workers.stale > 0`, log warning)
- Estimate system health (check `status` field for degraded/unhealthy)
- Track daemon uptime (useful for restart detection)

### 8.3.2 Salus Query Protocol

### 8.4 Graceful Shutdown

When daemon shuts down (systemd stop, SIGTERM, etc.):

```
1. Set daemon status: SHUTTING_DOWN
2. Stop accepting new requests
3. Fire entity-shutdown hook for all entities
   - Entities get 10 seconds to clean up
4. Allow current worker tasks to finish (with 30-second timeout)
5. Unregister passengers from collection
6. Close DDP server
7. Close MongoDB connection
8. Exit daemon process
```

### 8.5 MongoDB Outage Recovery

MongoDB unavailability causes worker execution to fail but does not crash the daemon. This section defines recovery behavior when MongoDB comes back online.

**Initial MongoDB down scenario:**
1. Daemon starts; attempts MongoDB connection
2. If MongoDB unavailable: logs warning, continues with degraded operation
3. `/api/health` returns `status: "unhealthy"`
4. Worker registration still accepted (queued in memory)
5. Worker execution blocked (no state persistence possible)
6. Salus receives `unhealthy` status and alerts

**MongoDB recovery sequence:**
1. MongoDB process comes online (manual restart, replica set failover, etc.)
2. Daemon's MongoDB health check (every 60s) detects connection restored
3. Logs: "MongoDB reconnected, recovering worker state"
4. Daemon queries `workers` collection for existing documents
5. For each worker:
   - If `instanceId` matches current daemon instance: resume normally
   - If `instanceId` is old (from previous daemon instance): update `instanceId`, resume from `nextExecution`
6. Queued worker registrations (from step 4) now persist to MongoDB
7. `/api/health` status transitions: `unhealthy` → `healthy` (or `degraded` if stale workers detected)
8. Salus detects recovery via health check; clears alert

**Worker task loss prevention:**
- Worker state lives in MongoDB, not daemon memory
- If daemon crashes before MongoDB connection lost, worker state already persisted
- On daemon restart, queries MongoDB for existing workers and resumes
- No worker tasks are lost due to MongoDB transience

**Configuration for resilience:**

Use these env vars to tune MongoDB reconnection behavior:

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `MONGODB_RECONNECT_INTERVAL_MS` | number | 5000 | How often to retry MongoDB connection (5 seconds) |
| `MONGODB_RECONNECT_MAX_ATTEMPTS` | number | 0 (infinite) | Max reconnection attempts before giving up; 0 = infinite |
| `KOAD_IO_AUTO_SPAWN_MONGO` | bool | true | Auto-start MongoDB service if process exits |

**Example timeline — MongoDB replica set failover:**

```
10:00:00 - MongoDB primary node fails
10:00:05 - Daemon health check detects connection lost
          - Logs: "MongoDB unavailable, continuing with degraded operation"
          - /api/health returns {status: "unhealthy"}
10:00:30 - Replica set elects new primary (20 second election window)
10:00:35 - Daemon health check retries, succeeds
          - Logs: "MongoDB reconnected, recovering worker state"
          - Queries workers collection; finds 5 existing workers
          - Updates all instanceIds to current daemon instance
          - /api/health returns {status: "healthy"}
10:00:36 - All workers resume execution from their next scheduled times
          - No tasks were lost
          - Salus detects recovery; clears alert
```

---

## 9. Configuration Reference

### 9.1 Daemon Environment Variables

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `DAEMON_PID` | int | (auto) | Process ID of daemon |
| `DAEMON_VERSION` | string | "1.0.0" | Daemon version |
| `KOAD_IO_BIND_IP` | IP | 127.0.0.1 | Bind address for DDP server |
| `DAEMON_LISTEN_PORT` | int | 28282 | DDP server port |
| `ZEROTIER_NETWORK_ID` | string | (unset) | ZeroTier network to join |
| `ZEROTIER_API_TOKEN` | string | (unset) | ZeroTier API token (optional) |
| `KOAD_IO_AUTO_SPAWN_MONGO` | bool | true | Auto-spawn MongoDB if missing |
| `MONGODB_URL` | URL | mongodb://localhost:27017/koad-io | MongoDB connection string |
| `KOAD_IO_QUIET` | bool | 0 | Suppress verbose daemon logs |
| `PASSENGER_REFRESH_INTERVAL` | int | 60000 | Passenger discovery interval (milliseconds) |
| `WORKER_HEALTH_CHECK_INTERVAL` | int | 60000 | Worker health check interval |

### 9.2 Passenger Registry Configuration

**File:** `~/.koad-io/passenger-config.json`

```json
{
  "daemon_host": "127.0.0.1",
  "daemon_port": 28282,
  "auto_connect": true,
  "reconnect_interval": 5000,
  "log_urls": true,
  "log_path": "~/.koad-io/logs/passenger.log"
}
```

### 9.3 Worker Default Configuration

These can be overridden per-worker in `koad.workers.start()`:

```javascript
const WORKER_DEFAULTS = {
  maxAttempts: 3,
  timeout: 300000,        // 5 minutes
  runImmediately: false,
  type: 'general'
};
```

---

## 10. Examples

### 10.1 Full Passenger Registration Example

**File: `~/.salus/passenger.json`**

```json
{
  "handle": "salus",
  "name": "Salus",
  "role": "healer",
  "avatar": "avatar.png",
  "outfit": "green",
  "buttons": [
    {
      "label": "Diagnose",
      "action": "diagnose",
      "description": "Run health diagnostics"
    },
    {
      "label": "Repair",
      "action": "repair",
      "description": "Attempt automatic healing"
    }
  ],
  "status": "active"
}
```

**Daemon processing:**
1. Reads `.salus/.env` → finds `KOAD_IO_VERSION`
2. Reads `.salus/passenger.json`
3. Embeds `avatar.png` as base64 data URI
4. Inserts into MongoDB:
   ```javascript
   {
     handle: "salus",
     name: "Salus",
     role: "healer",
     image: "data:image/png;base64,iVBORw0KGgo...",
     outfit: "green",
     buttons: [ /* ... */ ],
     status: "active",
     _lastUpdated: ISODate("2026-04-03T10:15:40Z")
   }
   ```

### 10.2 Worker Registration and Execution Example

**File: `~/.vulcan/startup.js` (Meteor startup)**

```javascript
Meteor.startup(async () => {
  // Register a build worker
  await koad.workers.start({
    service: 'daily-build-check',
    interval: 1440,          // Every 24 hours
    delay: 60,               // 1 hour after midnight
    task: async () => {
      console.log('[VULCAN] Checking for stale builds...');
      
      const builds = await db.collection('builds')
        .find({ status: 'pending' })
        .toArray();
      
      if (builds.length > 0) {
        console.log(`[VULCAN] Found ${builds.length} stale builds`);
        // Trigger rebuild process
        await triggerRebuild(builds);
      }
      
      return { processed: builds.length };
    },
    timeout: 600000  // 10 minutes
  });
});
```

**MongoDB worker document:**

```javascript
{
  _id: ObjectId("..."),
  service: "daily-build-check",
  host: "thinker",
  pid: 1234,
  instanceId: "inst-20260403-abc123",
  workerId: "worker-uuid-abc123",
  
  interval: 1440,
  delay: 60,
  type: "general",
  maxAttempts: 3,
  timeout: 600000,
  
  state: "running",
  enabled: true,
  insane: false,
  
  lastHeartbeat: ISODate("2026-04-03T09:30:00Z"),
  asof: ISODate("2026-04-03T09:30:00Z"),
  nextExecution: ISODate("2026-04-04T01:00:00Z"),
  lastExecution: ISODate("2026-04-02T01:00:00Z"),
  lastExecutionDuration: 1234,
  successCount: 30,
  errorCount: 0,
  
  errors: [],
  createdAt: ISODate("2026-03-01T10:00:00Z"),
  updatedAt: ISODate("2026-04-03T09:30:00Z")
}
```

### 10.3 Dark Passenger URL Received Hook Example

**File: `~/.sibyl/hooks/passenger-url-received.sh`**

```bash
#!/bin/bash
# Hook: passenger-url-received
# Fires: Browser extension sends a URL to the daemon

LOG_FILE="$ENTITY_DIR/comms/research-queue.txt"

# Append URL to research queue with timestamp and source
echo "[$PASSENGER_RECEIVED_AT] URL: $PASSENGER_URL" >> "$LOG_FILE"
echo "  Title: $PASSENGER_TITLE" >> "$LOG_FILE"
echo "  Domain: $PASSENGER_DOMAIN" >> "$LOG_FILE"
echo "  Browser: $BROWSER_CONTEXT" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Optional: post to GitHub as an issue for tracking
if [ "${PASSENGER_DOMAIN}" = "github.com" ]; then
  gh issue create -R koad/sibyl \
    --title "Research: $PASSENGER_TITLE" \
    --body "**Source:** Dark Passenger\\n\\n**URL:** $PASSENGER_URL\\n\\n**Time:** $PASSENGER_RECEIVED_AT"
fi

echo "[SIBYL] Queued for research: $PASSENGER_DOMAIN"
```

---

## 11. Compatibility & Migration

### 11.1 From Hooks to Daemon

Previously, entities triggered work via shell hooks. The daemon-based worker system is the canonical approach for scheduled work going forward.

**Old pattern (hooks only):**
```bash
# Manual cron-like invocation
0 1 * * * ~/.vesta/hooks/daily-reconcile.sh
```

**New pattern (daemon workers):**
```javascript
// In Meteor startup
await koad.workers.start({
  service: 'daily-reconcile',
  interval: 1440,
  delay: 60,
  task: () => runReconciliation()
});
```

**Migration note:** Both patterns can coexist. Hooks remain valid for synchronous, event-driven work (entity startup, Dark Passenger events). Workers are for asynchronous, scheduled tasks.

---

## 12. Appendices

### Appendix A: DDP Method Reference

**Publicly callable methods:**

```javascript
// Passenger management
Meteor.call('passenger.select', { handle: 'vesta' })
Meteor.call('passenger.url-received', { url, title, domain })
Meteor.call('passenger.identity-request', { requestId })
Meteor.call('passenger.button-click', { handle, action })

// Worker management (internal, not for external use)
Meteor.call('worker.register', { /* config */ })
Meteor.call('worker.heartbeat', { service, status })
Meteor.call('worker.unregister', { service })
```

### Appendix B: Daemon Log Format

All logs written to `~/.koad-io/logs/daemon.log` in format:

```
[ISO-timestamp] [LEVEL] [component] message

[2026-04-03T10:15:30Z] [INFO] daemon Daemon starting PID=1234
[2026-04-03T10:15:32Z] [INFO] mongo MongoDB connected
[2026-04-03T10:15:33Z] [WARN] passenger Could not load passenger.json for vulcan: ENOENT
[2026-04-03T10:15:34Z] [ERROR] worker Worker 'my-service' max retries exceeded
```

### Appendix C: Salus Healing Actions

When Salus detects daemon health issues:

| Condition | Action |
|-----------|--------|
| Daemon not running | Restart daemon via systemd/supervisor |
| Worker insane (maxed retries) | Alert via GitHub issue; recommend manual fix |
| Worker stale (no heartbeat 5+ min) | Log warning; restart worker task |
| MongoDB unavailable | Alert immediately; attempt to restart MongoDB |
| ZeroTier disconnected | Rejoin network; reconnect peers |
| DDP connection lost | Daemon auto-reconnects; Salus monitors recovery |

---

## 13. Questions & Answers

**Q: Why DDP on port 28282?**  
A: Dark Passenger (browser extension) needs a low, memorable port. 28282 = "te te" in leetspeak, a small in-joke. Any port can be configured via `DAEMON_LISTEN_PORT`.

**Q: Can multiple machines' daemons talk to each other?**  
A: Yes, via ZeroTier network. Current implementation is machine-local (entities on same machine share daemon). Future: inter-daemon worker delegation.

**Q: What if MongoDB crashes?**  
A: Daemon logs error and continues running. Workers cannot persist state. Salus detects and alerts. MongoDB should be auto-restarted by supervisor.

**Q: Can an entity run on multiple machines?**  
A: No. Each entity is tied to one machine's `ENTITY_DIR`. Inter-machine coordination happens via GitHub Issues or comms channels.

**Q: How do I customize the worker retry logic?**  
A: Per-worker in `koad.workers.start()`: set `maxAttempts` and `timeout`. Daemon-wide defaults in daemon config.

**Q: What happens if a task throws an exception?**  
A: Exception is caught, logged to worker document, counted as attempt. Daemon retries per backoff logic. After `maxAttempts`, worker marked insane.

**Q: Can I see worker logs?**  
A: Worker task output is logged to daemon logs (`~/.koad-io/logs/daemon.log`). Error details stored in worker document `errors[]` array. Query MongoDB to inspect.

**Q: How do I know if the daemon is healthy?**  
A: Query `workers` collection for insane/stale workers. Check daemon uptime (compare startup time vs. now). Verify DDP connection. Salus can automate this.

---

## References

- VESTA-SPEC-001: Canonical Entity Model
- VESTA-SPEC-005: Cascade Environment Protocol
- VESTA-SPEC-008: Spawn Protocol
- VESTA-SPEC-009: Hooks Catalog
- koad:io-worker-processes Meteor package (server/logic.js)
- Dark Passenger browser extension
- ZeroTier VPN documentation

---

**Spec Version:** 1.0-draft  
**Canonical Location:** `~/.vesta/specs/daemon-specification.md`  
**Next Steps:** Vulcan review for worker implementation feasibility; Salus review for health monitoring patterns.
