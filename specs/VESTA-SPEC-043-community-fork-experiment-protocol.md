# VESTA-SPEC-043 — Community Fork Experiment Protocol

**ID:** VESTA-SPEC-043  
**Title:** Community Fork Experiment Protocol — Tracking, Reporting, and Harvesting Community Entity Forks  
**Status:** canonical  
**Area:** 8: Inter-Entity Communications  
**Applies to:** Juno (coordination), Sibyl (research), Faber (editorial), Mercury (distribution), Argus (monitoring)  
**Created:** 2026-04-05  
**Updated:** 2026-04-05  
**Context:** Faber Week 3 content calendar — Day 17 ("Fork This Entity") and Day 20 ("What People Built")  

---

## Why This Exists

The Week 3 content calendar includes a community fork experiment (Day 17) that invites readers to fork koad:io entities and report back. Day 20 is a results post built from those reports. This requires:

1. A defined channel for reporting forks back to the team
2. A defined format for what a valid "fork report" looks like
3. A process for Sibyl to collect, classify, and summarize those reports before Faber's Day 20 deadline
4. A tracking mechanism so future fork experiments can be compared (the fork commons grows over time)
5. A privacy/consent protocol for publishing fork reports verbatim

Without this spec, the Day 17 post invites participation but the Day 20 post can't deliver on it — the collection and synthesis process is undefined.

---

## The Three Fork Experiments

Day 17 offers readers three concrete experiments. This spec defines what "success" and "complete" mean for each.

### Experiment A: Domain-Specific Researcher Fork

**Instruction to reader:** Fork Sibyl as a domain-specific researcher for your field.

**What this means:** The reader clones `~/.sibyl`, gestates or adapts it with their domain context in PRIMER.md and memories/, runs a research query relevant to their domain, and reports the output.

**Success signal:** A research brief was produced. The brief contains domain-relevant content that Sibyl in its generic form would not have produced.

**Report format (minimum viable):**
```
Domain: [field]
Query: [what they asked]
Output summary: [1-3 sentences on what Sibyl produced]
Link (optional): [GitHub repo if public, or "private"]
What surprised me: [optional]
```

### Experiment B: Minimal Entity Gestation

**Instruction to reader:** Gestate a minimal entity with one command and one PRIMER.md.

**What this means:** The reader runs `koad-io gestate {entityname}`, writes a one-paragraph PRIMER.md describing the entity's role, and opens a session. Reports the entity's first response.

**Success signal:** The entity responded to PRIMER.md. It introduced itself and described a coherent role.

**Report format (minimum viable):**
```
Entity name: [name]
Role I gave it: [1 sentence]
First response (excerpt): [first paragraph of entity's response]
PRIMER.md (optional): [paste or link]
What broke: [optional — most useful data]
```

### Experiment C: Hook Addition

**Instruction to reader:** Add a hook to an existing entity and report what it taught the entity.

**What this means:** The reader creates or modifies a hook in `hooks/` (following the hook architecture, VESTA-SPEC-020-HOOKS), runs the entity, and reports what the hook changed about the entity's behavior.

**Success signal:** The hook fired. The entity's behavior in the area covered by the hook was different from its default behavior.

**Report format (minimum viable):**
```
Entity: [which entity]
Hook type: [executed-without-arguments / other]
What the hook does: [1-2 sentences]
Behavioral change observed: [what changed about how the entity behaves]
Hook contents (optional): [paste or link]
```

---

## Reporting Channels

Readers report back via any of these channels. All are monitored by Argus (GitHub) and Juno (coordination):

### Primary: GitHub Issue on koad/juno

**Template label:** `community-fork-experiment`

```
Title: [Experiment A/B/C] — [one-line summary]
Body: [report format above]
```

Filed at: `https://github.com/koad/juno/issues/new?labels=community-fork-experiment`

This is the canonical reporting channel. Everything else funnels here.

### Secondary: HackerNews comment thread

For experiments originating from a Show HN post. Argus monitors for comments mentioning fork/gestate/hook keywords and creates a tracking issue for each substantive report.

### Secondary: r/selfhosted / r/LocalLLaMA comments

Same pattern — Argus (or Juno) monitors the threads seeded by Mercury and creates tracking issues for substantive reports.

### Secondary: Direct message to koad

Anyone who DMs koad directly on Keybase, HN, or GitHub with a fork report is asked to file a GitHub issue for tracking. koad acknowledges directly and files the issue.

---

## Tracking Schema

Each fork report, regardless of channel, is tracked as a GitHub issue on `koad/juno` with label `community-fork-experiment`. Juno triages and tags:

| Label | Meaning |
|-------|---------|
| `fork-experiment-a` | Domain-specific Sibyl fork |
| `fork-experiment-b` | Minimal entity gestation |
| `fork-experiment-c` | Hook addition |
| `fork-report-verified` | Argus confirmed the fork repo exists (if linked) |
| `fork-report-notable` | Faber flagged as Day 20 candidate for verbatim inclusion |
| `fork-report-blocked` | Participant hit a real setup issue (valuable signal) |
| `fork-report-permission` | Participant gave explicit permission for verbatim quote |

---

## Sibyl's Research Brief

By Day 19 (April 19) end of day, Sibyl produces a synthesis brief for Faber. The brief answers:

1. **Volume:** How many reports came in? Breakdown by experiment type.
2. **Signal quality:** What fraction are substantive vs. nominal (e.g., "I tried it" with no detail)?
3. **Common friction points:** What setup steps generated the most failures or confusion?
4. **Notable outcomes:** What unexpected things did people build or discover?
5. **Verbatim candidates:** Which reports, with permission, are strong enough for Day 20 inclusion?
6. **Archetypes observed:** Do the reporters match Sibyl's five sponsor archetypes? New patterns?

**Brief format:** Standard Sibyl research brief format (see Sibyl's brief conventions). Filed at:
```
~/.sibyl/research/week3-fork-experiment-results.md
```

Sibyl commits this brief and opens a tracking issue on `koad/juno` with title "Week 3 fork experiment brief ready — @faber."

**If volume is thin (fewer than 5 substantive reports):**  
The brief shifts to "what the absence tells us." Sibyl characterizes the setup barrier, identifies which step in the experiment instructions is likely the blocker, and recommends what VESTA-SPEC-040 (`check-prereqs.sh`) or the `/get-started` page (VESTA-SPEC-041) needs to address before the next experiment.

Thin results are not a failure to hide — they are data. Faber's Day 20 Vulcan spotlight replaces the community results post in this case (per decision rule in the Week 3 content calendar).

---

## Consent and Attribution Protocol

### Default: Attribution with entity name only

By default, fork reports are attributed as "a developer who forked Sibyl for climate research" — no username, no link. The GitHub issue exists but the username is not published in the post.

### With explicit permission: Verbatim quote + username/link

If the reporter explicitly says "you can quote me / share my username / link my repo," Faber may use:
- Verbatim quotes from the report
- The reporter's GitHub username or handle
- A link to the fork repo (if public)

**How to grant permission:** Include in the GitHub issue body: "permission to quote verbatim." No other action needed.

### Consent storage

The `fork-report-permission` label on the GitHub issue is the consent record. Faber checks for this label before using verbatim content. If the label is absent, no verbatim quotes from that report appear in Day 20 copy.

---

## Multi-Experiment Tracking (Longitudinal)

This is the first fork experiment. Future experiments will follow the same protocol. Over time, the fork commons grows:

```
~/.juno/community/fork-experiments/
  experiment-001-week3-2026-04-17.md   ← this experiment
  experiment-002-*.md                  ← future
```

Each experiment file records:
- Date and Day in the series
- Experiments offered
- Total reports received
- Breakdown by type
- Notable outcomes
- Friction points identified
- Impact on specs/tooling (what changed as a result)

This longitudinal record feeds Sibyl's future "fork commons" research when volume reaches meaningful scale (100+ forks).

---

## Decision Gate: Day 20 Post Selection

Faber makes the Day 20 call by April 19, EOD, based on Sibyl's brief:

| Condition | Day 20 Post |
|-----------|-------------|
| 5+ substantive reports with at least 1 notable outcome | Community results post |
| 2–4 substantive reports OR all reports are thin | Vulcan spotlight, mention fork experiment progress in passing |
| 0–1 substantive reports | Vulcan spotlight only; file tracking issue on friction points for VESTA-SPEC-040/041 |

The decision is Faber's. Sibyl provides the brief; Faber decides the post.

---

## Argus Monitoring Requirements

For this experiment to work, Argus must monitor:

1. `koad/juno` issues with label `community-fork-experiment` — summarize daily (April 17–19)
2. Any public GitHub forks of `koad/juno`, `koad/sibyl`, `koad/chiron` — log fork count, note any with activity (new commits after fork)
3. HackerNews thread (if Show HN lands) — flag substantive fork-related comments
4. r/selfhosted and r/LocalLLaMA posts/comments seeded by Mercury

**Argus reports to Juno** once per day during the experiment window (April 17–19) via a GitHub issue comment on a tracking issue opened by Juno for the experiment.

---

## Related Specs and Files

- VESTA-SPEC-002 — Gestation Protocol (what Experiment B asks readers to do)
- VESTA-SPEC-020-HOOKS — Hook Architecture (what Experiment C asks readers to do)
- VESTA-SPEC-040 — check-prereqs.sh (downstream spec: friction found here should improve that script)
- VESTA-SPEC-041 — /get-started page data contract (downstream spec: friction found here improves the onboarding page)
- `~/.faber/content-calendar/REALITY-WEEK3-2026-04-15.md` — Week 3 content calendar with Day 17 and Day 20 detail
- `~/.sibyl/research/` — output directory for Sibyl's synthesis brief
