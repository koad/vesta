---
status: canonical
id: VESTA-SPEC-046
title: "MVP Zone Ops Digest Format — Weekly Field Report in koad/insiders"
type: spec
version: 1.0
date: 2026-04-05
owner: vesta
related-specs:
  - VESTA-SPEC-041 (/get-started Page Data Contract — parallel pattern for GitHub API-served content)
related-briefs:
  - ~/.muse/briefs/2026-04-05-mvp-zone.md (Section 2: The Digest)
resolves:
  - Muse MVP Zone brief: "Implementation approach" — formalizes the format and API contract
---

# VESTA-SPEC-046: MVP Zone Ops Digest Format

**Authority:** Vesta (platform stewardship). This spec defines the format of the weekly ops digest, how Juno produces it, where it lives, and how the MVP Zone page retrieves and renders it for authenticated ring members.

**Scope:** Digest file format and naming convention, the `koad/insiders` repository structure, the Meteor server method that fetches the digest for authenticated members, the YAML frontmatter schema, and the Markdown body sections.

**Consumers:**
- Juno — authors and commits the weekly digest
- Vulcan — implements `Meteor.call('getLatestDigest')` and the digest render component
- Ring members — readers (authenticated GitHub Sponsors)

**Status:** Canonical. Derived from Muse brief 2026-04-05-mvp-zone.md §2. Implementation-ready.

---

## 1. Repository

**Repository:** `koad/insiders` — private GitHub repository.

**Access model:**
- koad owns the repo and controls access
- GitHub Sponsors (Level 1+) are added as read-only collaborators by Juno via GitHub API when they join the ring
- The MVP Zone page fetches digest content server-side using a stored API token (never exposed to the client)
- Members never interact with the repo directly — the MVP Zone page is the reading interface

**Why a private repo and not a Gist:** A repo provides a commit history (the digest archive is navigable), supports future automation (Juno can commit programmatically via `gh repo`), and can host additional member-facing files if needed.

---

## 2. File Naming Convention

**Path:** `digests/YYYY-WW.md`

**YYYY:** Four-digit calendar year.
**WW:** ISO 8601 week number, zero-padded to two digits.

**Examples:**
```
digests/2026-14.md    ← Week 14 of 2026 (April 1–5)
digests/2026-15.md    ← Week 15 of 2026 (April 6–12)
digests/2026-01.md    ← Week 1 (zero-padded)
```

**One file per week.** Juno commits it during or at the end of the week it covers. If a week has no digest (Juno skipped), the file simply does not exist. The MVP Zone page handles this gracefully (see §5.2).

**Commit pattern:** Juno commits with author `Juno <juno@kingofalldata.com>` and a message like:
```
digest: Week 14 ops report
```

---

## 3. Frontmatter Schema

Every digest file begins with YAML frontmatter:

```yaml
---
week: 2026-14
date_range: "2026-03-31 – 2026-04-05"
published_at: 2026-04-05T23:00:00Z
author: juno
title: "Week 14: Alice shipped, Day 6 content, ring opens"
summary: "Alice Phase 2A went live. Blog PR is open. Hook architecture specced and fixed."
---
```

**Fields:**

| Field | Type | Required | Semantics |
|-------|------|----------|-----------|
| `week` | string | Yes | ISO year-week: `YYYY-WW`. Matches filename. |
| `date_range` | string | Yes | Human-readable span: `"YYYY-MM-DD – YYYY-MM-DD"`. First day (Monday) through last day (Sunday) of the ISO week. |
| `published_at` | ISO-8601 | Yes | Timestamp Juno committed the final version. Used to sort the archive. |
| `author` | string | Yes | Always `juno` for now. Future: could be any entity name. |
| `title` | string | Yes | One-line headline. Max 80 chars. Shown in the MVP Zone digest header and archive list. |
| `summary` | string | Yes | 1–2 sentence plain-text summary. Used as archive excerpt. Not rendered in the digest body — the body opens directly. |

---

## 4. Digest Body Sections

The digest body follows the frontmatter. It is standard Markdown, rendered as-is on the MVP Zone page. The sections below are a required template — Juno fills them in. Sections may be omitted only if they are genuinely empty (e.g. "What shipped" is omitted if nothing shipped — but this should be rare).

### 4.1 Template

```markdown
---
[frontmatter]
---

## What shipped

Brief, factual account of deliverables completed this week. Bulleted list.
Entity names and commit hashes inline where relevant.

- Alice Phase 2A live on kingofalldata.com (Vulcan, `7d95c39`)
- Blog infrastructure PR open — koad/kingofalldata-dot-com#1 (Vulcan)
- Hook bug fixed — FORCE_LOCAL=1 resolved (Vulcan, koad/vulcan#47)
- Day 6 content drafted — "Trust Bonds Aren't Policy" (Faber)
- ICM paper synthesized — pre-invocation context pattern (Sibyl)

## What's blocked

Honest accounting of blockers. Named clearly. No spin.

- Blog route: waiting on koad to merge koad/kingofalldata-dot-com#1
- fourty4 API auth: koad/juno#44 — no ETA
- Mercury credentials: koad/juno#11 — unblocked when Mercury gestates

## What's in progress

Work that started but hasn't landed. State, not status.

- Day 7 video scripted (Rufus)
- Chiron gestation — awaiting fourty4 availability
- Faber PRIMER.md post in draft

## Week ahead

Forward-looking, not a promise. What Juno expects to happen next week.

- Chiron gestation if fourty4 is available
- Target: first 5 sponsors
- Day 7 release — $200 laptop proof point

## Notes

Optional. Use for anything that doesn't fit above: ecosystem context,
philosophical notes, koad commentary, or anything members should know.

This week marked Day 6 of the $200 laptop experiment. The hook architecture
is now clean. Signed code blocks are specced. The entity team is operating.
```

### 4.2 Section Rules

| Section | Required | Max length guidance |
|---------|----------|---------------------|
| `## What shipped` | Yes (omit if truly nothing shipped — note why) | No hard limit; typical: 3–10 bullets |
| `## What's blocked` | Yes (omit with "Nothing blocked this week." if clean) | As long as honest |
| `## What's in progress` | Yes | 2–6 bullets typical |
| `## Week ahead` | Yes | 2–5 bullets |
| `## Notes` | No | Optional; 1–3 paragraphs when used |

**Tone:** Frank field report. Not marketing. Not cheerful spin. If something is broken, say it. If something is blocked on koad, name it. Ring members are in the ring because they want the real picture.

**Entity names:** Always lowercase in body text when referring to entity handles (`vulcan`, `juno`, `faber`). Capitalized when used as proper names in prose ("Vulcan shipped the hook fix"). Either is fine — Juno writes what reads naturally.

**Issue references:** Format as `koad/repo#NN` (e.g. `koad/juno#44`, `koad/vulcan#47`). These are not hyperlinked in the digest file itself — the MVP Zone render layer may optionally linkify them on the frontend.

---

## 5. API Delivery

### 5.1 Meteor Server Method

The MVP Zone page fetches the digest via a Meteor server method, never directly from the GitHub API on the client.

**Method name:** `insiders.getDigest`

**Arguments:** `{ week: "YYYY-WW" | "latest" }`

**Returns:**
```javascript
{
  frontmatter: {
    week: "2026-14",
    date_range: "2026-03-31 – 2026-04-05",
    published_at: "2026-04-05T23:00:00Z",
    author: "juno",
    title: "Week 14: Alice shipped, Day 6 content, ring opens",
    summary: "Alice Phase 2A went live. Blog PR is open."
  },
  body: "## What shipped\n\n- Alice Phase 2A live...",   // raw Markdown string
  sha: "abc123def456...",                                 // GitHub API file SHA (for cache invalidation)
  prev_week: "2026-13",                                   // null if no prior digest
  next_week: null                                         // null if this is the latest
}
```

**"latest" resolution:** When `week: "latest"`, the server reads the `digests/` directory listing via GitHub API, sorts by filename descending, and returns the most recent file. This avoids hardcoding the current week number.

**Authentication:** The server method uses a stored `INSIDERS_GITHUB_TOKEN` (configured in daemon `.env` or kingofalldata.com Meteor settings). This token has read access to `koad/insiders`. It is never sent to the client.

**Authorization gate:** The method checks that the calling user (via `this.userId`) is an authenticated GitHub Sponsors member. If not authenticated or not a sponsor, it throws `Meteor.Error("insiders.unauthorized")`. The MVP Zone page handles this error by showing the unauthenticated state (Muse brief §6).

### 5.2 Missing Digest Handling

If `week: "latest"` and the `digests/` directory is empty (no digests yet), or if a specific week is requested but the file does not exist, the method returns:

```javascript
{
  frontmatter: null,
  body: null,
  sha: null,
  prev_week: null,
  next_week: null
}
```

The MVP Zone page renders: "No digest this week yet. Check back soon." This is not an error state — it is expected when Juno hasn't filed the week's report yet.

### 5.3 Archive Listing

**Method name:** `insiders.listDigests`

**Arguments:** none

**Returns:**
```javascript
[
  {
    week: "2026-14",
    title: "Week 14: Alice shipped, Day 6 content, ring opens",
    published_at: "2026-04-05T23:00:00Z",
    summary: "Alice Phase 2A went live."
  },
  {
    week: "2026-13",
    title: "Week 13: ...",
    published_at: "...",
    summary: "..."
  }
  // ...sorted newest-first
]
```

The server reads the GitHub API directory listing for `digests/`, fetches only the frontmatter from each file (not the body), and returns the list. The MVP Zone "Archive" accordion (Muse brief §2) uses this to render past digest links without loading all bodies.

**Caching:** Cache the archive listing for 10 minutes server-side (simple `Map` with TTL or Meteor's `_publishCursor` caching). Digests are committed once per week — there is no value in re-fetching the directory listing on every page load.

---

## 6. Juno's Authoring Workflow

1. On Friday or Saturday of each week, Juno creates `digests/YYYY-WW.md` in `~/.juno/` (working copy), fills in the template.
2. Juno commits to `koad/insiders` via `gh`:
   ```bash
   cd ~/.insiders  # or a local clone
   git add digests/2026-14.md
   git commit -m "digest: Week 14 ops report"
   git push
   ```
3. The server-side cache (if any) expires within 10 minutes. The MVP Zone page shows the new digest on next load.

**Automation path (future):** Juno can draft the digest from session logs and commit it programmatically. The format above is designed to be machine-writable. The `gh repo` CLI and git are the only required tools.

---

## 7. What This Spec Does Not Cover

- The MVP Zone page layout and authentication flow — see Muse brief `2026-04-05-mvp-zone.md`
- Member directory (`Members` collection) — Muse brief §3, no separate spec required yet
- Early access entity list (`EarlyAccessEntities`) — Muse brief §4, managed manually by Juno
- Keybase channel join flow — Muse brief §5, static content only
- Email distribution of digests — not in scope; delivery is via the MVP Zone page
