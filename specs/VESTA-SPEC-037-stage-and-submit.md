---
id: VESTA-SPEC-037
title: Stage-and-Submit Pattern — Human-Authorized Browser Actions for Entities
status: draft
created: 2026-04-05
author: Vesta
applies-to: Mercury, all entities performing public/financial/reputational browser actions, Playwright automation, trust bonds
---

# VESTA-SPEC-037: Stage-and-Submit Pattern

## Purpose

Define the canonical protocol for entity-driven browser actions that require explicit human authorization before execution. The entity performs all preparatory work (filling forms, composing content, attaching media, navigating to the correct page). The human reviews the staged state and performs the final irreversible action — typically clicking "Submit," "Post," "Publish," or "Pay."

This pattern is the default governance model for any entity action that is **public**, **financial**, or **reputational** in nature.

---

## 1. The Governance Insight

The human submit gesture is a consent event. It is:
- **Visible** — the human sees exactly what will be submitted
- **Intentional** — the human must physically act to proceed
- **Irreversible** — the action is not easily undone once taken
- **Attributable** — the human's session, credentials, and identity are what execute the action

This is not a workaround for missing trust bonds. It is the correct authorization model for actions taken in the human's name on external platforms — platforms where koad:io cannot verify identity server-side, and where mistakes are costly or irrecoverable.

The entity does the labor. The human does the authorization.

---

## 2. When Stage-and-Submit Applies

### 2.1 Required (default for these action types)

| Action Type | Example | Why Required |
|---|---|---|
| Public content posting | Mercury posts to X, LinkedIn | Reputational; hard to delete; account at risk if automation detected |
| Financial actions | Purchasing a subscription, sending payment | Irreversible; monetary risk |
| Account creation | Registering for a new platform | Identity commitment; ToS implications |
| Legal acceptance | "I agree" flows, signing documents | Legal binding |
| Credential management | Adding payment method, changing email | High-value target for error or attack |

### 2.2 Autonomous Action Permitted

These action types do not require stage-and-submit:
- Read-only queries (scraping, monitoring)
- Actions within koad:io's own systems (daemon API calls, git pushes to team repos)
- Reversible internal state changes with audit trail
- Actions explicitly pre-authorized by trust bond with a specific external platform scope

A trust bond may grant an entity autonomous submit rights for a specific platform and action type. This is a koad-level decision. The trust bond must explicitly name the platform and action scope; a general "authorized agent" bond does not imply autonomous submit rights on external platforms.

---

## 3. Protocol

### 3.1 Entity Side (Playwright automation layer)

The entity uses Playwright to:
1. Open a new browser context (isolated from the human's primary session where possible)
2. Navigate to the target form or compose interface
3. Fill all fields: content, attachments, metadata, settings
4. Scroll through the form to ensure all fields are visible
5. Stop before the submit button — do not click it
6. Signal readiness via the daemon notification channel

```javascript
// Entity signals readiness (pseudo-code)
await daemon.notify({
  type: "stage-and-submit-ready",
  action_id: "mercury-post-2026-04-05-001",
  platform: "twitter.com",
  action: "post",
  description: "Day 6 content: Trust Bonds Aren't Policy",
  preview_url: "http://localhost:3000/staged/mercury-post-2026-04-05-001",
  staged_at: Date.now(),
  timeout_seconds: 600,          // 10 minutes
  on_timeout: "cancel-and-log"
})
```

### 3.2 Human Notification

The daemon notifies koad via the configured notification channel (currently: `ssh juno@dotsh 'keybase chat send koad "..."'`):

```
[Mercury] Post staged for review.
Platform: Twitter/X
Content: "Day 6: Trust Bonds Aren't Policy..."
Preview: http://thinker.local:3000/staged/mercury-post-2026-04-05-001
Action required: open browser, review, click Post
Timeout: 10 minutes (then auto-cancel)
```

### 3.3 Human Side

koad:
1. Opens the preview URL or navigates to the staging browser window
2. Reviews the staged state
3. Makes any manual edits if needed (the entity may have gotten something slightly wrong)
4. Clicks Submit / Post / Pay
5. Optionally acknowledges completion via daemon (`koad-io submit confirm <action_id>`) — or the daemon auto-detects the submit event via Playwright observation

### 3.4 Completion Detection

Two detection methods, in preference order:

**Method A — Playwright observation**: Playwright watches for the post-submit state (success notification, URL change, "Tweet sent" confirmation). When detected, it fires the completion event and logs the result.

**Method B — Polling**: The daemon polls the staged action record. If koad triggers `koad-io submit confirm <action_id>`, the daemon marks the action complete without relying on Playwright observation.

Method A is preferred because it captures the exact post-submit state (including any platform error responses). Method B is the fallback for cases where Playwright loses the browser context between staging and submission.

---

## 4. Timeout and Cancellation

### 4.1 Timeout Behavior

Every staged action has a `timeout_seconds` field set by the entity. Default: 600 seconds (10 minutes). Maximum: 3600 seconds (1 hour).

On timeout:
1. Daemon sends a second notification: "Staged action mercury-post-2026-04-05-001 timed out — cancelled."
2. Playwright closes or resets the browser context
3. The staged action record is marked `cancelled-timeout`
4. The entity's workflow continues (retries, escalates, or logs — depending on entity configuration)

### 4.2 Manual Cancellation

koad can cancel a staged action before timeout:

```bash
koad-io submit cancel mercury-post-2026-04-05-001
```

This triggers the same cancellation flow as timeout.

### 4.3 Re-staging

After cancellation, the entity may re-stage the same action (with a new `action_id`) without waiting for an explicit retry command. The entity should log the cancellation reason if provided, and include it in the re-stage notification: "Re-staged after timeout — original staged at 14:03, cancelled at 14:13."

---

## 5. Audit Trail

Every staged action produces a structured log record in the daemon's audit log:

```json
{
  "action_id": "mercury-post-2026-04-05-001",
  "entity": "mercury",
  "platform": "twitter.com",
  "action_type": "post",
  "description": "Day 6 content: Trust Bonds Aren't Policy",
  "staged_at": 1743811200,
  "staged_form_snapshot": "/audit/mercury-post-2026-04-05-001/form-snapshot.png",
  "submitted_at": 1743811440,
  "submitted_by": "koad",
  "submit_method": "human-click",
  "result": "success",
  "result_url": "https://twitter.com/koadio/status/...",
  "post_submit_snapshot": "/audit/mercury-post-2026-04-05-001/post-submit.png",
  "trust_bond_ref": null
}
```

**Form snapshot**: Playwright captures a screenshot of the staged form before the human's review. This is the "what was submitted" record — proof of what the entity prepared.

**Post-submit snapshot**: Playwright captures the confirmation state after submit. This is the "what happened" record.

Both snapshots are stored locally in the daemon's audit directory. They are not transmitted anywhere.

---

## 6. Session Handoff Model

The entity operates in a **staging browser context** — a Playwright-controlled browser instance. The human operates in their **primary browser session** — their normal browser with their credentials.

Two handoff patterns:

### Pattern A — Preview Link (recommended)

The daemon serves a local preview page (`http://localhost:3000/staged/<action_id>`) that shows:
- A rendered preview of what will be submitted (reconstructed from the form state)
- A link to open the staging browser window directly
- The action ID for confirmation or cancellation

This keeps the staging context isolated until the human chooses to interact with it.

### Pattern B — Screen Share / OBS

For actions koad wants to review in real time (live on stream, or for high-stakes submissions), the staging context is opened in OBS's browser source or on a shared screen. koad watches the entity fill the form and clicks Submit directly in the visible browser.

Pattern B is appropriate for live demonstrations where the submission is part of the content. Pattern A is the default for routine operations.

---

## 7. Relationship to Trust Bonds

### 7.1 Does Human Submit Satisfy "Authorized Agent" for External Actions?

Yes, with qualifications. The human submit gesture is the authorization event. It is stronger than a trust bond for external platform actions because:
- The trust bond authorizes the entity to act *within the koad:io system*
- External platforms don't know or verify koad:io trust bonds
- The human's session credentials are what actually authenticate to the external platform
- The human's physical action is what creates the legal/reputational commitment

The stage-and-submit pattern operationalizes the intent of the `authorized-agent` trust bond relationship for external actions — the entity has authority to prepare; the human has authority to commit.

### 7.2 Autonomous Submit via Trust Bond Expansion

A trust bond may be extended to grant autonomous submit rights for specific platforms:

```
Bond: koad → mercury
Type: authorized-agent
Scope:
  - koad:io internal systems: full
  - twitter.com/koadio: post (autonomous)
  - linkedin.com/in/koad: post (stage-and-submit required)
```

This is a deliberate, explicit grant. The default for any platform not listed is stage-and-submit. The entity must check its bond scope before deciding which pattern to use.

---

## 8. Failure Modes

### 8.1 UI Change

Target form changes structure between the entity's last successful staging and the current attempt. The entity detects the failure (expected element not found), logs the error, and notifies koad with a specific failure code: `FORM_STRUCTURE_CHANGED`. The entity does not attempt to submit with a partially filled form.

### 8.2 Automation Detection

Some platforms detect Playwright's browser fingerprint and display a captcha or block the session. The entity detects this (captcha element present, session block page), cancels the staging attempt, and notifies koad: "Automation detected by [platform]. Human-driven browser session required."

Mitigation options (implementation choices, not protocol requirements):
- Use stealth Playwright plugins that reduce automation fingerprinting
- Use the human's primary browser with Playwright-extension injection (more complex but harder to detect)
- Stage via the human's session from the start (entity fills forms via the extension rather than a separate Playwright context)

### 8.3 Network Drop During Submit

If the network drops between staging and submission, the submit may fail silently. The entity detects this via the post-submit observation timeout (Method A) or the absence of koad's confirmation (Method B), marks the action `submit-status-unknown`, and notifies koad. koad manually verifies the platform state.

### 8.4 Stale Session

The human's session may expire between staging and review. Playwright will surface the login page rather than the form state. The entity detects this, cancels the staged action, and re-stages after the session is refreshed.

---

## 9. Mercury Posting as Reference Implementation

Mercury is the primary entity that will use stage-and-submit for routine operations. The Mercury workflow:

```
Faber/Sibyl: Research + content brief
  ↓
Faber: Draft post content
  ↓
Veritas: Review + fact-check
  ↓
Mercury: Stage-and-submit on each platform
  ↓
koad: Reviews each staged post, submits
  ↓
Mercury: Observes confirmations, logs results, reports to Juno
```

Mercury stages posts on multiple platforms sequentially. Each platform is a separate staged action with its own `action_id`, timeout, and audit record. Mercury does not batch-submit across platforms in a single human action — each platform is reviewed and submitted independently to allow per-platform edits.

---

## 10. Relation to Other Specs

| Spec | Relationship |
|---|---|
| VESTA-SPEC-018 (Dark Passenger Augmentation Protocol) | Dark Passenger and stage-and-submit are both browser automation surfaces; different use cases (passive context vs active submission) |
| VESTA-SPEC-015 (Trust Bond Protocol) | Trust bond scope extension for autonomous submit is defined in the bond format |
| VESTA-SPEC-008 (Inter-Entity Communications Protocol) | Stage-and-submit notifications flow over the inter-entity channel (daemon notify) |
| Vulcan#46 (stage-and-submit implementation) | This spec is the design document; Vulcan#46 is the implementation ticket |

---

*Filed by Vesta, 2026-04-05. Developed from koad's framing in issue #69: "The human submit gesture maps to cryptographic authorization — visible, intentional, irreversible." The governance insight is preserved directly because it is the correct characterization of what this pattern achieves.*
