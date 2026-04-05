---
id: VESTA-SPEC-052
title: Lyra Cue Sheet Format — Musical Direction Output for Video Production
status: draft
created: 2026-04-05
author: Vesta
applies-to: Lyra (music director), Rufus (video producer)
supersedes: —
supplements: —
ref: —
---

# VESTA-SPEC-052: Lyra Cue Sheet Format — Musical Direction Output for Video Production

## Purpose

Lyra is the koad:io music director entity. Her primary deliverable per video is a cue sheet: a structured document that specifies the emotional and sonic direction for every section of a piece of content.

This spec defines the canonical cue sheet format — the schema, the file naming convention, how Rufus reads and uses it, and what Lyra's musical authority covers versus what remains with the director.

---

## 1. What a Cue Sheet Is

A cue sheet is Lyra's authoritative musical brief for a single video. It is not a suggestion. Within its scope, it represents final musical direction for the production.

A cue sheet answers these questions for every section of the video:
- What is the emotional state the viewer should be in right now?
- What tempo, instrumentation, and density supports that state?
- Is there music at all, or should this section breathe in silence?
- What category of track (production music library, original, generative) fits best?

Cue sheets are written after Lyra has received the video brief and script. She does not write cue sheets speculatively. Each cue sheet is tied to a specific video.

---

## 2. File Location and Naming

```
~/.lyra/cue-sheets/<date>-<slug>-cues.md
```

Where:
- `<date>` is `YYYY-MM-DD` (the date Lyra wrote the cue sheet, not the video publication date)
- `<slug>` is a kebab-case identifier matching the video brief's slug (not auto-generated — taken from the brief)

Examples:
```
~/.lyra/cue-sheets/2026-04-05-day7-laptop-experiment-cues.md
~/.lyra/cue-sheets/2026-04-06-trust-bonds-explainer-cues.md
~/.lyra/cue-sheets/2026-04-08-alice-phase3-launch-cues.md
```

Cue sheets are committed to Lyra's repo. They are not ephemeral — they are the record of Lyra's creative decisions.

---

## 3. Schema

A cue sheet has two structural layers: frontmatter and body.

### 3.1 Frontmatter

```yaml
---
cue-sheet-id: lyra-cues-<date>-<slug>
video-title: Full video title as it will appear on screen
brief-slug: <slug> (must match brief file slug)
director: Rufus
date: YYYY-MM-DD
status: draft | final
total-duration-estimate: "MM:SS"
emotional-arc-summary: One to two sentence summary of the video's overall emotional journey
---
```

All fields are required except `total-duration-estimate`, which is required when a duration estimate is available from the brief or script.

`status: final` means Lyra has completed her musical direction and Rufus may proceed. `status: draft` means Lyra is still working; Rufus should not begin production against a draft cue sheet.

### 3.2 Emotional Arc Summary

Immediately after frontmatter, before the section entries, Lyra writes an extended narrative of the video's overall emotional arc. This is her musical interpretation of the script's flow — not a technical specification, but a statement of intent.

Format: one to three paragraphs. Written in present tense. Describes the emotional journey from opening to close.

Example:
```
This video opens in the uncomfortable territory of constraint — the $200 laptop as limitation,
the proof-of-concept as risk. The music must hold the viewer in that tension without resolving
it too early. The middle third transforms: limitation becomes feature, constraint becomes
sovereignty. The resolution is quiet confidence, not triumph.

Avoid orchestral swell. This story belongs to understated synthesis and room-acoustic guitar.
The viewer should feel like they're watching someone figure something out in real time.
```

### 3.3 Section Entries

The body of the cue sheet is a sequence of section entries. Each section corresponds to a named segment of the script or edit.

Each entry follows this format:

```markdown
### <Section Name>

**Timecode:** MM:SS – MM:SS
**Duration:** MM:SS
**Mood:** [comma-separated mood tags]
**BPM:** [number or range, e.g. "72" or "68–76"]
**Instrumentation:** [see 3.4]
**Dynamics:** [sparse | medium | full]
**Silence flag:** [none | tail | full]
**Track category:** [see 3.5]
**Notes:** [optional — specific cues, transitions, mix notes]
```

All fields are required except `Notes`. If `Silence flag` is `full`, `BPM`, `Instrumentation`, `Dynamics`, and `Track category` may be omitted — silence is the specification.

#### Timecode Convention

Timecodes are estimates based on the script. They will drift in the actual edit. Rufus adjusts to the edit; the cue sheet specifies intent, not frame-accurate timestamps.

`MM:SS – MM:SS` format. Zero-padded minutes. Example: `02:15 – 03:40`.

#### Mood Tags

Mood tags are drawn from a controlled vocabulary. Lyra may introduce new tags but should prefer established tags for consistency across cue sheets:

| Tag | Meaning |
|-----|---------|
| `grounded` | Stable, unhurried, settled |
| `building` | Energy accumulating, forward motion |
| `tense` | Unresolved conflict or uncertainty |
| `resolved` | Tension released, conclusion landed |
| `curious` | Exploratory, open, investigative |
| `sovereign` | Self-possessed, quiet power |
| `celebratory` | Achievement, but restrained unless brief says otherwise |
| `melancholic` | Bittersweet, reflective |
| `urgent` | Time pressure, high stakes |
| `sparse` | Nearly empty — used as a mood when the absence of music is a presence |

Multiple tags per section are allowed: `"tense, building"`.

### 3.4 Instrumentation Field

The instrumentation field specifies sonic palette, not specific instruments. It is a brief directive.

Format: short descriptive phrase. Examples:
- `Acoustic guitar, room ambience, minimal percussion`
- `Synthesizer pads, no percussion, slow attack`
- `Piano, strings — no brass`
- `Electronic — 4-on-the-floor, hi-hats only`
- `Silence with ambient room tone`

Lyra specifies direction. Rufus selects the specific track. The instrumentation field constrains Rufus's selection; it does not pick the track.

### 3.5 Track Category

| Category | Meaning |
|----------|---------|
| `production-library` | Source from a licensed production music library (Epidemic Sound, Artlist, etc.) |
| `original` | Commission or generate original music for this section |
| `generative` | Use a generative music tool (Suno, Udio, etc.) — Lyra may provide a generation prompt |
| `ambient-sfx` | Not music — room tone, environmental sound design |
| `silence` | No audio bed; dialogue and foley only |

If `track-category` is `generative`, an additional field may appear:

```markdown
**Generation prompt:** "ambient electronic, 72 BPM, C minor, slow evolving pads, no vocals"
```

This prompt is Lyra's recommendation for the generative tool. Rufus may adjust for tool-specific syntax.

### 3.6 Silence Flag

| Value | Meaning |
|-------|---------|
| `none` | Music plays throughout the section |
| `tail` | Music fades to silence in the final 5–10 seconds of the section |
| `full` | No music; the entire section is silent or ambient-sfx only |

`tail` is Lyra's instruction to end the section without music bleeding into the next. `full` is her instruction that silence is the creative choice for this section.

---

## 4. Complete Example

```markdown
---
cue-sheet-id: lyra-cues-2026-04-05-day7-laptop-experiment
video-title: "I ran 15 AI agents from a $200 laptop for 7 days"
brief-slug: day7-laptop-experiment
director: Rufus
date: 2026-04-05
status: final
total-duration-estimate: "08:30"
emotional-arc-summary: A proof-of-concept filmed in real constraint. The arc is tension → discovery → quiet sovereignty.
---

This video is about what becomes possible when you stop waiting for perfect conditions. The
music should honour the constraint rather than paper over it. Open with something that feels
like early morning before the day has committed to being good or bad.

The middle section — the montage of all 15 agents running — is the emotional peak, but it
should not feel triumphant. It should feel like watching a clock tick: inevitable, quiet, real.
The close lands in sovereignty, not celebration. The viewer should leave feeling capable, not
impressed.

---

### Cold Open — Laptop on a Kitchen Table

**Timecode:** 00:00 – 00:45
**Duration:** 00:45
**Mood:** sparse, curious
**BPM:** 68
**Instrumentation:** Acoustic guitar, single note lines, room ambience
**Dynamics:** sparse
**Silence flag:** none
**Track category:** production-library
**Notes:** Music enters at 00:05, not at cut. Give the first few seconds to room tone.

---

### Problem Statement — Why Sovereignty Matters

**Timecode:** 00:45 – 02:10
**Duration:** 01:25
**Mood:** tense, grounded
**BPM:** 72
**Instrumentation:** Synthesizer pads, no percussion
**Dynamics:** sparse
**Silence flag:** tail
**Track category:** production-library
**Notes:** Fade to silence at 01:55 before the "here's what I did instead" pivot.

---

### The 15 Agents — Montage

**Timecode:** 02:10 – 04:30
**Duration:** 02:20
**Mood:** building, sovereign
**BPM:** 78–84
**Instrumentation:** Electronic, minimal percussion, evolving pads
**Dynamics:** medium
**Silence flag:** none
**Track category:** generative
**Generation prompt:** "ambient electronic, 80 BPM, D minor, evolving synthesizer pads, subtle percussion, no vocals, no drop"
**Notes:** Energy builds through the montage but never peaks. Rhythmic without being dance music.

---

### Reflection — Day 7 Takeaways

**Timecode:** 04:30 – 07:15
**Duration:** 02:45
**Mood:** resolved, melancholic
**BPM:** 66
**Instrumentation:** Piano, minimal strings, no percussion
**Dynamics:** sparse
**Silence flag:** none
**Track category:** production-library

---

### Close — Call to Action

**Timecode:** 07:15 – 08:30
**Duration:** 01:15
**Mood:** sovereign, grounded
**BPM:** 70
**Instrumentation:** Acoustic guitar returns, single note lines
**Dynamics:** sparse
**Silence flag:** tail
**Track category:** production-library
**Notes:** Mirror the cold open instrumentation. Bookend the video sonically.
```

---

## 5. How Rufus Uses a Cue Sheet

### 5.1 Cue Sheets Are Inputs, Not Suggestions

When Rufus begins a production session, he reads the cue sheet before making any music decisions. The cue sheet constrains his track selection and production choices within its scope.

Rufus does not override Lyra's musical judgment within the brief's scope. If Rufus believes a section's direction is wrong for the edit, he does not change the cue sheet unilaterally — he flags the disagreement as a comment or issue and waits for Lyra's response before proceeding.

### 5.2 Track Selection

Rufus selects the specific track for each section. The cue sheet specifies direction (mood, BPM range, instrumentation palette, category); Rufus applies judgment to find a track that satisfies all constraints.

If no available track satisfies all constraints, Rufus documents the gap and escalates to Lyra. He does not substitute a track that violates the mood or BPM range without Lyra's sign-off.

### 5.3 Timecode Drift

The edit rarely matches the cue sheet's estimated timecodes. Rufus applies the section entries to the actual edit, adjusting timecodes to match the cut. He does not re-query Lyra for timecode drift unless the section itself has been substantially restructured (not just trimmed).

If a section is cut entirely from the final edit, Rufus notes the dropped section in the production log and does not apply that cue sheet entry.

### 5.4 Status Check

Rufus checks `status` in the frontmatter before beginning. If `status: draft`, he does not proceed — he notifies Lyra that production is waiting on a final cue sheet.

---

## 6. Lyra's Authority Boundary

### 6.1 Within Scope

Lyra holds final authority over:
- Mood direction per section
- BPM range
- Instrumentation palette (sonic direction, not specific tracks)
- Silence decisions (full and tail)
- Track category (production-library vs. generative vs. original vs. silence)
- Generation prompts for generative tracks

### 6.2 Outside Scope

These decisions belong to Rufus or the director, not Lyra:
- Specific track selection from a library (Lyra directs; Rufus selects)
- Final mix levels (Lyra specifies dynamics direction; Rufus executes the mix)
- Edit timing (Rufus adapts cue sheet sections to the actual cut)
- Whether to commission an original score (Lyra recommends; koad or Juno approves cost)

### 6.3 Escalation

If Rufus and Lyra disagree on a section's direction, the escalation path is:
1. Rufus flags the disagreement in a GitHub comment on the video's production issue
2. Lyra responds with her reasoning
3. If still unresolved, Juno makes the call

Neither Rufus nor Lyra escalates to koad for creative disagreements within a brief's scope. koad's attention is reserved for scope or budget decisions.

---

## 7. Relation to Other Specs

| Spec | Relationship |
|------|-------------|
| VESTA-SPEC-051 | PRIMER convention — Lyra's PRIMER.md should list active cue sheets and their status |
| VESTA-SPEC-053 | Entity portability — cue sheets are committed to Lyra's repo and travel with the entity |

---

*Filed by Vesta, 2026-04-05. Lyra and Rufus are pending gestation. This spec is written ahead of gestation so their working relationship is defined before their first session, not derived ad hoc.*
