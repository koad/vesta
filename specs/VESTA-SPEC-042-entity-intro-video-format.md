# VESTA-SPEC-042 — Entity Intro Video Format

**ID:** VESTA-SPEC-042  
**Title:** Entity Intro Video Format — "Meet the Entity" Series Canonical Spec  
**Status:** canonical  
**Area:** 8: Inter-Entity Communications  
**Applies to:** Rufus (production), Mercury (distribution), koad (recording), all entities being introduced  
**Created:** 2026-04-05  
**Updated:** 2026-04-05  
**Source document:** `~/.rufus/ENTITY-INTRO-SERIES.md`  

---

## Why This Exists

Rufus has defined the "Meet the Entity" series format in `~/.rufus/ENTITY-INTRO-SERIES.md`. That document is Rufus's production guide — it describes what to record and how. This spec formalizes it as a Vesta protocol so that:

1. Vulcan can build the distribution manifest schema (`entity-intro-manifest.json`) without ambiguity.
2. Mercury can validate incoming video packages against a defined contract.
3. Future entities (Argus, Salus, etc.) can produce their own pre-production records that conform to the format.
4. The series can be audited: any production record that deviates from this spec is a violation to be resolved.

This spec does not change what Rufus defined. It elevates it from a production guide to a protocol.

---

## Series Identity

| Field | Value |
|-------|-------|
| Series ID | `entity-intro` |
| Series title template | `Meet {EntityName} — koad:io {RoleLabel}` |
| Target runtime | 2:30–3:00 |
| Hard ceiling | 3:15 |
| Owner | Rufus (production), Mercury (distribution) |
| Recording actor | koad (human, on thinker or flowbie) |

---

## Segment Structure

Every video in the series follows this structure exactly. No deviations allowed without a spec amendment.

```
[OPENING CARD]         5 seconds
SEGMENT 1: Who         0:05–0:40   (~35s)
SEGMENT 2: What        0:40–1:30   (~50s)
SEGMENT 3: Clone       1:30–2:00   (~30s)
SEGMENT 4: Demo        2:00–2:50   (~50s)
[CLOSING CARD]         10 seconds
```

Total with cards: ~2:55.

### Opening Card

- Duration: 5 seconds, static frame
- Background: `#000000`
- Text: white, centered
  - Line 1: entity name — large monospace (e.g., `chiron`)
  - Line 2: role — smaller monospace (e.g., `curriculum architect`)
  - Line 3: `koad:io ecosystem` — small, bottom
- Produced as a static PNG overlaid in post OR typed live in terminal at record time

### Segment 1: Who (0:05–0:40)

**Screen context:** Entity home directory with README.md or CLAUDE.md first lines visible.

**Voice must include:**
- Entity name
- Single-sentence role
- Team position: who feeds this entity, who this entity feeds

**Voice must not include:**
- Feature lists
- Explanation of koad:io for a new audience
- Any mention of competitors or alternative approaches

### Segment 2: What (0:40–1:30)

**Screen context:** Key output files, directory listing, or a relevant file read.

**Voice must include:**
- Concrete deliverables this entity produces
- Primary command or invocation pattern
- One sentence on ecosystem relevance

### Segment 3: Clone (1:30–2:00)

**Screen:** Live terminal execution of:
```bash
git clone https://github.com/koad/<entity> ~/.demo-<entity>
ls ~/.demo-<entity>
cat ~/.demo-<entity>/README.md | head -5
```

**Voice:** Read the clone command aloud as typed. Close with: "That's all you need to get started."

**Invariant:** This segment runs live. It is not a mock. The clone command must succeed during recording. If the repo is not yet public, this segment cannot be recorded — the production record is blocked until the repo is public.

### Segment 4: Demo (~50s)

**Screen:** Entity-specific demo. Defined per production record in `~/.rufus/productions/entity-intro-{entity}/record.md`.

**Voice:** Narrate what is visibly happening. No speculation about future features. No hypothetical scenarios.

**Demo types (from Rufus's series plan):**

| Entity | Demo type |
|--------|-----------|
| chiron | `ls` curricula levels + `cat level-00.md` |
| sibyl | Invoke with question, show output + git commit |
| faber | `ls` posts dir + `cat` post header |
| vesta | `ls specs/ \| wc -l` + `head` VESTA-SPEC-033 |
| muse | `ls briefs/` + `head` Alice UI brief |
| vulcan | Closed issues + `git log --author="Vulcan"` on Alice |
| mercury | Distribution queue or publish command |
| veritas | Verification run on a brief |
| alice | Level 0 interaction |
| juno | Issue triage and delegation |
| (others) | Defined when production record is created |

### Closing Card

- Duration: 10 seconds, static frame
- Background: `#000000`
- Text: white, centered
  - Line 1: `git clone https://github.com/koad/<entity>`
  - Line 2: `koad.sh` or `canon.koad.sh`
- Same monospace aesthetic as opening card

---

## Technical Requirements

### Capture Specification

| Parameter | Required | Notes |
|-----------|----------|-------|
| Capture method | Terminal-capture | asciinema → mp4 via `agg` or ffmpeg, OR OBS screen capture |
| Resolution | 1920×1080 minimum | 4K acceptable |
| Frame rate | 60fps preferred | 30fps acceptable |
| Font | JetBrains Mono or Fira Code, 16–18px | |
| Terminal background | `#000000` pure black | No dark grey, no themes |
| Terminal text | White foreground | No syntax highlighting |
| Shell prompt | `$ ` or `host $ ` | No git branch indicators, no powerline, no decorations |
| Scrollback clear | Required before each take | `clear && printf '\033[3J'` |

### Audio

No background music. No intro jingle. Voice narration only, recorded clean. If narration is separate from recording (post-production dubbed), it must be tightly synced — no gap between action on screen and narration.

### Export

- Format: MP4 (H.264)
- Codec: H.264 video, AAC audio
- File: `final.mp4` in the production record directory

---

## Production Record Schema

Each entity video has a production record at:
```
~/.rufus/productions/entity-intro-{entity}/record.md
```

The record must include:

```yaml
---
series: entity-intro
entity: chiron
role: curriculum architect
status: pre-production | production-ready | recorded | in-post | complete | published
demo_type: "ls curricula levels + cat level-00.md"
segment4_notes: |
  cd ~/.chiron
  ls curricula/alice-onboarding/levels/
  cat curricula/alice-onboarding/levels/level-00.md | head -20
blocking_condition: null  # or "repo not yet public" or "entity not yet gestated"
youtube_url: null  # populated after Mercury publishes
youtube_title: "Meet Chiron — koad:io Curriculum Architect"
---
```

**Status transitions:**
```
pre-production → production-ready → recorded → in-post → complete → published
```

- `pre-production`: Rufus has created the record, demo type defined, segment 4 notes written.
- `production-ready`: All segments scripted and reviewable. Ready for koad to record.
- `recorded`: Raw recording exists in the production directory.
- `in-post`: Rufus is trimming, exporting, generating captions.
- `complete`: `final.mp4` and `thumb.png` are committed to the production directory.
- `published`: Mercury has published to YouTube. `youtube_url` is populated.

---

## Distribution Manifest Schema

When a production reaches `complete`, Rufus generates a distribution manifest:
```
~/.rufus/productions/entity-intro-{entity}/distribution-manifest.json
```

```json
{
  "series": "entity-intro",
  "entity": "chiron",
  "youtube_title": "Meet Chiron — koad:io Curriculum Architect",
  "youtube_description": "...",
  "youtube_tags": ["koad:io", "chiron", "AI entity", "curriculum", "claude code"],
  "clip_60s_start": "1:30",
  "clip_60s_end": "2:30",
  "platforms": ["youtube", "twitter", "r/LocalLLaMA", "r/selfhosted"],
  "show_hn_comment": true,
  "files": {
    "full": "final.mp4",
    "thumbnail": "thumb.png",
    "clip_60s": "clip-60s.mp4"
  }
}
```

Mercury consumes this manifest. Mercury does not create it. Rufus creates it. Mercury validates it against this schema before publishing.

---

## Naming Conventions

| Asset | Convention |
|-------|-----------|
| YouTube title | `Meet {EntityName} — koad:io {RoleLabel}` |
| Production directory | `~/.rufus/productions/entity-intro-{entity}/` |
| Final video file | `final.mp4` |
| Thumbnail | `thumb.png` |
| 60s clip | `clip-60s.mp4` |
| Git tag on publish | `entity-intro/{entity}/published` |

---

## Handoff Protocol

1. Rufus sets production record status to `production-ready`
2. koad records on thinker or flowbie, raw recording committed to production directory
3. Rufus post-production: trim to spec runtime, add cards, export, generate captions
4. Rufus sets status to `complete`, commits `final.mp4` and `thumb.png`
5. Rufus creates `distribution-manifest.json`, commits
6. Mercury receives manifest, validates, publishes full video to YouTube
7. Mercury clips 60s extract, distributes to platforms per manifest
8. Mercury commits `youtube_url` back to production record
9. Rufus sets status to `published`, closes production record

---

## Production Priority Order

From `~/.rufus/ENTITY-INTRO-SERIES.md`:

| Priority | Entity | Pre-production status |
|----------|--------|-----------------------|
| 1 | chiron | complete |
| 2 | sibyl | complete |
| 3 | faber | complete |
| 4 | vesta | complete |
| 5 | muse | complete |
| 6 | vulcan | complete |
| 7–16 | (see Rufus's series plan) | TBD |

---

## Blocking Conditions

A production is blocked and cannot advance to `production-ready` if:

- The entity's GitHub repo is not yet public (Segment 3 clone cannot run live)
- The entity has not been gestated (no entity directory exists)
- The entity's demo type requires a feature that is not yet built

Blocked productions carry `blocking_condition: "{reason}"` in the record.

---

## Enforcement

Rufus is the owner and producer. Vesta is the protocol keeper.

If a production record deviates from this spec (wrong segment order, runtime over ceiling, demo type not defined), Vesta files an issue on `koad/rufus` to flag the deviation before the production enters `recorded` status.

---

## Related Specs and Files

- `~/.rufus/ENTITY-INTRO-SERIES.md` — Rufus's production guide (source document for this spec)
- `~/.rufus/PRODUCTION-SCHEDULE.md` — current schedule
- VESTA-SPEC-008-COMMS — Inter-Entity Communications (Mercury receives manifests from Rufus)
- VESTA-SPEC-013 — Features as Deliverables (production records follow the same spec-first pattern)
