# VESTA-SPEC-041 — `/get-started` Page Data Contract

**ID:** VESTA-SPEC-041  
**Title:** `/get-started` Page Data Contract — GitHub API and Static Data Requirements  
**Status:** canonical  
**Area:** 1: Entity Model  
**Applies to:** Vulcan (implementation), Muse (design direction), kingofalldata.com site  
**Created:** 2026-04-05  
**Updated:** 2026-04-05  
**Resolves:** Muse brief `2026-04-05-get-started-flow.md` — Open Questions 2, 3, 5  

---

## Why This Exists

The `/get-started` page (Muse brief `2026-04-05-get-started-flow.md`) has several data dependencies that must be specified before Vulcan builds the page. These are:

1. Which entities are offered in Step 2's entity selector
2. What data each entity card needs and where it comes from
3. Whether Step 3's "expected output" block can be semi-live (last commit from selected entity)
4. Whether routes linked from Step 4 exist yet

This spec provides the data contract: what data is needed, where it comes from, how it degrades when unavailable.

---

## Data Dependencies by Step

### Step 1 — Prerequisites

**Data needed:** None from GitHub or APIs. All static content.

The `check-prereqs.sh` script link (see VESTA-SPEC-040) is a static URL:
```
https://raw.githubusercontent.com/koad/koad-io/main/bin/check-prereqs.sh
```

No API call. No dynamic data.

---

### Step 2 — Entity Selector

**Entities offered:** Three entities are hardcoded in the initial implementation. These are not dynamically fetched from the entities index.

| Entity | Clone URL | Profile URL | Role label |
|--------|-----------|-------------|------------|
| Juno | `https://github.com/koad/juno` | `/entities/juno` | BUSINESS ORCHESTRATOR |
| Chiron | `https://github.com/koad/chiron` | `/entities/chiron` | CURRICULUM ARCHITECT |
| Sibyl | `https://github.com/koad/sibyl` | `/entities/sibyl` | RESEARCH ANALYST |

**Why these three:** They represent the three use cases most relevant to a new operator:
- Juno: see the team model in full
- Chiron: build a teaching/onboarding curriculum
- Sibyl: autonomous research worker

**Data source:** Static. No API call. Clone URLs and role labels are hardcoded in the page component.

**Entity availability check (optional enhancement):**  
Before rendering a card, the page may make a lightweight GitHub API call to verify the repo exists and is public:
```
GET https://api.github.com/repos/koad/{entity}
```
If the call fails or returns 404, the card is hidden rather than shown in a broken state. This call is unauthenticated. Rate limit: 60 requests/hour per IP — acceptable for a static page.

**Degradation:** If the availability check is not implemented (MVP), all three cards render unconditionally. If a repo does not yet exist (Chiron pending gestation), the clone command will fail when the operator tries it — the troubleshoot section in Step 4 covers this case.

---

### Step 3 — First Session

**PRIMER.md link:**  
Each entity card in Step 2 passes the selected entity slug to Step 3. The PRIMER.md link is:
```
https://github.com/koad/{entity}/blob/main/PRIMER.md
```
Static template, entity slug substituted. No API call.

**"Expected output" block — static vs. semi-live:**

The Muse brief asks whether the expected output block can show the entity's last commit message as evidence of activity. This spec defines the contract:

**MVP (static):** The expected output block is static mock copy. It does not reflect real entity state. Label reads "~ expected output". This is always correct — the entity's actual response will vary regardless.

**Enhancement (semi-live):** If Vulcan implements the optional enhancement, the last commit is fetched:
```
GET https://api.github.com/repos/koad/{entity}/commits?per_page=1
```
Response: `[{ "commit": { "message": "...", "author": { "date": "..." } } }]`

The expected output block then reads:
```
Last commit: {commit.message} — {relative_time(commit.author.date)}
```

This is shown as a callout below the mock, not replacing it. Label: "Most recent commit from this entity."

**Cache:** 5 minutes for the commits API response. Stale-while-revalidate. If the API is unavailable, fall back to static copy silently — do not show an error.

**Do not implement the semi-live enhancement for MVP.** Static first. Note it as a tracked enhancement in the issue.

---

### Step 4 — You're Running

**Three next-step cards and their link targets:**

| Card | Link Target | Exists? | Degradation |
|------|-------------|---------|-------------|
| File a GitHub Issue | `https://github.com/koad/{entity}/issues/new` | Yes (GitHub, always exists if repo is public) | None needed |
| Start Alice's curriculum | `https://kingofalldata.com/alice` | No — depends on Alice PR merge (#1) | See below |
| Meet the team | `https://kingofalldata.com/entities` | No — depends on entities index build | See below |

**Alice curriculum link degradation:**  
The Alice curriculum route (`/alice`) does not exist until the blog PR (koad/kingofalldata-dot-com#1) is merged and Alice's curriculum route is implemented. Until then:
- Primary degradation: link to `https://github.com/koad/alice` (the entity repo).
- The card copy adjusts: "Alice's curriculum is coming soon. Follow the entity repo for progress."
- Do not show the card as broken. Show the degraded version.
- Implementation: check at build time if `/alice` route exists. If not, substitute the GitHub URL.

**Entities index link degradation:**  
`/entities` does not exist until Muse's entities index page is built. Until then:
- Link to `https://github.com/koad` (the GitHub org page — shows all public entity repos).
- Card copy adjusts: "Browse entity repos on GitHub while the full index is being built."

**"File a GitHub Issue" link:**  
This uses the selected entity from Step 2 session state. Default: Juno. Template:
```
https://github.com/koad/{selectedEntity}/issues/new
```

---

## Session State Contract

The selected entity from Step 2 is stored in `sessionStorage` under the key `koadio_get_started_entity`.

```javascript
// Write on selection
sessionStorage.setItem('koadio_get_started_entity', 'juno');

// Read on Steps 3 and 4
const entity = sessionStorage.getItem('koadio_get_started_entity') ?? 'juno';
```

Default: `'juno'` if `sessionStorage` is unavailable or unset.

`sessionStorage` is cleared when the tab closes. This is correct behavior — the page represents no persistent state. The operator's real progress is in their terminal.

No `localStorage`. No cookies. No server-side session.

---

## URL Fragment Contract

```
/get-started            → Step 1 (default entry)
/get-started#step-1     → Step 1
/get-started#step-2     → Step 2
/get-started#step-3     → Step 3
/get-started#step-4     → Step 4
```

**Fragment navigation:** Client-side hash routing. No page reload. `window.addEventListener('hashchange', ...)`.

**Direct deep-link to Step 2+:** If an operator arrives at `#step-2` or later without having passed through Step 1, the page renders the requested step. Prerequisites are not enforced by URL — they are a UX guide, not a gate.

**`history.pushState`:** Use `history.replaceState` to update the URL as the operator advances, rather than `pushState` (which adds to history). The operator's back button should go to the previous page they came from, not to Step 3 when they're on Step 4. Exception: if the operator explicitly clicks "← Previous", use `history.back()`.

---

## API Call Summary

| Call | Used for | Method | Auth | Cache |
|------|---------|--------|------|-------|
| `api.github.com/repos/koad/{entity}` | Entity card availability check (optional) | GET | None | 60 min |
| `api.github.com/repos/koad/{entity}/commits?per_page=1` | Semi-live expected output (optional enhancement, not MVP) | GET | None | 5 min |

**Total API calls for MVP:** Zero. The MVP page is fully static.

---

## Relationship to Other Specs

- VESTA-SPEC-039 — `trust/public-chain.json` (entity profile page reads this; get-started links to entity profiles)
- VESTA-SPEC-040 — `check-prereqs.sh` (Step 1 links to this script)
- VESTA-SPEC-026 — Chiron Entity Spec (Chiron is offered in Step 2; must be gestated before the card is live)
- Muse brief: `2026-04-05-get-started-flow.md` (full design specification)
- Muse brief: `2026-04-05-entities-index.md` (Step 4 links here)
- Vulcan issue: koad/kingofalldata-dot-com#1 (Alice PR — blocks Step 4 Alice card)
