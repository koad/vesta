---
title: "Entity Public Accounts — Keybase and GitHub"
spec-id: VESTA-SPEC-004
status: draft
created: 2026-04-03
author: Vesta (vesta@kingofalldata.com)
reviewers: [koad, Juno]
related-issues: []
---

# Entity Public Accounts: Keybase and GitHub

## Overview

This specification defines the canonical approach for koad:io entities acquiring and operating accounts on public services — specifically Keybase and GitHub. It establishes the principles that govern these decisions, the security model, custody protocol, and phased rollout order.

**Decision trigger:** koad has stated that only Juno gets a new Keybase and GitHub account initially, to be used on dotsh. This spec formalizes the reasoning so future decisions follow consistent criteria.

---

## 1. Principles

The following principles are ordered by priority. When they conflict, higher-numbered principles yield to lower-numbered ones.

### P1 — Minimal surface

Every public account is an attack surface. Each account introduces: a login credential to protect, a recovery path to secure, a session that can be hijacked, and a reputation that can be tarnished. An entity should acquire a public account only when the operational benefit is concrete and near-term — not hypothetical.

### P2 — Clear custody

For every account an entity holds, there must be one unambiguous answer to: "Who controls this?" Ambiguous custody is worse than no custody. The answer must be documented, signed, and actionable in a compromise scenario.

### P3 — Sovereignty where it matters

An entity operating as another identity (koad posting as Juno via koad's account) is not sovereignty — it is a borrowed costume. Where an entity has public presence that will be inspected, attributed, or relied upon by third parties, that presence should belong to the entity cryptographically.

### P4 — Responsibility boundary

An entity with a public account in a third party's GitHub org or Keybase team carries responsibility into that third party's context. This extends the blast radius of any compromise. An entity should not hold org memberships until it has established stable operational history under koad's direct supervision.

### P5 — Proliferation discipline

12 entities × multiple services × multiple machines = potential for account sprawl that exceeds koad's capacity to audit. The system must be legible to one human. Each new account should be justified against the cognitive and operational overhead it adds.

---

## 2. Keybase Model

### What Keybase accounts enable for entities

- Verified public identity linkable to GitHub, DNS, Twitter, etc.
- KBFS (Keybase File System) storage keyed to entity identity
- Keybase team membership — joining other people's teams and being discoverable as a team member
- Keybase chat under the entity's own identity
- Clearsigned documents attributed to the entity, verifiable without trusting koad's chain

### The team membership risk

When an entity joins a Keybase team:
- The entity gains read/write access to the team's KBFS (`/keybase/team/<teamname>/`)
- The entity can post in team channels
- **Compromise of the entity's Keybase account = access to every team they belong to**

This is the primary reason team membership must be earned, not granted speculatively. Until an entity's Keybase account has proven stable under koad's monitoring, it should not join external teams.

### Recommended approach: Controlled issuance

**Tier 0 — No account** (default for all entities)
Operations under koad's Keybase identity. Trust bonds signed by koad's Keybase key are attributed to koad, who vouches for the entity.

**Tier 1 — Entity Keybase account, no team memberships**
The entity has its own Keybase account. It can post, sign documents, and link proofs. It does NOT join external teams. This is appropriate when:
- The entity has public-facing communications responsibilities (Mercury, Juno)
- The entity needs to publish signed artifacts attributed to itself
- The entity's operation is monitored and stable

**Tier 2 — Keybase team membership**
The entity is added to external Keybase teams. Requires:
- 30+ days of stable operation at Tier 1
- koad explicitly approves each team membership
- Entity has no active security incidents in its record
- koad holds revocation capability (see custody protocol)

### Keybase account naming convention

```
Entity name, lowercase: juno, vulcan, mercury, etc.
Keybase username: koad-juno, koad-vulcan, koad-mercury
```

The `koad-` prefix makes attribution to the koad:io ecosystem explicit and distinguishable from other Keybase users who happen to share the entity's first name. It also signals that koad is the root authority, which is accurate.

### Keybase proof strategy

Entity Keybase accounts should link only the proofs that are operationally active:
- GitHub account (if entity has one)
- Domain proof via `canon.koad.sh/<entity>.keys` TXT record
- Do NOT link social accounts the entity does not actively operate

---

## 3. GitHub Model

### Identity options compared

| Option | What it enables | Blast radius on compromise |
|---|---|---|
| Full personal account | Push, PRs, issues, org membership, GitHub Actions, Packages | High — account takeover = access to all orgs/repos |
| Deploy key (repo-scoped) | Push to one specific repo, read/write configurable | Low — scoped to one repo |
| Machine user (org bot account) | Push to org repos, can be added to teams | Medium — org-scoped |
| Signed commits (GPG only) | Commits attributed to entity key without an account | Zero — no account |
| GitHub App | OAuth scopes, granular permissions, no password | Medium — app permissions |

### Recommended approach: Minimal viable identity

**Phase A — GPG-signed commits without a GitHub account**
An entity can have its commits attributed to its identity via commit signing alone. The entity's GPG key (at `~/.entity/id/`) signs commits. GitHub displays the "Verified" badge when the public key is registered to any GitHub account — in this case, it can be registered to koad's account as a signing key for a specific identity, or to the entity's own account.

This provides: cryptographic attribution, verifiable commit history, public identity via the key fingerprint — with zero account surface.

**Phase B — Entity GitHub account, no org memberships**
When the entity needs to: file issues on other people's repos, comment on public issues, have a profile page, be credited as a contributor, receive @mentions — a full account is warranted. Criteria:
- Entity has concrete operational need for public GitHub interaction
- koad has reviewed and approved the account creation
- MFA is configured immediately on account creation (see custody)
- The account's email is `<entity>@kingofalldata.com`

**Phase C — Organization membership**
An entity joins a GitHub organization (koad's org or a third party's). This should be:
- Explicitly requested and justified
- Granted at minimum required permission (member, not owner)
- Audited quarterly

### Deploy keys as an alternative

For entities whose primary GitHub need is pushing code to their own repo, a deploy key is superior to a full account:

```bash
# Generate deploy key for entity
ssh-keygen -t ed25519 -C "vulcan@kingofalldata.com" -f ~/.vulcan/id/github-deploy-key

# Register the public key to the entity's repo on GitHub
# Scope: write access to koad/vulcan only
```

Deploy keys are repo-scoped. Compromise exposes one repo. They cannot be used to join orgs, file issues on other repos, or access Actions secrets beyond that repo's scope.

### GitHub commit signing without a GitHub account

```bash
# Export entity's GPG public key
gpg --armor --export <entity>@kingofalldata.com > /tmp/<entity>-gpg.pub

# Register to koad's GitHub account as a signing key
# This makes commits signed by this key show "Verified" in GitHub UI

# Configure entity's git to use its key
git config user.signingkey <fingerprint>
git config commit.gpgsign true
```

This approach — currently the most conservative — should be the default for all entities that do not yet have Phase B accounts.

---

## 4. Custody Protocol

### The custody question

For a human's Keybase or GitHub account, custody is clear: the human holds the password, MFA device, and recovery codes. For an AI entity, the question is structural: the entity has no persistent memory of credentials, and cannot protect a password the way a human can.

### Custody model: koad-held, entity-declared

**koad holds:**
- Account passwords (in koad's password manager)
- MFA device / TOTP secret (koad's authenticator)
- Recovery codes (offline storage)
- Email account access (via `<entity>@kingofalldata.com` which koad controls)

**The entity holds:**
- Its cryptographic keys (`~/.entity/id/`) — these are disk-resident and koad has access to the machine
- The `gh` CLI authentication token (scoped to what the entity needs)
- Signing keys for commits and trust bonds

**Rationale:** The entity IS its keys, not its accounts. The accounts are operational interfaces. koad holding account credentials is consistent with how a company holds service accounts — the employee uses the account but the company owns the credentials.

This is not a reduction in sovereignty. Juno's sovereignty is expressed through her cryptographic keys, her signed trust bonds, her commits under her identity. The Keybase account password being in koad's vault does not diminish that Juno's signed documents are Juno's signed documents.

### Credential storage requirements

For every entity public account, the following must be documented in `~/.entity/accounts/<service>.md`:

```
Service: github / keybase
Username: <entity-username>
Email: <entity>@kingofalldata.com
Created: <date>
MFA: TOTP / hardware key / SMS (never SMS)
Custody: koad
Recovery codes: koad's secure storage
GPG key registered: <fingerprint>
Last rotated: <date>
```

### gh CLI token scoping

When the entity uses `gh` CLI, the token should be scoped to minimum necessary:

| Entity type | Recommended scopes |
|---|---|
| Orchestrator (Juno) | `repo`, `read:org`, `read:user` |
| Builder (Vulcan) | `repo` (own repos only), `read:org` |
| Communicator (Mercury) | `public_repo`, `read:user` |
| Researcher (Sibyl) | `read:user`, `public_repo` (read-only) |

### Rotation schedule

| Credential | Rotation trigger | Rotation frequency |
|---|---|---|
| gh CLI token | Suspected compromise OR quarterly | 90 days |
| Keybase paperkey | Suspected compromise | On demand only |
| GPG signing key | Suspected compromise | On demand only |
| Account password | Suspected compromise | On demand only |
| MFA secret | Device change | On device change |

### Compromise response

If an entity's public account is compromised:

1. **Immediate:** koad revokes the `gh` CLI token via GitHub settings
2. **Within 1 hour:** Password changed, all active sessions invalidated
3. **Within 4 hours:** Review all commits, issues, and API actions taken during the window
4. **Within 24 hours:** Determine if any org memberships were abused; notify affected parties
5. **Within 48 hours:** File incident report in `~/.entity/LOGS/<date>-account-compromise.md`
6. **Cryptographic keys:** If signing keys on disk are believed compromised, regenerate and re-sign all trust bonds (see key compromise recovery protocol)

Account compromise does not invalidate the entity's cryptographic identity if the keys on disk remain secure. A compromised Keybase account password is serious but not catastrophic — the entity's GPG-signed documents remain valid.

---

## 5. Phased Rollout

### Rollout criteria (all must be met before account creation)

1. **Operational history:** Entity has been operational for at least 30 days with at least 10 commits to its repo
2. **Concrete need:** There is a specific named task that requires the account (not "it would be useful someday")
3. **Custody documented:** The account record template is completed before the account is used
4. **koad approval:** koad explicitly approves the account creation (not just Juno's recommendation)

### Current state and planned order

| Entity | Keybase | GitHub | Rationale |
|---|---|---|---|
| Juno | Phase 1 — immediate | Phase B — immediate | Business orchestrator, public presence required, dotsh integration |
| Mercury | Phase 1 — when operational | Phase B — when operational | Communications role requires public identity |
| Vulcan | Phase 0 — deploy keys | Phase A + deploy keys | Builder; commits need attribution, deploy keys sufficient |
| Veritas | Phase 0 | Phase A | Quality work is internal; GPG signing sufficient |
| Vesta | Phase 0 | Phase A | Specs are filed in koad/vesta; no external interaction needed |
| Sibyl | Phase 0 | Phase 0 | Research is internal output; no public account needed yet |
| Muse | Phase 0 | Phase A | UI polish attributed via commits; no public interaction |
| Argus | Phase 0 | Phase 0 | Diagnostics are internal; no public account needed |
| Salus | Phase 0 | Phase 0 | Healing is internal; no public account needed |
| Janus | Phase 0 | Phase 0 | Stream watching is internal observation |
| Aegis | Phase 0 | Phase 0 | Confidant role is private by design |
| Doc | Phase 0 | Phase 0 | Documentation generation is internal |

### Juno's immediate account setup (dotsh)

Per koad's direction, Juno gets a Keybase account and GitHub account now. The specific context is dotsh integration.

**Juno Keybase account:**
- Username: `koad-juno` (or `juno` if available — check availability)
- Link proofs: GitHub (when created), domain (`canon.koad.sh/juno.keys`)
- No team memberships initially
- Paperkey generated and stored in koad's secure storage

**Juno GitHub account:**
- Username: `koad-juno` (consistent with Keybase naming)
- Email: `juno@kingofalldata.com`
- GPG key registered: Juno's key from `~/.juno/id/`
- gh CLI scoped: `repo`, `read:org`, `read:user`
- MFA: TOTP (not SMS)

---

## 6. Attack Surface Register

This register explicitly documents the risks accepted when an entity acquires a public account. The act of creating an account implicitly accepts these risks. They are listed here so the decision is made with eyes open, not discovered in an incident.

### Risks accepted: Any public account (Keybase or GitHub)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Credential phishing targeting the entity's username | Medium | High | koad never clicks unsolicited login prompts; TOTP + no SMS |
| Account takeover via compromised `<entity>@kingofalldata.com` email | Low | High | Secure email provider; account recovery paths audited |
| Impersonation (bad actor registers `koad-juno2` etc.) | Medium | Medium | Public key registration makes impersonation verifiable; awareness |
| Session hijacking via stolen `gh` token | Low | Medium | Quarterly rotation; scoped tokens |
| Social engineering via account's public activity | Low | Medium | Entities don't respond to DMs; all external requests go through GitHub Issues |

### Additional risks: Keybase team membership

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Team data exposure on account compromise | Medium | High | No team memberships until 30-day stable operation |
| KBFS content accessible during account compromise window | Low | High | Sensitive data not stored in KBFS under entity account |
| Team reputation damage from entity actions | Low | Medium | Entity has no autonomous post capability without koad involvement |

### Additional risks: GitHub org membership

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| GitHub Actions abuse (org secrets accessible) | Low | High | Entity has member role, not owner; secrets scoped at org level |
| Org repo access beyond entity's work scope | Medium | Medium | Request only repos the entity actively uses |
| Supply chain attack via entity's push access | Very Low | Very High | PRs required for main branch; entity cannot self-merge |

### Risks accepted: GPG-signed commits only (Phase A)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Private key compromise on disk | Very Low | High | Keys in `~/.entity/id/` on koad-controlled machine; disk encryption |
| Key fingerprint spoofing | Very Low | Low | Fingerprint published at `canon.koad.sh/<entity>.keys` |

### Risks explicitly NOT accepted

- **SMS-based MFA:** Never. SMS is interceptable. TOTP or hardware key only.
- **Shared credentials across entities:** Each account has its own password and token.
- **Accounts on services where koad does not hold recovery access:** If koad cannot recover the account without the entity's cooperation, the account should not exist.
- **Org owner roles:** Entities are members, not owners, unless there is explicit and documented justification.

---

## 7. Open Questions (for koad review)

1. **Keybase username format:** `koad-juno` vs `juno` — if `juno` is available, is there value in claiming it without the prefix? The prefix makes the koad:io attribution explicit but longer usernames are less memorable.

2. **dotsh integration specifics:** What does dotsh need from Juno's Keybase account specifically? Team membership? KBFS path? Chat? The answer determines whether Tier 1 is sufficient or Tier 2 is immediately needed.

3. **Email infrastructure:** `juno@kingofalldata.com` — is this routed and accessible for account verification emails? If not, account creation is blocked at the email verification step.

4. **Multi-machine context:** Juno's `gh` CLI token will be on thinker. Is the same token needed on fourty4 (where GitClaw runs)? If yes, token should be generated with read-only scopes for fourty4, write scopes for thinker.

---

*Spec status: draft. Canonical when koad approves. File issues on koad/vesta to propose amendments.*
