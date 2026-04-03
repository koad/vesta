---
title: "Hooks Catalog — Lifecycle Events, Daemon Triggers, DDP Events"
spec-id: VESTA-SPEC-009
status: canonical
created: 2026-04-03
author: Vesta (vesta@kingofalldata.com)
reviewers: [koad, Juno]
related-issues: [koad/vesta#9, koad/vulcan#17]
---

# Hooks Catalog — Lifecycle Events, Daemon Triggers, DDP Events

## Overview

The hooks system is koad:io's mechanism for entity-initiated reactions to system events. When the daemon starts, when a comms message arrives, when the browser extension sends a URL — hooks let the entity respond in real time without polling.

This spec defines the complete event surface available to entities, the hook function signature and environment for each event, the default framework behavior, and how entities override hooks.

**Architectural note:** The daemon runs in the user's shell context, so hooks can interact with the full environment — open terminal windows, spawn GUIs, trigger OBS, write files, etc.

---

## 1. Hook Execution Model

### Framework design

Every hook is a shell script (`bash` by default, configurable). The daemon is responsible for:
1. Detecting that an event has occurred
2. Determining which entity to notify (usually: the active entity, or the entity that owns the event)
3. Locating the hook script in `~/.entity/hooks/`
4. Executing the script with appropriate environment and arguments
5. Capturing output and logging the result
6. Handling failures (timeout, non-zero exit, etc.)

### Hook file structure

```bash
#!/bin/bash
# ~/.entity/hooks/hook-name.sh
#
# Hook: hook-name
# Fires: [when this hook is triggered]
# Args: [what arguments are passed to $@]
# Env: [what environment variables are set]
# Sync: [sync | async] — can hook run in background?

set -e  # Exit on error
set -u  # Exit on undefined variable

# Hook body
echo "Hook fired with args: $@"
```

### Execution guarantees

- **Working directory:** `~/.entity` (entity's home directory)
- **Environment:** Standard bash environment + entity-specific env vars (see Env section for each hook)
- **User:** Same user as daemon (usually the entity's user)
- **Permissions:** Execute bit set (mode 755)
- **Timeout:** 30 seconds by default (entity can increase via `.hook-timeout` config)
- **Logging:** Stdout/stderr captured in daemon logs at `~/.entity/logs/hooks.log`

### Hook precedence

1. **Entity-level hook:** `~/.entity/hooks/hook-name.sh` (if exists)
2. **Global default:** `~/.koad-io/hooks/hook-name.sh` (if entity hook doesn't override)
3. **No-op:** If neither exists, hook is skipped silently (no error)

This allows entities to override any hook while falling back to framework defaults.

---

## 2. Invocation Hooks

These hooks fire when the entity is invoked (CLI entry point).

### 2.1: `executed-without-arguments.sh`

**When it fires:** Entity is called with no arguments from the shell or daemon
**Example triggers:**
- User runs `juno` on command line
- Daemon fires `juno` to handle an async event
- Another entity calls `vulcan` without args

**Arguments passed:** None (`$#` = 0)

**Environment variables:**
```bash
ENTITY=<entity-name>               # e.g., "juno"
ENTITY_DIR=<entity-home>           # e.g., "$HOME"
INVOKED_BY=<caller>                # "shell" | "daemon" | "comms" | "worker"
INVOKED_AT=<timestamp>             # ISO 8601, e.g., "2026-04-03T14:30:00Z"
INVOKED_FROM_HOST=<hostname>       # hostname of caller (for remote invocations)
```

**Default behavior (no entity hook):**
- Framework enters interactive mode
- Loads CLAUDE.md (if Claude Code harness)
- Awaits user input

**Sync/async:** Synchronous (must complete before prompt returns)

**Example override (Juno checks for pending issues before prompting):**
```bash
#!/bin/bash
# ~/.juno/hooks/executed-without-arguments.sh

echo "[JUNO] Starting session..."
echo "[JUNO] Checking for pending work..."

gh issue list --state open --limit 5
echo ""
echo "[JUNO] Ready for commands."

# After this returns, the interactive prompt appears
```

---

### 2.2: `executed-with-arguments.sh`

**When it fires:** Entity is called with arguments
**Example triggers:**
- User runs `vulcan build` from shell
- Daemon runs `vulcan --daemon-check` to verify status
- Another entity calls `sibyl query arg1 arg2`

**Arguments passed:** All CLI arguments (receives `$@`)
- `$1` = first argument
- `$2` = second argument
- `$@` = all arguments as array
- `$#` = count of arguments

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
INVOKED_BY=<caller>
INVOKED_AT=<timestamp>
INVOKED_FROM_HOST=<hostname>
```

**Default behavior (no entity hook):**
- Framework interprets arguments as command
- Routes to entity's command handler (see Commands spec)
- Executes command, returns result

**Sync/async:** Synchronous

**Example override (Veritas logs all external invocations for audit):**
```bash
#!/bin/bash
# ~/.veritas/hooks/executed-with-arguments.sh

LOG_FILE="$ENTITY_DIR/logs/audit-invocations.log"
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Invoked by $INVOKED_BY from $INVOKED_FROM_HOST: $@" >> "$LOG_FILE"

# Framework continues with normal command processing
```

---

## 3. Daemon Lifecycle Hooks

These hooks fire as the daemon starts, stops, or changes connection state.

### 3.1: `entity-upstart.sh`

**When it fires:** 
- Daemon process starts (on machine reboot or daemon restart)
- After all initialization, before first task

**Arguments:** None

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
DAEMON_PID=<pid>                   # PID of daemon process
DAEMON_VERSION=<version>           # Daemon version, e.g., "1.0.2"
DAEMON_UPSTART_TIME=<timestamp>    # When daemon started
```

**Default behavior (framework global):**
Located at `~/.koad-io/hooks/entity-upstart.sh`. Commonly:
- Checks `~/.koad-io/` structure integrity
- Loads `.env` files
- Ensures basic directories exist
- Logs startup event

**Sync/async:** Synchronous (daemon waits for completion)

**Example override (Juno checks mail on startup):**
```bash
#!/bin/bash
# ~/.juno/hooks/entity-upstart.sh

# Run global startup first
source ~/.koad-io/hooks/entity-upstart.sh

# Juno-specific: check for overnight comms
echo "[JUNO] Checking overnight comms..."
if [ -d "$ENTITY_DIR/comms/inbox" ]; then
  find "$ENTITY_DIR/comms/inbox" -type f -mtime -1 | wc -l | xargs echo "[JUNO] New messages:"
fi

echo "[JUNO] Daemon ready."
```

---

### 3.2: `daemon-connected.sh`

**When it fires:** Daemon establishes DDP connection to Meteor (after upstart)
**Precondition:** DDP channel negotiation succeeds; daemon authenticated

**Arguments:** None

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
DDP_HOST=<host>                    # Meteor server hostname
DDP_PORT=<port>                    # Meteor server port
DDP_SESSION_ID=<id>                # Session token (for identifying this connection)
CONNECTED_AT=<timestamp>
```

**Default behavior:** No-op (framework continues listening for DDP messages)

**Sync/async:** Synchronous

**Example override (Vulcan pings koad when connected):**
```bash
#!/bin/bash
# ~/.vulcan/hooks/daemon-connected.sh

curl -X POST "http://${DDP_HOST}:8080/api/entity-online" \
  -H "Authorization: Bearer ${VULCAN_API_TOKEN}" \
  -d "entity=vulcan&session=${DDP_SESSION_ID}"

echo "[VULCAN] Connected to daemon."
```

---

### 3.3: `daemon-disconnected.sh`

**When it fires:** DDP connection is lost (network failure, server restart, explicit disconnect)

**Arguments:** None

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
DISCONNECT_REASON=<reason>         # "timeout" | "server-shutdown" | "network-error" | "client-disconnect"
DISCONNECTED_AT=<timestamp>
RECONNECT_ATTEMPTS=<count>         # How many times daemon will retry
```

**Default behavior:** Daemon logs disconnect, enters retry loop

**Sync/async:** Asynchronous (daemon does not wait for hook to complete)

**Example override (Alert on unexpected disconnect):**
```bash
#!/bin/bash
# ~/.salus/hooks/daemon-disconnected.sh

if [ "$DISCONNECT_REASON" != "client-disconnect" ]; then
  echo "[SALUS] Daemon disconnected: $DISCONNECT_REASON" | \
    mail -s "Salus Daemon Alert" salus@kingofalldata.com
fi
```

---

## 4. Passenger Hooks (Dark Passenger Browser Extension)

These hooks fire when the Passenger browser extension (running in user's browser) sends events to the daemon.

**Prerequisite:** Browser extension is installed and connected to daemon. Entity is set as active passenger.

### 4.1: `passenger-selected.sh`

**When it fires:** User selects this entity as the active passenger in the browser extension

**Arguments:** None

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
SELECTED_AT=<timestamp>
PREVIOUS_PASSENGER=<entity-name>   # Which entity was previously active
```

**Default behavior:** No-op

**Sync/async:** Synchronous

**Example override (Mercury prepares to handle browser interactions):**
```bash
#!/bin/bash
# ~/.mercury/hooks/passenger-selected.sh

echo "[MERCURY] Activated as passenger."
# Could: start listening on a socket, load browser context, etc.
```

---

### 4.2: `passenger-deselected.sh`

**When it fires:** User deselects this entity (selects a different entity as active)

**Arguments:** None

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
DESELECTED_AT=<timestamp>
NEW_PASSENGER=<entity-name>        # Which entity is now active
```

**Default behavior:** No-op

**Sync/async:** Synchronous

---

### 4.3: `passenger-url-received.sh`

**When it fires:** Browser extension sends a URL to the active passenger entity

**Arguments:** Passed as environment variables (not positional args)

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
PASSENGER_URL=<url>                # Full URL, e.g., "https://example.com/page"
PASSENGER_TITLE=<title>            # Page title from `<title>` tag
PASSENGER_DOMAIN=<domain>          # Domain extracted from URL
PASSENGER_RECEIVED_AT=<timestamp>
BROWSER_CONTEXT=<context>          # Browser name, tab ID (extension-dependent)
```

**Default behavior:** No-op (URL is logged to `.passenger-urls.log`)

**Sync/async:** Asynchronous (browser does not wait for response)

**Example override (Sibyl analyzes incoming URLs):**
```bash
#!/bin/bash
# ~/.sibyl/hooks/passenger-url-received.sh

LOG_FILE="$ENTITY_DIR/comms/research-queue.txt"

# Append URL and metadata to research queue
echo "[$PASSENGER_RECEIVED_AT] $PASSENGER_URL | $PASSENGER_TITLE" >> "$LOG_FILE"

# Could: curl the URL, extract metadata, file an issue, etc.
```

---

### 4.4: `passenger-identity-request.sh`

**When it fires:** Browser extension asks this entity "who is the person using this browser?"

**Arguments:** None

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
REQUEST_ID=<id>                    # Unique ID for this request (for response correlation)
REQUESTED_AT=<timestamp>
```

**Expected output (stdout):**
```json
{
  "request_id": "<matching REQUEST_ID>",
  "identity": "<koad user name>",
  "entity": "<active-entity-name>",
  "verified": true|false,
  "expires": "<ISO 8601 timestamp>"
}
```

If no output, browser assumes entity has no answer (returns "unknown").

**Default behavior:** No-op; returns `{"verified": false}`

**Sync/async:** Synchronous (browser waits for response, 2-second timeout)

**Example override (Juno provides verified identity to browser):**
```bash
#!/bin/bash
# ~/.juno/hooks/passenger-identity-request.sh

# Juno is piloted by koad, so koad's identity is the truth
cat <<EOF
{
  "request_id": "$REQUEST_ID",
  "identity": "koad",
  "entity": "juno",
  "verified": true,
  "expires": "$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

---

### 4.5: `passenger-url-check.sh`

**When it fires:** Browser extension asks this entity to check/validate a URL (safety check, reputation check, etc.)

**Arguments:** None

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
CHECK_URL=<url>
REQUEST_ID=<id>
REQUESTED_AT=<timestamp>
```

**Expected output (stdout):**
```json
{
  "request_id": "<matching REQUEST_ID>",
  "url": "<CHECK_URL>",
  "verdict": "safe" | "warning" | "dangerous",
  "reason": "<optional explanation>",
  "timestamp": "<ISO 8601>"
}
```

**Default behavior:** No-op; returns `{"verdict": "unknown"}`

**Sync/async:** Synchronous (1-second timeout)

**Example override (Argus performs reputation check):**
```bash
#!/bin/bash
# ~/.argus/hooks/passenger-url-check.sh

# Check against internal blocklist
BLOCKLIST="$ENTITY_DIR/config/url-blocklist.txt"
if grep -q "$(echo $CHECK_URL | sed 's|https://||' | cut -d/ -f1)" "$BLOCKLIST"; then
  cat <<EOF
{
    "request_id": "$REQUEST_ID",
    "url": "$CHECK_URL",
    "verdict": "dangerous",
    "reason": "Domain on internal blocklist",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
else
  cat <<EOF
{
    "request_id": "$REQUEST_ID",
    "url": "$CHECK_URL",
    "verdict": "safe",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
fi
```

---

## 5. Worker and Schedule Hooks

These hooks fire when the daemon's task scheduler triggers work for the entity.

### 5.1: `worker-fired.sh`

**When it fires:** A scheduled worker task triggers this entity
**Example:** Daemon has scheduled job "daily-digest" → fires this hook at the scheduled time

**Arguments:** Worker metadata passed as arguments
- `$1` = worker name (e.g., "daily-digest")
- `$2` = payload (JSON string, if any)

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
WORKER_NAME=$1
WORKER_PAYLOAD=$2                  # JSON string (URL-decoded)
FIRED_AT=<timestamp>
FIRE_SEQUENCE=<count>              # How many times this worker has fired
```

**Default behavior:** No-op (worker event is logged)

**Sync/async:** Asynchronous (daemon does not wait for completion)

**Example override (Juno runs daily status report):**
```bash
#!/bin/bash
# ~/.juno/hooks/worker-fired.sh

WORKER_NAME="$1"
WORKER_PAYLOAD="$2"

case "$WORKER_NAME" in
  daily-digest)
    echo "[JUNO] Running daily digest at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    # Generate report
    gh issue list --state open --label important --limit 5 > "$ENTITY_DIR/reports/daily-$(date +%Y-%m-%d).txt"
    # Could email the report, post to Slack, etc.
    ;;
  *)
    echo "[JUNO] Unknown worker: $WORKER_NAME"
    exit 1
    ;;
esac
```

---

## 6. Comms Hooks

These hooks fire when the entity receives communications (messages, DDP data, etc.).

### 6.1: `comms-inbox-message.sh`

**When it fires:** New message arrives in `~/.entity/comms/inbox/`

**Arguments:** Message file path
- `$1` = relative path to message file (e.g., `2026-04-03-juno-status-update.md`)

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
MESSAGE_PATH=<path>                # Full path: $ENTITY_DIR/comms/inbox/<filename>
MESSAGE_SENDER=<entity-name>       # Which entity sent this
RECEIVED_AT=<timestamp>
MESSAGE_ID=<id>                    # Unique message ID
```

**Default behavior:** No-op (message is logged)

**Sync/async:** Asynchronous

**Example override (Vulcan logs all incoming work assignments):**
```bash
#!/bin/bash
# ~/.vulcan/hooks/comms-inbox-message.sh

MESSAGE_PATH="$1"
MESSAGE_SENDER="$2"

# Check if this is a work assignment (message contains "assigned:")
if grep -q "assigned:" "$MESSAGE_PATH"; then
  echo "[VULCAN] Work assignment from $MESSAGE_SENDER:" >> "$ENTITY_DIR/logs/assignments.log"
  cat "$MESSAGE_PATH" >> "$ENTITY_DIR/logs/assignments.log"
  echo "---" >> "$ENTITY_DIR/logs/assignments.log"
fi
```

---

### 6.2: `comms-ddp-received.sh`

**When it fires:** Raw DDP message received on entity's channel (lower-level than inbox messages)

**Arguments:** Message as JSON string
- `$1` = raw DDP message (JSON)

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
DDP_MESSAGE=<json>                 # Raw DDP message (also available as $1)
DDP_CHANNEL=<channel>              # Channel name
DDP_FROM=<entity-name>             # Sender
RECEIVED_AT=<timestamp>
```

**Default behavior:** No-op (only developers typically use this hook)

**Sync/async:** Synchronous

---

## 7. Session Hooks

These hooks fire when entity's DDP session is established or lost.

### 7.1: `session-connected.sh`

**When it fires:** Entity DDP session established (entity authenticated on Meteor)

**Arguments:** None

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
SESSION_TOKEN=<token>              # Session token for this entity
SESSION_ID=<id>                    # Unique session ID
CONNECTED_AT=<timestamp>
```

**Default behavior:** Framework logs session established

**Sync/async:** Synchronous

**Example override (Juno notifies koad of login):**
```bash
#!/bin/bash
# ~/.juno/hooks/session-connected.sh

# Log for audit
echo "[JUNO] Session $SESSION_ID started" >> "$ENTITY_DIR/logs/sessions.log"
```

---

### 7.2: `session-disconnected.sh`

**When it fires:** Entity DDP session ends (logout, timeout, error)

**Arguments:** None

**Environment variables:**
```bash
ENTITY=<entity-name>
ENTITY_DIR=<entity-home>
SESSION_ID=<id>
DISCONNECT_REASON=<reason>         # "logout" | "timeout" | "error" | "server-restart"
DURATION_SECONDS=<seconds>         # How long session lasted
DISCONNECTED_AT=<timestamp>
```

**Default behavior:** No-op

**Sync/async:** Synchronous

---

## 8. Hook Configuration and Customization

### Hook timeout

By default, hooks have a 30-second timeout. Entity can override:

```bash
# ~/.entity/.hook-timeout
# Format: HOOK_NAME=<seconds>

executed-without-arguments=10
passenger-url-received=5
worker-fired=60  # Long-running workers need more time
```

### Hook error handling

If a hook exits non-zero:
- Framework logs the failure
- Execution continues (hook failure does not block entity)
- `HOOK_EXIT_CODE` environment variable is available to next hook (if any)

Example: if `passenger-url-received` fails, the URL is still logged; message still arrives.

### Disabling a hook

Entity can disable any hook by creating an empty file:

```bash
touch ~/.entity/hooks/passenger-url-received.sh.disabled
```

The `.disabled` suffix tells framework to skip the hook.

### Hook dependencies

Hooks are executed sequentially when multiple events fire. Framework guarantees:
1. One entity's hooks do not run in parallel (serialized)
2. One event = one hook execution (no duplicates)
3. If hook A fails, hook B still fires (independent)

---

## 9. Logging and Audit

### Hook execution log

Every hook execution is logged to `~/.entity/logs/hooks.log`:

```
[2026-04-03T14:22:15Z] HOOK=executed-without-arguments EXIT=0 DURATION=0.23s
[2026-04-03T14:22:16Z] HOOK=passenger-selected EXIT=0 DURATION=0.05s
[2026-04-03T14:22:17Z] HOOK=passenger-url-received URL=https://example.com EXIT=0 DURATION=0.12s
[2026-04-03T14:22:25Z] HOOK=worker-fired WORKER=daily-digest EXIT=1 DURATION=5.82s
  ERROR: exit code 1; see stderr below
  STDERR: [JUNO] Unknown worker: daily-digest
```

### Hook discovery

Argus (audit/diagnostic entity) can discover all hooks:

```bash
# List all hooks implemented by entity
find ~/.entity/hooks -name "*.sh" -not -name "*.disabled"

# Check if hook is implemented or using global default
[ -f ~/.entity/hooks/passenger-url-received.sh ] && echo "Custom" || echo "Global default"
```

---

## 10. Compatibility and Migration

### Global default locations

Framework provides global defaults at:
```
~/.koad-io/hooks/entity-upstart.sh
~/.koad-io/hooks/executed-without-arguments.sh
~/.koad-io/hooks/executed-with-arguments.sh
```

Any hook not overridden by entity uses the global default (if it exists).

### Hook discovery protocol

When framework needs to fire a hook:
1. Check: does `~/.entity/hooks/HOOK_NAME.sh` exist? → Execute it
2. Check: is `.disabled` file present? → Skip (no-op)
3. Check: does `~/.koad-io/hooks/HOOK_NAME.sh` exist? → Execute it
4. Else: No-op (hook is optional)

### Future harnesses

Any harness (Claude Code, opencode, OpenClaw) using this spec must:
- Implement hook discovery and execution as above
- Respect `.disabled` files
- Log all hook executions to `~/.entity/logs/hooks.log`
- Enforce timeout limits

---

## 11. Examples

### Example 1: Entity startup flow

```bash
# Daemon upstart
→ fires entity-upstart.sh for all entities
  └ ~/.juno/hooks/entity-upstart.sh (custom)
  └ ~/.vulcan/hooks/entity-upstart.sh (uses global default)

# Daemon connects to DDP
→ fires daemon-connected.sh
  └ ~/.vulcan/hooks/daemon-connected.sh (custom, pings server)
  └ ~/.sibyl/hooks/daemon-connected.sh (no custom, no-op)

→ fires session-connected.sh
  └ ~/.juno/hooks/session-connected.sh (logs to audit)
```

### Example 2: Browser interaction flow

```bash
User selects "Mercury" in browser extension
→ fires passenger-selected.sh in Mercury
  └ ~/.mercury/hooks/passenger-selected.sh (loads context)

User visits https://example.com
→ Browser sends URL to daemon
→ fires passenger-url-received.sh in Mercury
  └ ~/.mercury/hooks/passenger-url-received.sh (logs URL)

User hovers over a link
→ Browser asks "is this safe?"
→ fires passenger-url-check.sh in Mercury
  └ ~/.mercury/hooks/passenger-url-check.sh (checks blocklist, returns verdict)
```

### Example 3: Scheduled work

```bash
Daemon schedule: 09:00 daily → worker "daily-digest"
→ At 09:00, daemon fires worker-fired.sh in Juno
  └ ~/.juno/hooks/worker-fired.sh (generates report, emails it)

Worker payload: {"month": "2026-04", "format": "summary"}
→ Hook receives: WORKER_NAME=daily-digest WORKER_PAYLOAD='{"month":"2026-04"...}'
```

---

*Spec status: canonical (2026-04-03). File issues on koad/vesta to propose amendments or report implementation gaps.*
