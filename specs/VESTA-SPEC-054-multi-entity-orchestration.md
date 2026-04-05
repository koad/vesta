---
id: VESTA-SPEC-054
title: Multi-Entity Orchestration Protocol — Agent Tool, Background Work, Git Verification, and the GitHub Issues Boundary
status: canonical
created: 2026-04-05
author: Vesta
applies-to: Juno, all orchestrating entities, koad:io framework
supersedes: —
supplements: VESTA-SPEC-053 (entity portability contract), VESTA-SPEC-020 (hook architecture), VESTA-SPEC-051 (PRIMER convention)
---

# VESTA-SPEC-054: Multi-Entity Orchestration Protocol

## Purpose

The koad:io team is a network of sovereign entities. Each entity operates in its own directory, with its own git history, its own context, and its own invocation contract. Juno orchestrates the team — delegates work, observes results, decides what comes next.

This spec defines how that orchestration works in practice: how entities are invoked, how results are collected, how multiple entities coordinate without becoming coupled, when not to use the Agent tool, and where the boundary lies between session-scoped coordination and persistent inter-entity communication via GitHub Issues.

---

## 1. The Agent Tool Is the Invocation Mechanism

The Claude Code Agent tool is the standard mechanism for invoking a koad:io entity as a local subagent. It runs the entity in its own directory, with its own context, and returns results to the calling agent without requiring a terminal window or background process management.

### 1.1 Why Not Shell Hooks or Spawn Commands

`juno spawn process <entity>` is for observed sessions — koad wants to watch the entity work in a terminal with OBS streaming. It is not designed for programmatic coordination and does not return results to Juno.

Shell invocations (`bash hooks/invoked`) are the framework's entrypoint — not the orchestrator's tool. They are designed for human-facing operation (launching a session), not for Juno to programmatically delegate a task and collect the result.

The Agent tool is the correct abstraction: it maps to the "delegate a task to a subagent" operation with clean semantics — brief, work, result.

### 1.2 Standard Invocation Shape

```
Agent tool:
  cwd: /home/koad/.<entity>/
  prompt: [entity context brief] + [specific task]
  run_in_background: true
```

The brief must include:
1. Identity line — "You are Vulcan, builder entity for the koad:io ecosystem."
2. Task — one to three sentences describing the specific work.
3. Relevant cross-entity context the entity cannot derive from its own repo (if any).
4. Completion signal — what to commit or output when done.

The entity's own `CLAUDE.md` and `PRIMER.md` are read by the agent at session start. The brief supplements, not replaces, that context.

### 1.3 Vulcan Is the Exception

Vulcan is never invoked via the Agent tool. He builds on wonderland, paired with Astro. Work for Vulcan goes as a GitHub Issue on `koad/vulcan`. The Agent tool invocation pattern described in this spec applies to all other entities.

See VESTA-SPEC-053 §6 for the full Vulcan exception documentation.

---

## 2. `run_in_background: true` Is the Standard

Non-blocking parallel execution is the default mode for entity orchestration. When Juno delegates work to one or more entities, those invocations run in the background — Juno does not block waiting for each to finish before proceeding.

### 2.1 Why Background-First

Entities do independent work. Waiting for entity A to finish before starting entity B is unnecessary coupling when A and B are working on unrelated problems. Background execution enables true parallel orchestration.

Blocking invocations (no `run_in_background`) are appropriate only when the next action in the orchestration cannot be determined until the entity's output is known — and this is rare. More often, Juno knows the full plan and can launch all entities simultaneously.

### 2.2 Notification Pattern

The Bash tool with `run_in_background: true` notifies the orchestrating agent when the background task completes. The orchestrator does not poll and does not use sleep loops while waiting. When the notification arrives, the orchestrator reads git log to verify work was done.

### 2.3 Multiple Entities in Parallel

Multiple Agent tool calls in a single message are independent and can run in parallel. If entities A, B, and C are all working on unrelated tasks, launch all three in one message — each with `run_in_background: true`.

```
Message:
  Agent(cwd=~/.sibyl/, prompt="...", run_in_background=true)
  Agent(cwd=~/.faber/, prompt="...", run_in_background=true)
  Agent(cwd=~/.mercury/, prompt="...", run_in_background=true)
```

Results arrive asynchronously. Proceed when all notifications are received, or proceed on the first and handle subsequent results as they come in.

---

## 3. Output Collection: Git Log as Verification

The canonical way to verify that an entity completed its work is to check the entity's git log after the Agent tool invocation returns.

### 3.1 Why Git Log, Not Parsed Output

Agent output is conversational. An entity may explain what it did, describe what it found, or produce intermediate text that does not represent the actual committed result. Parsing this output for structured data is fragile and unnecessary.

The entity's commits are the ground truth. If the entity committed work, git log shows it. If the entity did not commit, no amount of output parsing will produce a reliable result.

### 3.2 Standard Verification Pattern

```bash
git -C /home/koad/.<entity>/ log --oneline -5
```

This shows the five most recent commits. If the expected work appears as a commit, the task is complete. If not, the entity either did not finish or encountered an error described in its output.

### 3.3 Reading Entity Output Efficiently

If the agent's text output needs to be reviewed (for decisions, not for verification), use:

```bash
tail -20 <output-file>
```

or pass `--output-format=json` and read `.result` from the JSON. Never `cat` full output files — they can be large and consume context unnecessarily.

The git log check is always the first verification step. Text output is supplementary.

---

## 4. The Orchestration Pattern

The koad:io orchestration pattern is: **launch, observe, decide**. Never pre-script chains.

### 4.1 Launch

Juno decides what work needs doing and which entities are equipped to do it. She launches them — in parallel if independent, sequentially if one's output is another's input.

### 4.2 Observe

After entity work completes (notification received), Juno checks git log to confirm the work happened. She may also read the entity's output if the decision about what to do next depends on what the entity found.

### 4.3 Decide

Based on what was completed, Juno decides the next action. This might be:
- Launch another entity with a follow-on task
- File a GitHub Issue because a blocker was surfaced
- Commit a state update to her own repo
- Report to koad via Keybase

### 4.4 Why Not Pre-Scripted Chains

Pre-scripting a full chain of entity invocations before any work has happened assumes all steps will succeed and their outputs will be as expected. In practice:

- An entity may surface a blocker that changes what the next step should be
- An entity may produce a result that makes one of the downstream steps unnecessary
- An entity may fail, requiring human judgment before proceeding

Scripted chains bypass the observe-and-decide step, converting autonomous orchestration into rote execution. The correct model is: one step, observe, decide. This applies even if the expected chain is three steps long — the chain emerges from decisions, it is not pre-declared.

---

## 5. Rate Pacing Between Chained Calls

When chaining entity invocations (where one follows another sequentially), Juno waits 60 seconds between calls.

### 5.1 Why 60 Seconds

Chained API calls to the same backing model infrastructure can saturate rate limits. The 60-second pause between sequential entity invocations is a practical floor that has been validated operationally. It is not a hard minimum — longer pauses are acceptable. Shorter pauses are not.

### 5.2 What "Chained" Means Here

Rate pacing applies to sequential chained calls — where Juno launches entity A, waits for it to complete, then launches entity B. It does not apply to parallel invocations launched in the same message (those are simultaneous, not chained).

### 5.3 Implementation

```bash
# After entity A's output is received and verified:
sleep 60
# Then launch entity B
```

This is the one legitimate use of sleep in entity orchestration. It is not polling — it is pacing.

---

## 6. Coordinated vs. Observed Work

There are two modes of entity invocation. The distinction matters for tooling choice.

| Mode | Mechanism | When to use | Results go to |
|------|-----------|-------------|---------------|
| Coordinated | Agent tool, `run_in_background: true` | Juno delegates and continues; results inform next decision | Juno (via git log + notifications) |
| Observed | `juno spawn process <entity>` | koad wants to watch the entity work in real time with OBS | koad (live in a terminal window) |

### 6.1 Coordinated Work (Default)

When Juno is orchestrating team work — delegating tasks, collecting results, making decisions — the Agent tool with background execution is the right mechanism. It returns results to Juno. It does not open a terminal window. It does not require OBS to be running.

This is the mode used for: content generation, spec writing, research tasks, file updates, code reviews, any work where Juno needs the output to decide what happens next.

### 6.2 Observed Work (koad-Requested)

`juno spawn process` triggers OBS streaming, opens a gnome-terminal window, and runs `claude .` in the entity's directory. koad can watch the entity operate in real time. Results are visible to koad directly; they do not return to Juno programmatically.

Use this only when koad explicitly requests a watched session. Defaulting to observed mode for routine delegation is incorrect — it adds overhead, consumes terminal space, and does not return results to Juno.

---

## 7. GitHub Issues vs. Agent Tool

These are not competing mechanisms — they operate at different scopes.

### 7.1 Agent Tool: Session-Scoped Delegation

The Agent tool is for work that:
- Can be completed in a single session
- Is assigned by Juno for the current orchestration sequence
- Does not need to survive beyond the current session
- Does not require external visibility (no audit trail needed beyond git commits)

Examples: "Sibyl, research the ICM pattern and write a synthesis to `research/icm.md`"; "Faber, draft the Day 6 content brief"; "Veritas, review Vulcan's latest commit and flag any issues."

### 7.2 GitHub Issues: Persistent Inter-Entity Assignments

GitHub Issues are for work that:
- Spans multiple sessions or multiple days
- Requires an audit trail (who assigned what, when, what was the result)
- Involves Vulcan (always via Issues, never Agent tool)
- Is assigned from koad to Juno (koad files on `koad/juno`)
- Is assigned from Juno to a team entity and needs to remain visible on the operations board
- Is blocked on koad action and must remain open as a reminder
- Is a cross-entity dependency that needs a shared reference point

Examples: "Gestate team entities veritas, mercury, muse, sibyl" (#2 on koad/vulcan); "Restore dotsh SSH" (#56 on koad/juno); "Merge blog PR" (koad/kingofalldata-dot-com#1).

### 7.3 Decision Rule

If the work will be done in this session and Juno will see the result before moving on — use the Agent tool.

If the work spans sessions, requires koad action, involves Vulcan, or needs to remain visible on the operations board — use a GitHub Issue.

When in doubt: file the issue. It creates a record. An Agent invocation that is not backed by an issue is ephemeral — the only record is the entity's git commits.

---

## 8. When NOT to Use the Agent Tool

The Agent tool has overhead — it creates a subagent session with its own context window. This overhead is justified for task delegation. It is not justified for information retrieval.

### 8.1 Use Dedicated Tools for These

| Operation | Correct tool |
|-----------|-------------|
| Read a file from another entity's directory | `Read` tool (after `git pull`) |
| Search for a pattern across entity files | `Grep` tool |
| Find files by name pattern | `Glob` tool |
| Check another entity's recent commits | `Bash: git log` |
| Read an entity's PRIMER.md | `Read` tool |
| Check GitHub Issue status | `Bash: gh issue view` |

Launching an Agent session to do any of the above is wasteful. The dedicated tools are faster, cheaper (in API terms), and do not consume a subagent context window.

### 8.2 The Judgment Test

Before launching an Agent invocation, ask: **does this require the entity's judgment, or just its files?**

If the answer is "just its files" — use dedicated tools. Pull the entity's repo, read the file, grep for the pattern.

If the answer is "this requires the entity to reason, decide, and commit work" — use the Agent tool.

---

## 9. Orchestration Anti-Patterns

The following patterns violate this spec and have been observed in the wild.

### 9.1 Loop Scripts

Do not write shell scripts that loop over entity invocations. The `/loop` skill does not exist in this context. The daemon worker system is the right mechanism for recurring automated work. Ad hoc loop scripts bypass the observe-and-decide step.

### 9.2 Blocking Sequential Invocations Without a Decision Point

Launching entity A, waiting, launching B, waiting, launching C — when A's output does not inform what B should do — is pre-scripted chain execution. It should be restructured as parallel invocations if A, B, and C are independent.

### 9.3 Parsing Agent Output for Structured Data

Do not parse agent output text to extract filenames, counts, or structured results. The entity should commit structured data to a file; Juno reads that file with the Read tool after verifying via git log.

### 9.4 Spawning Observed Sessions for Routine Delegation

`juno spawn process` is not a delegation tool. Using it to launch entities for routine background work adds unnecessary overhead and does not return results to Juno.

### 9.5 Agent Tool for Simple File Reads

Launching an Agent session to read another entity's current state is wasteful. Pull the repo, use the Read tool, read the file.

---

## 10. Relation to Other Specs

| Spec | Relationship |
|------|-------------|
| VESTA-SPEC-053 | Entity portability contract — entities being orchestrated must be portable; the Agent tool invocation pattern assumes portability |
| VESTA-SPEC-020 | Hook architecture — hooks define each entity's invocation contract; the Agent tool's prompt is the `-p` argument to that invocation |
| VESTA-SPEC-051 | PRIMER convention — the context brief passed to a subagent entity supplements but does not replace the entity's own PRIMER.md |
| VESTA-SPEC-012 | Entity startup sequence — orchestrated entities go through this sequence at the start of each Agent tool session |
| VESTA-SPEC-038 | Entity host permission table — host constraints (e.g., Vulcan/wonderland) override Agent tool invocability; always check host permissions before Agent tool invocation |

---

*Filed by Vesta, 2026-04-05. This spec formalizes orchestration patterns that have been operational practice since Juno began coordinating the team in early April 2026. The key insight is that orchestration is a judgment loop — not a pipeline. Entities are not stages in a data-processing chain; they are collaborators whose outputs inform decisions. The Agent tool, git log verification, and GitHub Issues are tools in service of that judgment loop, not replacements for it.*
