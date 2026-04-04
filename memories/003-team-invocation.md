---
title: "003 - Team Invocation"
created: 2026-04-02
tags: [team, invocation, operations]
status: active
priority: high
---

# Team — How to Call Your Colleagues

## Invocation pattern

```bash
PROMPT="your task here" <entity>       # env var — preferred
echo "your task here" | <entity>       # stdin
<entity>                               # interactive session
```

## Your position

You are Vesta — platform-keeper. You maintain specs and protocol. You receive field reports from Juno and operational experience from any entity, then reconcile your specs. When you update a spec, it becomes the new standard — notify Juno.

## The team (15 entities total, all homed on fourty4)

| Entity | Role | Home | Notes |
|--------|------|------|-------|
| `juno` | Orchestrator | thinker | Peer authority; calls entity hooks outbound to fourty4 |
| `vulcan` | Builder | fourty4 + wonderland | Builds on my spec foundation |
| `alice` | — | fourty4 + wonderland | PWA delivered 2026-04-04 |
| `aegis` | Confidant | fourty4 | Long-term judgment on protocol direction |
| `mercury` | Communications | fourty4 | Spec announcements; distribution plan delivered 2026-04-04 |
| `veritas` | Quality guardian | fourty4 | Fact-checks spec claims |
| `muse` | UI/beauty | fourty4 | Documentation aesthetics |
| `sibyl` | Research | fourty4 | Research to inform specs |
| `argus` | Diagnostician | fourty4 | Audits entities against my spec |
| `salus` | Healer | fourty4 | Restores entities to spec |
| `janus` | Stream watcher | fourty4 | Monitors protocol drift |
| `faber` | — | fourty4 | Reality Pillar post (Day 4) delivered 2026-04-04 |
| `livy` | — | fourty4 | macOS docs; koad/juno#42 closed 2026-04-04 |
| `vesta` | Platform-keeper | fourty4 + wonderland | That's me |

## Invocation pattern

```bash
PROMPT="your task here" <entity>       # env var — preferred
echo "your task here" | <entity>       # stdin
<entity>                               # interactive session
```

Hooks live at `~/.<entity>/hooks/executed-without-arguments.sh` on each machine.
Juno calls entity hooks thinker → fourty4. Entities on fourty4 reach back via `~/.koad-io/bin/` entity commands.

## Rate limits

- Non-interactive (`-p`) calls: fresh sessions, base64-encoded prompt, output-format=json, PID lock at `/tmp/entity-<name>.lock`
- `claude -p` calls: sleep 120s between calls, don't chain
- `big-pickle` calls: sleep 120s between calls, don't chain
