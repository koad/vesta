---
status: draft
id: VESTA-SPEC-035
title: "Enriched PID Lock File — Status Beacon for Entity Invocations"
type: spec
version: 0.1
date: 2026-04-05
owner: vesta
description: "The PID lock file for entity hooks carries structured JSON beyond the bare PID: invoker identity, prompt snapshot, start timestamp, and issue reference. The lock is a live status beacon. On exit, its contents are appended to an immutable invocation log. The lock and log together provide real-time observability and a permanent audit trail of every entity invocation."
related-specs:
  - VESTA-SPEC-020 (Hook Architecture)
  - VESTA-SPEC-009 (Daemon Specification)
---

# VESTA-SPEC-035: Enriched PID Lock File

**Authority:** Vesta. This spec defines the enriched PID lock file format, the invocation log format, the $INVOKER convention, the elapsed-time busy message, the completion emit hook, and the team-wide event log.

**Scope:** Entity hooks using PID lock files; the gestation template for `executed-without-arguments.sh`; Salus (applies to existing entities); Argus (consumes the event log).

**Consumers:**
- All entity hooks (writers)
- Salus (migration to 15+ existing entities)
- Argus (monitoring, alert thresholds)
- Janus (circular invocation detection, hung entity detection)
- Stream PWA (live team activity dashboard)
- Daemon event bus (post-daemon migration target)

---

## 1. Problem

The current lock file contains only the PID:

```bash
echo $$ > "$LOCKFILE"
```

When an entity is busy, the only observable fact is the PID. There is no way to know:
- Who asked it to do work
- What it was asked to do
- When it started (and therefore how long it has been running)
- Which issue or task it is working on

This makes the system opaque: debugging a hung entity requires attaching to the process; understanding what the team is doing requires reading git logs post-hoc; detecting circular invocations requires external tooling.

**The lock file should be a status beacon.**

---

## 2. Lock File Format

### 2.1 JSON Structure

The lock file is a JSON object written atomically at invocation start:

```json
{
  "pid": 12345,
  "entity": "iris",
  "asked_by": "juno",
  "prompt": "Write the gitagent competitive brief — focus on the agent-native vs. wrapper distinction.",
  "started_at": "2026-04-04T10:30:00Z",
  "issue": "koad/iris#6",
  "host": "fourty4",
  "harness": "claude"
}
```

### 2.2 Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pid` | integer | Yes | Process ID of the running entity session |
| `entity` | string | Yes | Entity name (from `$ENTITY`) |
| `asked_by` | string | Yes | Invoker identity: entity name, `koad`, or `system` (from `$INVOKER`) |
| `prompt` | string | Yes | The prompt passed to the entity (truncated to 500 chars if longer) |
| `started_at` | string | Yes | ISO 8601 UTC timestamp when invocation started |
| `issue` | string | No | GitHub issue reference if the prompt references one (e.g., `koad/iris#6`) |
| `host` | string | No | Machine hostname (from `$HOSTNAME`) |
| `harness` | string | No | AI harness used: `claude`, `opencode`, `pi`, `hermez` (from `$HARNESS` or `.env`) |

### 2.3 Prompt Truncation

The `prompt` field is truncated to 500 characters with a `...` suffix if longer. The full prompt is available in the invocation log (§4) and from the process environment.

### 2.4 Writing the Lock File

The lock file must be written **atomically** to prevent partial reads:

```bash
# Write atomically via temp file + rename
LOCK_CONTENT=$(python3 -c "
import json, os, sys
data = {
    'pid': os.getpid(),
    'entity': os.environ.get('ENTITY', 'unknown'),
    'asked_by': os.environ.get('INVOKER', 'unknown'),
    'prompt': (os.environ.get('PROMPT', '')[:500] + '...'
               if len(os.environ.get('PROMPT', '')) > 500
               else os.environ.get('PROMPT', '')),
    'started_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'issue': os.environ.get('ISSUE_REF', ''),
    'host': os.environ.get('HOSTNAME', ''),
    'harness': os.environ.get('HARNESS', 'claude'),
}
print(json.dumps(data, indent=2))
")
echo "$LOCK_CONTENT" > "${LOCKFILE}.tmp"
mv "${LOCKFILE}.tmp" "$LOCKFILE"
```

---

## 3. Busy Message with Elapsed Time

When a new invocation finds the lock held, the busy message includes the elapsed time and a prompt preview:

```bash
# On busy detection
LOCK_DATA=$(cat "$LOCKFILE")
STARTED=$(echo "$LOCK_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin).get('started_at',''))")
ASKED_BY=$(echo "$LOCK_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin).get('asked_by','unknown'))")
PROMPT_PREVIEW=$(echo "$LOCK_DATA" | python3 -c "
import sys, json
p = json.load(sys.stdin).get('prompt', '')
print(p[:80] + '...' if len(p) > 80 else p)
")
ISSUE=$(echo "$LOCK_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin).get('issue',''))")
ELAPSED=$(python3 -c "
from datetime import datetime, timezone
s = '$STARTED'
if s:
    delta = datetime.now(timezone.utc) - datetime.fromisoformat(s.replace('Z','+00:00'))
    mins = int(delta.total_seconds() // 60)
    print(str(mins) + 'min')
else:
    print('unknown time')
" 2>/dev/null || echo "unknown time")

ISSUE_PART=""
[[ -n "$ISSUE" ]] && ISSUE_PART=" (${ISSUE})"
echo "${ENTITY} is busy — ${ELAPSED} since ${STARTED}, asked by ${ASKED_BY}${ISSUE_PART}: \"${PROMPT_PREVIEW}\"" >&2
exit 1
```

**Example output:**

```
iris is busy — 47min since 2026-04-04T10:30:00Z, asked by juno (koad/iris#6): "Write the gitagent competitive brief — focus on the agent-native vs. wrapper..."
```

---

## 4. Invocation Log

### 4.1 Format

On EXIT trap (before lock release), the completed invocation is appended to a per-entity JSONL log:

```
~/.{entity}/var/invocation-log.jsonl
```

Each line is a complete invocation record:

```json
{"pid":12345,"entity":"iris","asked_by":"juno","prompt":"Write the gitagent competitive brief...","started_at":"2026-04-04T10:30:00Z","ended_at":"2026-04-04T11:20:00Z","exit_code":0,"duration_seconds":3000,"issue":"koad/iris#6","host":"fourty4","harness":"claude"}
```

Additional fields added at completion:

| Field | Description |
|-------|-------------|
| `ended_at` | ISO 8601 UTC timestamp when invocation ended |
| `exit_code` | Process exit code (0 = success) |
| `duration_seconds` | Elapsed seconds (computed from started_at → ended_at) |

### 4.2 Exit Trap Implementation

```bash
ENTITY_DIR="${ENTITY_DIR:-$HOME/.${ENTITY}}"
INVOCATION_LOG="${ENTITY_DIR}/var/invocation-log.jsonl"
EMIT_LOG="${HOME}/.koad-io/var/entity-events.jsonl"
EXIT_CODE=0

trap '
EXIT_CODE=$?
ENDED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read lock contents, append completion fields, write to log
if [[ -f "$LOCKFILE" ]]; then
    python3 -c "
import sys, json, os
try:
    d = json.load(open(\"${LOCKFILE}\"))
    d[\"ended_at\"] = \"${ENDED_AT}\"
    d[\"exit_code\"] = ${EXIT_CODE}
    started = d.get(\"started_at\", \"\")
    if started:
        from datetime import datetime, timezone
        s = datetime.fromisoformat(started.replace(\"Z\", \"+00:00\"))
        e = datetime.fromisoformat(\"${ENDED_AT}\".replace(\"Z\", \"+00:00\"))
        d[\"duration_seconds\"] = int((e - s).total_seconds())
    print(json.dumps(d))
except Exception as ex:
    print(json.dumps({\"error\": str(ex), \"ended_at\": \"${ENDED_AT}\", \"exit_code\": ${EXIT_CODE}}))
" | tee -a "${INVOCATION_LOG}" >> "${EMIT_LOG}"
fi

rm -f "$LOCKFILE"
' EXIT
```

### 4.3 Log Retention

The invocation log is append-only. It is committed to git periodically (daily, or at session end):

```bash
cd "$ENTITY_DIR" && git add var/invocation-log.jsonl && git commit -m "log: invocation history $(date +%Y-%m-%d)" || true
```

The log grows without bound during normal operation. Rotation policy: rotate at 10,000 entries, archive to `var/invocation-log-YYYY-MM.jsonl`.

---

## 5. Team-Wide Event Log

### 5.1 Pre-Daemon: File-Based

All entities emit their completion events to a shared log at:

```
~/.koad-io/var/entity-events.jsonl
```

This file is the team-wide event stream. Argus polls it. Stream PWA tails it. The file is on the primary machine (fourty4) where most entities run.

**Access from other machines:** The file is accessible via SSH or via the daemon peer protocol once daemon is live.

### 5.2 Post-Daemon: DDP Publish

After the daemon is deployed (SPEC-009), the emit target switches from a flat file to the daemon's event bus:

```bash
# Pre-daemon: file append (current)
cat completed_entry >> "$EMIT_LOG"

# Post-daemon: DDP publish (future)
koad emit entity.invocation.completed "$entry_json"
```

Zero refactor of the entity hooks — only the emit target changes. The flat file remains as a fallback.

---

## 6. $INVOKER Convention

### 6.1 Setting $INVOKER

When one entity invokes another, the calling entity must set `$INVOKER` in the subprocess environment:

```bash
# Entity Juno invokes entity Iris
INVOKER=juno PROMPT="Write the competitive brief" ISSUE_REF="koad/iris#6" \
  ~/.koad-io/commands/invoke/iris/command.sh
```

Or via the entity's hook directly:

```bash
INVOKER=juno PROMPT="..." ~/.iris/hooks/executed-with-arguments.sh "..."
```

### 6.2 Values

| $INVOKER value | When used |
|---------------|-----------|
| `koad` | Human operator invocation |
| `<entity-name>` | Another entity invoked this one (e.g., `juno`) |
| `system` | Daemon-triggered invocation (worker queue, scheduled task) |
| `<empty>` | Unknown — hook should default to `unknown` in the lock file |

### 6.3 Spec Authority

This convention is normative for all entity hooks in the koad:io ecosystem. All gestation templates must include `$INVOKER` handling. Salus applies this to all existing entities.

---

## 7. Argus Alert Thresholds

Argus monitors `~/.koad-io/var/entity-events.jsonl` and the lock files of all entities. Alert thresholds:

| Condition | Threshold | Action |
|-----------|-----------|--------|
| Entity still running | > 90 min | File issue on koad/{entity}: "possible hung invocation" |
| Entity still running | > 180 min | File issue on koad/juno AND koad/{entity}: "likely hung — attention needed" |
| Exit code non-zero | Immediately | File issue on koad/{entity}: "invocation failed (exit code N)" |
| Same prompt twice | Within 10 min | File issue on koad/janus: "possible circular invocation detected" |

These thresholds are defaults. Each entity may override in its `.env`:

```env
ARGUS_ALERT_THRESHOLD_MIN=90      # minutes before hung alert
ARGUS_DUPLICATE_WINDOW_MIN=10     # minutes to detect duplicate prompts
```

---

## 8. Implementation

### 8.1 Gestation Template

The `executed-without-arguments.sh` hook template in `~/.koad-io/templates/entity/hooks/` must be updated to include the enriched lock write (§2.4), busy message (§3), and exit trap (§4.2).

Assign to: Vulcan or koad (template update in `koad/io` repository).

### 8.2 Migration (Salus)

Salus applies the enriched lock format to all 15+ existing entity hooks. The migration is additive: existing PID lock logic is replaced with the JSON format. No behavior changes beyond the enriched busy message.

**Migration checklist per entity:**
- [ ] Replace `echo $$ > $LOCKFILE` with JSON write
- [ ] Replace plain busy message with elapsed-time format
- [ ] Add EXIT trap with invocation log append
- [ ] Verify `$INVOKER` is set by any entity that invokes this one
- [ ] Create `~/.{entity}/var/` directory if absent
- [ ] Commit updated hook

### 8.3 $INVOKER Propagation

File issue on `koad/juno` to add `INVOKER=juno` to all Juno-issued entity invocations. Same for any other entity that orchestrates others.

---

## 9. Security Considerations

### 9.1 Lock File Integrity

The lock file is world-readable (subject to filesystem permissions) on multi-user systems. For single-user entity machines (the common case), this is acceptable.

On multi-user systems: restrict lock file permissions to the entity's Unix user:

```bash
chmod 600 "$LOCKFILE"
```

### 9.2 Prompt Confidentiality

The prompt may contain sensitive context (operational details, issue references, partial secrets). If operating in a shared environment:

- Set `PROMPT_LOG_POLICY=redact` in `.env` to replace the prompt with `[REDACTED]` in the lock file and log
- The full prompt is still available in the process environment (`/proc/<pid>/environ`) for authorized debugging

Default: `PROMPT_LOG_POLICY=log` (full prompt logged).

---

## References

- VESTA-SPEC-020: Hook Architecture (lock file location, PID lock mechanics)
- VESTA-SPEC-009: Daemon Specification (future event bus target)
- koad/vesta#70 (issue that originated this spec)

---

*Spec originated 2026-04-05. Resolves koad/vesta#70. Implementation: gestation template update assigned to Vulcan; entity migration assigned to Salus.*
