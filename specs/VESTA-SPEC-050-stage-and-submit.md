---
id: VESTA-SPEC-050
title: Stage-and-Submit — Builder Spec for Vulcan
status: draft
created: 2026-04-05
author: Vesta
applies-to: Vulcan (implementation), Mercury (caller), daemon (notification channel)
supersedes: —
supplements: VESTA-SPEC-037 (governance model; read that first)
ref: koad/vulcan#46
---

# VESTA-SPEC-050: Stage-and-Submit — Builder Spec for Vulcan

## Purpose

This spec provides the implementation-ready design for the stage-and-submit pattern. The governance rationale is in VESTA-SPEC-037. This document covers what to build, how Mercury calls it, what koad experiences, how failures are handled, and what Phase 1 scope is.

The non-negotiable constraint: **koad is the only human who can trigger the final submit.** Everything else is negotiable.

---

## 1. What "Staged" Means

A post is "staged" when:

1. A visible (non-headless) browser window on flowbie has the compose/post form open
2. Every field is filled: body text, title (if applicable), subreddit/community/thread target, media attached (if any), options set (NSFW, flair, etc.)
3. The browser has scrolled to and focused on the submit button — the cursor is positioned
4. The submit button is visible on screen without further scrolling
5. No input is needed from koad to complete the form — only a single click

There is **zero ambiguity** about what will happen when koad clicks submit. The entity has done all the work. The human authorizes the outcome.

A form is **not staged** if:
- Any field is empty or placeholder text remains
- A confirmation modal or preview step will appear after the click that requires further action
- The session has expired and requires login
- A captcha is blocking the form

If any of the above conditions are detected, the entity cancels and notifies rather than presenting a partially staged form.

---

## 2. Platform Scope

### 2.1 Phase 1 — Build These First

These two platforms are the immediate operational need:

| Platform | URL | Action | Notes |
|----------|-----|--------|-------|
| Twitter/X | x.com | Compose tweet / thread | Single tweet for Phase 1; thread support in Phase 2 |
| Reddit | reddit.com | Submit link or text post to a subreddit | r/selfhosted is the first target |

### 2.2 Phase 2 — Build After Phase 1 Is Running

| Platform | URL | Action | Notes |
|----------|-----|--------|-------|
| HackerNews | news.ycombinator.com | Submit link (Show HN) | Simpler form than Twitter/X |
| LinkedIn | linkedin.com | Post update | Session management is fiddly |
| Dev.to | dev.to | Publish article | Draft → publish flow |
| GitHub Discussions | github.com | Create discussion | Low priority, koad can do manually |

### 2.3 Does Not Apply — Not a Good Fit for This Pattern

These are excluded from stage-and-submit:

| Case | Reason |
|------|--------|
| Comment replies / threaded responses | Reading context requires human judgment; entity cannot reliably stage the right conversation thread |
| Buffer / scheduled post tools | The API costs money (the pattern this replaces) — stage-and-submit directly to the platform instead |
| Email composition | Too many edge cases in threading and reply context; Mercury uses koad's MUA directly |
| Form submissions that require file uploads beyond images | Complex multi-step flows not worth automating before simpler cases are solid |

---

## 3. Mercury's Interface

### 3.1 Input: What Mercury Passes

Mercury calls the stage-and-submit tool with a JSON payload:

```json
{
  "action_id": "mercury-twitter-2026-04-05-001",
  "platform": "twitter",
  "action": "post",
  "content": {
    "text": "Full post text here — plain text, no markdown",
    "media": [
      {
        "type": "image",
        "path": "/home/koad/.mercury/media/2026-04-05-hook-diagram.png",
        "alt_text": "Hook architecture diagram"
      }
    ],
    "thread": []
  },
  "meta": {
    "source_file": "/home/koad/.mercury/distribution/twitter-week1-thread.md",
    "approved_by": "juno",
    "staged_for": "koad"
  },
  "options": {
    "timeout_seconds": 600,
    "on_timeout": "cancel-and-log",
    "notify_channel": "keybase"
  }
}
```

For Reddit, the `content` object adds:

```json
"content": {
  "subreddit": "selfhosted",
  "post_type": "link",
  "title": "Self-hosted AI agents: each one is a git repo on hardware you control",
  "url": "https://kingofalldata.com/blog/entities-are-running-on-disk",
  "body": ""
}
```

For a Reddit text post, `url` is omitted and `body` contains the post body.

### 3.2 Invocation Method

Mercury calls the tool as a local CLI command (installed by Vulcan into `~/.koad-io/bin/`):

```bash
stage-and-submit --payload /tmp/mercury-action-001.json
```

Or via the daemon API if the daemon worker system is active:

```bash
koad-io submit stage --file /tmp/mercury-action-001.json
```

Phase 1 implementation: CLI script. Daemon API integration is Phase 2.

### 3.3 Output: What Mercury Gets Back

The tool exits with one of these codes and writes a JSON result to stdout:

```json
{
  "action_id": "mercury-twitter-2026-04-05-001",
  "status": "staged",
  "staged_at": 1743811200,
  "preview_screenshot": "/home/koad/.mercury/audit/mercury-twitter-2026-04-05-001/staged.png",
  "message": "Staged on twitter. Browser open on flowbie. Notification sent to koad."
}
```

Or on failure:

```json
{
  "action_id": "mercury-twitter-2026-04-05-001",
  "status": "failed",
  "error_code": "FORM_STRUCTURE_CHANGED",
  "error_detail": "Expected selector 'div[data-testid=tweetTextarea_0]' not found",
  "staged_at": null,
  "message": "Could not stage. Notify Vulcan to update the platform adapter."
}
```

The tool **blocks** while staging (filling the form). It returns as soon as the form is fully staged and the notification has fired. It does **not** block waiting for koad to submit — that is an asynchronous event. Mercury's workflow continues after receiving the `staged` status; the completion callback arrives later via the daemon notification channel.

### 3.4 Completion Callback

When koad submits (or the action times out or is cancelled), the daemon writes a completion record that Mercury can poll or subscribe to:

```
~/.mercury/audit/<action_id>/result.json
```

```json
{
  "action_id": "mercury-twitter-2026-04-05-001",
  "status": "submitted",
  "submitted_at": 1743811440,
  "result_url": "https://x.com/koadio/status/...",
  "post_submit_screenshot": "/home/koad/.mercury/audit/mercury-twitter-2026-04-05-001/post-submit.png"
}
```

Mercury polls this file after staging to detect completion. Poll interval: 30 seconds. Max wait: `timeout_seconds` + 60 seconds grace.

---

## 4. koad's Experience

### 4.1 The Browser Window

The Playwright browser is **visible, non-headless**, running on flowbie (the always-on content studio machine, which has an X11 display). The browser window is sized to fit a standard compose interface (1280×900 minimum) and placed in the foreground.

flowbie is the mandatory host for stage-and-submit. Rationale:
- Always-on — the window persists between koad's sessions
- Has X11 display — visible browser is possible
- OBS running — screen can be captured for review without koad physically being at the machine
- Not thinker — keeps the staging browser off koad's primary work machine

### 4.2 Notification

Immediately after staging, the system notifies koad via Keybase chat (the current confirmed notification channel):

```
[Mercury] Post staged — ready for your click.

Platform: Twitter/X
Content: "I sent one command to 15 AI agents this morning..."
Screenshot: <link to preview>

Action: Open flowbie browser window and click Post.
Window title: "stage-and-submit: mercury-twitter-2026-04-05-001"
Times out in: 10 minutes (then auto-cancelled)

To cancel: koad-io submit cancel mercury-twitter-2026-04-05-001
```

The notification channel is the same as the existing `ssh juno@dotsh 'keybase chat send koad "..."'` pattern. Stage-and-submit uses it directly.

### 4.3 Accessing the Staged Window When Away from flowbie

If koad is on thinker and needs to see the flowbie browser, the options (in preference order):

1. **OBS scene on flowbie** includes a browser capture source — koad can view via stream preview without opening a VNC session
2. **Screenshot in the notification** — the staged form screenshot is included in the notification message (or linked as a localhost URL accessible over the LAN)
3. **SSH X11 forwarding** — `ssh -X koad@flowbie` can forward the window, but this is slow and is the fallback only

For Phase 1, the screenshot attached to the Keybase notification is sufficient for routine reviews. koad switches to flowbie and clicks when ready.

### 4.4 When koad Is Away from Keyboard

If koad is AFK:
- The window stays open until `timeout_seconds` expires
- A second Keybase notification fires at 2 minutes before timeout: "Staged post will auto-cancel in 2 minutes. Click now or it will be re-queued."
- If koad returns after timeout, the action has been cancelled and logged; Mercury will re-stage on the next distribution run or when koad manually triggers retry

Mercury's content pipeline is not time-critical enough to require immediate submission. 10-minute default timeout is appropriate. For time-sensitive posts (HN Show HN during a specific hour), Mercury increases `timeout_seconds` to 3600 and includes the deadline in the notification.

---

## 5. Confirmation and Logging

### 5.1 How the System Knows koad Submitted

**Primary method — Playwright navigation observation**: After staging, a Playwright observer watches for post-submit state:

| Platform | Success Signal |
|----------|---------------|
| Twitter/X | URL changes to `x.com/koadio/status/*`, or "Tweet sent" toast appears |
| Reddit | Redirect to the new post URL (`reddit.com/r/*/comments/*`) |
| HackerNews | Redirect to the news item URL |
| LinkedIn | "Post shared" confirmation toast |

When the success signal fires, Playwright captures a screenshot and the result URL, writes `result.json`, and fires the completion notification to koad and Mercury.

**Fallback method — manual confirmation**: If Playwright loses the browser context (window closed, focus changed, crash), koad can confirm manually:

```bash
koad-io submit confirm mercury-twitter-2026-04-05-001 --url https://x.com/koadio/status/...
```

This writes the result record without a screenshot.

### 5.2 Audit Record

Every staged action produces two files in the audit directory:

```
~/.mercury/audit/<action_id>/
  staged.png         ← screenshot before koad's click (what the entity prepared)
  post-submit.png    ← screenshot after submit (what the platform confirmed)
  action.json        ← full structured record
  result.json        ← written on completion
```

The `action.json` record:

```json
{
  "action_id": "mercury-twitter-2026-04-05-001",
  "entity": "mercury",
  "platform": "twitter",
  "action_type": "post",
  "content_preview": "I sent one command to 15 AI agents...",
  "source_file": "/home/koad/.mercury/distribution/twitter-week1-thread.md",
  "host": "flowbie",
  "staged_at": 1743811200,
  "staged_by": "mercury",
  "submitted_at": 1743811440,
  "submitted_by": "koad",
  "submit_method": "human-click",
  "detection_method": "playwright-navigation",
  "result": "success",
  "result_url": "https://x.com/koadio/status/...",
  "timeout_seconds": 600
}
```

Audit records are stored locally. They are committed to Mercury's git repo as part of the publish log on the next `mercury commit self`.

---

## 6. Failure Modes

### 6.1 Platform UI Change

The platform changes its DOM structure between the last successful staging and the current attempt. Expected Playwright selectors are not found.

**Detection**: Playwright selector timeout. The adapter catches this and raises `FORM_STRUCTURE_CHANGED`.

**Response**:
1. Log the failure with the missing selector and page URL
2. Take a screenshot of the current page state
3. Cancel the staged action
4. Notify koad: "Twitter/X compose UI has changed. Vulcan needs to update the adapter. Action cancelled — re-queue when fixed."
5. File a GitHub issue on koad/vulcan with the error details and screenshot

**No retry** on `FORM_STRUCTURE_CHANGED` — retrying a broken adapter wastes time and may partially fill a form.

### 6.2 CAPTCHA or Automation Detection

Platform detects Playwright's browser fingerprint and surfaces a CAPTCHA or session block.

**Detection**: Presence of known CAPTCHA element (`iframe[src*=recaptcha]`, `div[class*=captcha]`, etc.) or HTTP 429/403 response.

**Response**:
1. Cancel the staged action
2. Notify koad: "Automation detected by [platform]. Browser session needs manual login or stealth mode update."
3. Log the failure as `AUTOMATION_DETECTED`
4. Do **not** attempt stealth mode fallback without koad's explicit instruction — that is a capability change requiring koad's decision

Mitigation options for Vulcan to consider (not required in Phase 1): playwright-stealth plugin, user-agent rotation, or extension-injection into koad's primary browser profile.

### 6.3 Form Validation Failure

The form fills correctly but the platform surfaces a validation error (character count exceeded, URL not recognized, media too large).

**Detection**: Error toast or inline validation message present after field fill, before koad has clicked submit.

**Response**:
1. Take a screenshot of the validation error
2. Cancel the staged action
3. Notify koad: "Form validation error on [platform]: [error text]. Content may need editing."
4. Log as `FORM_VALIDATION_FAILED`
5. Include the error text and screenshot in the notification so koad can diagnose without opening the browser

Mercury should pre-validate character counts and media dimensions before calling stage-and-submit to catch these before Playwright runs.

### 6.4 koad Closes the Window Without Submitting

koad closes the browser window without clicking submit and without running the cancel command.

**Detection**: Playwright process detects the browser context closed without a navigation success signal. Timeout not yet reached.

**Response**:
1. Log the action as `window-closed-without-submit`
2. Notify koad: "Staged window was closed without submitting. Was this intentional? To cancel: koad-io submit cancel <id>. To re-stage: koad-io submit retry <id>"
3. Hold the staged action record in `pending-close-confirm` state for 60 seconds
4. If no confirmation received within 60 seconds, auto-cancel and log

This avoids false cancellations if koad accidentally closes the window.

### 6.5 Network Drop During Submit

Network drops between staging and submission. The submit may fire on the platform but Playwright never observes the success signal.

**Detection**: Navigation observer times out after submit click (Playwright sees the click but not the success URL).

**Response**:
1. Log as `submit-status-unknown`
2. Notify koad: "Post may have been submitted but confirmation was not detected. Please verify manually on [platform]."
3. Do not log as success or failure — mark as `unknown` until koad manually confirms or denies
4. Provide manual confirm command in notification

### 6.6 flowbie Unreachable

The stage-and-submit tool cannot reach flowbie (SSH timeout, machine offline).

**Detection**: SSH connection attempt fails.

**Response**:
1. Log as `host-unreachable`
2. Notify koad: "flowbie is unreachable. Stage-and-submit requires flowbie (X11 display). Check machine status."
3. Do not attempt to run headless on thinker — the visible browser on flowbie is a protocol requirement, not an implementation preference

---

## 7. Security Boundary

The human submit gesture is the authorization event. This section specifies how the system enforces that only koad can trigger it.

### 7.1 No Entity Can Auto-Submit

The Playwright adapter has a hard-coded constraint: it never calls `.click()` on a submit, post, or publish button. The submit action can only occur via:

1. **koad's physical click** in the visible browser window
2. **koad's keyboard** (Enter key, if the form supports it — same authorization level as a click)

No code path in the stage-and-submit tool dispatches a synthetic click on the final action button. This is enforced at the adapter layer, not just policy.

Playwright's role ends when the form is filled and staged. The Playwright observer resumes after the human action to capture the result. The gap between "staged" and "submitted" is owned entirely by the human.

### 7.2 Entity Cannot Override via Trust Bond

The `authorized-agent` trust bond between koad and Mercury does **not** grant autonomous submit rights on external platforms. This cannot be changed by Mercury or Juno — it requires koad to explicitly extend the bond scope with a platform-specific autonomous grant (see VESTA-SPEC-037, Section 7.2).

The stage-and-submit tool checks this constraint on startup: if the calling entity's trust bond does not include a platform-specific autonomous grant for the target platform, the tool enforces stage-and-submit regardless of any flags passed by the caller.

### 7.3 flowbie as the Authorization Surface

The staged browser window runs on flowbie — koad's machine, under koad's session. The browser instance is controlled by Playwright until staging is complete, then Playwright yields control. Only koad's physical input (keyboard or mouse on flowbie) can advance the state past staging.

This means: even if an entity were to send a malicious payload to the stage-and-submit tool, the worst it could do is fill a form. It cannot post. koad's physical presence on flowbie is the final gate.

### 7.4 Action IDs Are Not Forgeable

Action IDs are generated by the calling entity but must be structured as: `<entity>-<platform>-<date>-<seq>` (e.g., `mercury-twitter-2026-04-05-001`). The daemon validates this format and rejects malformed IDs. An entity cannot confirm another entity's action — the completion record is keyed to the action ID and the entity that staged it.

---

## 8. Phase 1 Scope

Phase 1 is the minimum viable tool. Build only what is needed to stage and notify for Twitter/X and Reddit.

### 8.1 What Phase 1 Includes

- [ ] Playwright adapter for **Twitter/X** single-tweet compose
- [ ] Playwright adapter for **Reddit** link post and text post (r/selfhosted first)
- [ ] CLI entrypoint: `stage-and-submit --payload <file>`
- [ ] Visible (non-headless) Chromium browser on flowbie
- [ ] Keybase notification on stage complete (using existing `ssh juno@dotsh 'keybase chat send koad "..."'` pattern)
- [ ] Screenshot capture at staging (saves to `~/.mercury/audit/<action_id>/staged.png`)
- [ ] Playwright navigation observer for post-submit success detection
- [ ] Screenshot capture at post-submit (saves to `~/.mercury/audit/<action_id>/post-submit.png`)
- [ ] `result.json` written on completion or cancellation
- [ ] Timeout with second notification at 2 minutes before expiry
- [ ] `FORM_STRUCTURE_CHANGED` error detection and notification
- [ ] `AUTOMATION_DETECTED` error detection and notification

### 8.2 What Phase 1 Excludes

- Twitter/X thread posting (multiple tweets — Phase 2)
- HackerNews, LinkedIn, Dev.to adapters (Phase 2)
- Daemon API integration (Phase 2 — Phase 1 uses CLI only)
- Preview link served by local HTTP server (Phase 2 — Phase 1 uses screenshot in notification)
- Browser extension injection into koad's primary browser profile (Phase 2 — stealth mitigation)
- Trust bond scope check at runtime (Phase 2 — Phase 1 assumes stage-and-submit for all calls)

### 8.3 Host and Runtime Requirements

- **Host**: flowbie (always-on, X11 display available)
- **Runtime**: Node.js + Playwright (`playwright-core` + Chromium)
- **Install location**: `~/.koad-io/packages/stage-and-submit/` (installed via `koad install stage-and-submit`)
- **Entrypoint**: `~/.koad-io/bin/stage-and-submit`
- **Audit output**: `~/.mercury/audit/` (Mercury's audit directory, not the tool's)
- **SSH access**: tool runs on flowbie; invocation can originate from thinker via `ssh koad@flowbie 'stage-and-submit --payload ...'` — or Mercury runs directly on flowbie

### 8.4 Acceptance Criteria for Phase 1

Phase 1 is complete when:

1. Mercury can call `stage-and-submit` with a Twitter/X payload and a visible browser window appears on flowbie with the compose UI fully filled
2. A Keybase notification arrives on koad's device with a screenshot of the staged post
3. koad clicks Post in the browser; the tool detects the navigation success and writes `result.json`
4. Mercury reads `result.json` and logs the result URL
5. The same flow works end-to-end for a Reddit link post to r/selfhosted
6. A form change (remove the target element from the DOM in a test) produces a `FORM_STRUCTURE_CHANGED` notification rather than a crash or silent failure

---

## 9. Relation to Other Specs

| Spec | Relationship |
|------|-------------|
| VESTA-SPEC-037 | Governance model for this pattern — the "why." Read before implementing. |
| VESTA-SPEC-020 | Entity hook architecture — how Mercury invokes tooling |
| VESTA-SPEC-036 | Dark Passenger — different browser automation surface (passive context, not form submission) |
| VESTA-SPEC-038 | Entity host permission table — flowbie is the permitted host for browser actions |
| koad/vulcan#46 | Original implementation brief; this spec supersedes it for design detail |

---

*Filed by Vesta, 2026-04-05. VESTA-SPEC-037 covers the governance rationale; this spec covers what Vulcan builds. The two should be read together. If they conflict, this spec (SPEC-050) takes precedence on implementation details; SPEC-037 takes precedence on governance constraints.*
