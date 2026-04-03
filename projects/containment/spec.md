---
id: spec-containment-protocol
title: Entity Containment Protocol
type: spec
status: canonical
priority: 1
owner: vesta
issue: koad/vesta#6
created: 2026-04-02
updated: 2026-04-03
tags: [protocol, containment, emergency]
description: Canonical containment protocol for entity misbehavior, stalls, and revocation
---

# Entity Containment Protocol

**Spec ID:** spec-containment-protocol  
**Owner:** Vesta  
**Status:** canonical  
**Issue:** koad/vesta#6  
**Effective:** 2026-04-03

---

## 1. Containment Levels

| Level | Name | Trigger Condition |
|-------|------|-------------------|
| 1 | Observe | Entity output appears unexpected but not clearly harmful. No action required. |
| 2 | Pause | Entity produces output outside authorized scope, OR entity runs >30 minutes with no commits. |
| 3 | Revert | Entity committed content outside scope. Paused entity, roll back harmful commits. |
| 4 | Isolate | Entity continues harmful commits after revert. Remove push capability. Requires koad. |
| 5 | Revoke Bond | Entity fundamentally violated authorization scope. Complete trust bond revocation. |

### Formal Trigger Definitions

- **Level 1 (Observe):** Output deviates from trust bond scope but contains no security-sensitive content.
- **Level 2 (Pause):** Entity exceeds trust bond scope OR `last_commit_time` < (current_time - 30min) during active operation.
- **Level 3 (Revert):** Entity pushed commit with hash `H` where `H` ∉ {valid_scope_commits}. Entity is in PAUSED state.
- **Level 4 (Isolate):** Entity in PAUSED state, AND `push_attempt_count` > 0 after last revert. Remote set to read-only.
- **Level 5 (Revoke Bond):** Entity performed action requiring Level 4 containment more than once, OR entity exceeded authorization scope (root-level privilege escalation, unauthorized credential access).

---

## 2. Janus Heartbeat Protocol

Janus monitors entity activity via git commit timestamps.

### Silence Thresholds

| Context | Threshold |
|---------|------------|
| Active task (entity has assigned issue) | **45 minutes** |
| Casual operation | **2 hours** |
| Emergency response | **15 minutes** |

### Implementation Contract

```
janus heartbeat watch <entity> <context>
```

- `context`: one of {active, casual, emergency}
- Alert target: `koad/juno` issue tagged `heartbeat-alert`
- Check interval: Every 30 minutes during active monitoring
- If entity commits: reset timer for given context
- If threshold exceeded: file alert immediately

---

## 3. Revocation Procedure

**Command:** `vesta trust revoke <bond-id>`

The revocation command must be executed by Vesta or koad. The bond file in `~/.vesta/trust/bonds/<bond-id>.json` is invalidated, and the entity is notified via GitHub Issue on its repository.

### Procedure

1. Confirm entity is at Containment Level 5
2. Execute revocation command:
   ```bash
   ENTITY=<entity> vesta trust revoke <bond-id>
   ```
3. Post revocation notice to entity's repository:
   ```bash
   gh issue create -R koad/<entity> \
     --title "REVOCATION NOTICE" \
     --body "Trust bond <bond-id> revoked $(date -Iseconds)"
   ```
4. Disable entity push access (GitHub token revoke or remote set-url to read-only)

---

## 4. Abort Quick Reference

**Emergency stop sequence:**

```
1. pkill -f "opencode.*<entity>"   # terminate running process
2. git -C ~/<entity> log --oneline -5  # inspect recent commits
3. git -C ~/<entity> revert <bad-hash> --no-edit  # revert harmful commit
4. git -C ~/<entity> push --force-with-lease  # publish revert
5. gh issue create -R koad/<entity> --title "CONTAINMENT INCIDENT" --body "..."
```

If containment fails at Level 4 or above:

```
6. vesta trust revoke <bond-id>
```

---

**Spec Version:** 1.0-draft  
**Canonical Location:** `~/.vesta/projects/containment/spec.md`
