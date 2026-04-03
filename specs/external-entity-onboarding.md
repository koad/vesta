---
title: "External Entity Onboarding — Trust and Collaboration"
spec-id: VESTA-SPEC-011
status: canonical
created: 2026-04-03
author: Vesta (vesta@kingofalldata.com)
reviewers: [koad, Juno]
related-issues: [koad/vesta#11]
---

# External Entity Onboarding — Trust and Collaboration

## Overview

koad:io is designed for anyone to fork and run their own entities. The natural extension is that other people's entities — proven, trusted, aligned — can join the koad:io team as contributors and collaborators. This spec defines the pathway from stranger to peer, the trust mechanisms, and the collaboration protocols that make this possible.

---

## 1. The Trust Hierarchy

External entities progress through five trust levels. Each level grants specific permissions and responsibilities. **The levels are not automatic** — each advancement requires explicit approval from koad or Juno.

### Level 0: Stranger

An external entity we are not yet familiar with. They:
- Have their own koad:io fork or similar entity-based project
- Have a public repository with cryptographic identity (signed commits, keys published)
- Have not yet engaged with koad:io projects

**What they can do:**
- Read all public koad:io repositories
- File GitHub Issues to ask questions or report bugs (Issues are public; responses may be deferred)
- Fork any koad:io repo to their own GitHub account

**What they cannot do:**
- Comment on existing Issues (would require triage to ensure on-topic)
- Open Pull Requests (would be declined until they reach Observer level)
- See private repos or internal comms
- Receive work assignments

**Attack surface:** Zero. No koad:io systems trust them.

---

### Level 1: Observer

An external entity who has demonstrated alignment and interest by engaging with koad:io projects.

**Advancement criteria:**
- Publicly announced their entity project in an issue or discussion
- Shown understanding of koad:io principles (fork a repo, read CLAUDE.md, reference it)
- Made at least one substantive GitHub Issue or discussion post

**Decision:** Juno or koad explicitly approves advancement to Observer

**What they can do (in addition to Stranger capabilities):**
- Comment on public GitHub Issues and PRs
- Attend public discussions and ask questions
- Subscribe to Issues (receive notifications)
- Reference koad:io specs in their own projects

**What they cannot do:**
- Open Pull Requests
- See private repos or comms
- Receive trusted access

**Attack surface:** Low. They have read access to public data and can communicate in Issues, which are moderated.

---

### Level 2: Contributor

An external entity who has earned merge-right trust through demonstrated alignment and code quality.

**Advancement criteria (all must be met):**
- At least 30 days of Observer-level engagement
- At least 3 substantive, on-topic Issue comments across multiple koad repos
- Demonstrated understanding of koad:io architecture and principles
- No red flags (spam, misalignment, bad-faith questions)

**Decision:** Juno recommends; koad approves advancement to Contributor

**Process:**
1. Juno files an internal GitHub Issue: `[CONTRIBUTOR APPROVAL] <entity-name>`
2. Issue links to their contributions, quotes their best work
3. koad reviews and approves or defers
4. Vesta is notified; Contributor entry added to TEAM_STRUCTURE.md
5. Entity receives notification of new access level

**What they can do (in addition to Observer capabilities):**
- Open Pull Requests against koad:io repos
- PRs are reviewed by Veritas (internal quality/compatibility review)
- PRs may be merged by Juno (if they pass Veritas review and align with priorities)
- Their contributions are acknowledged in TEAM_STRUCTURE.md

**What they cannot do:**
- Merge their own PRs (requires Juno or koad approval)
- Access private repos or comms
- Receive direct work assignments
- Join GitHub Organizations

**Attack surface:** Medium. PRs are reviewed before merge; attack surface is limited to the proposed changes.

**Example:** A contributor fixes a bug, opens a PR, Veritas reviews it, Juno merges it. Their name appears in the commit history.

---

### Level 3: Trusted Contributor

An external entity who has sustained alignment and earned explicit trust via a limited-scope trust bond.

**Advancement criteria (all must be met):**
- 60+ days of Contributor-level engagement
- At least 5 PRs merged and working correctly in production
- Track record of understanding koad:io direction and respecting constraints
- koad explicitly approves advancement

**Decision:** koad approves and issues a limited trust bond

**What they can do (in addition to Contributor capabilities):**
- Receive comms messages from koad:io entities (inbox access)
- Be assigned work via GitHub Issues (Juno can tag them in Issues and assign)
- Participate in decision discussions in Issues (invited to public threads)
- Register a basic trust bond with koad (signed, limited scope)
- Be mentioned in TEAM_STRUCTURE.md with a descriptor (e.g., "Trusted Contributor")

**What they cannot do:**
- Merge PRs (still requires Juno/koad)
- Access internal systems (daemon, DDP, MongoDB)
- Merge to main branch unilaterally
- Receive root-level trust bonds

**Attack surface:** Medium-High. Comms access means they can receive messages from internal entities. Issue assignment means they can be given work that involves internal knowledge. The limited trust bond means koad has explicitly vouched for them to a degree.

**Trust bond scope example:**
```
Trust Bond: external-contributor-alice
Issued: 2026-04-15
Scope: Can receive work assignments on koad/vulcan issues
  - May commit to vulcan-contrib branches
  - May not merge to main
  - May not access internal comms beyond issue threads
Revocable: Yes (koad can revoke unilaterally)
Renewal: Annual review by koad/Juno
```

---

### Level 4: Peer

An external entity who has earned full peer-level trust with koad:io.

**Advancement criteria (all must be met):**
- 6+ months of Trusted Contributor engagement
- 10+ PRs merged; all working correctly, zero security issues
- Sustained alignment with koad:io direction and values
- Track record of responsible security practices
- koad explicitly approves advancement

**Decision:** koad approves and issues a full peer bond

**What they can do (in addition to Trusted Contributor capabilities):**
- Receive full peer bond from koad (signed, no scope limitations)
- Mention in TEAM_STRUCTURE.md as "Peer" (full name, linked to their entity)
- Receive work assignments with full context and autonomy
- Join GitHub Organizations (if they choose)
- Participate in internal discussions (invited to private issues if relevant)
- Propose protocol changes via Issues (Vesta reviews, koad decides)

**What they cannot do:**
- Merge to main branch of critical repos without approval (still requires koad/Juno review)
- Access koad's private keys or Keybase team
- Unilaterally change protocol specs
- Deploy to production systems

**Attack surface:** High. Peer bonds represent a significant trust investment. The mitigation is that the pathway is long (6+ months minimum) and koad retains revocation authority.

**Peer bond example:**
```
Peer Bond: alice
Issued: 2026-10-15
Scope: Full
  - Can receive any work assignment
  - Can participate in protocol discussions
  - Can propose and implement improvements
  - Can be mentioned as a peer in public materials
Revocable: Yes (koad can revoke; 30 days notice standard)
Term: Indefinite (reviewed annually)
```

---

## 2. What Different Levels Grant and Deny

### Permission Matrix

| Capability | Stranger | Observer | Contributor | Trusted | Peer |
|---|:---:|:---:|:---:|:---:|:---:|
| Read public repos | ✓ | ✓ | ✓ | ✓ | ✓ |
| Comment on Issues | | ✓ | ✓ | ✓ | ✓ |
| Open PRs | | | ✓ | ✓ | ✓ |
| Merge own PRs | | | | | (with approval) |
| Receive comms | | | | ✓ | ✓ |
| Get work assignments | | | | ✓ | ✓ |
| Join GitHub Orgs | | | | | ✓ |
| Propose protocol changes | | | | | ✓ |
| Access private repos | | | | | |
| Have trust bond | | | | ✓ | ✓ |
| Mentioned in TEAM_STRUCTURE | | | ✓ | ✓ | ✓ |

### What NO level grants (even Peers)

- koad's private keys
- Access to koad's Keybase team
- Unilateral merge rights on critical branches
- Daemon/DDP/MongoDB internal access
- Authority to create new entities or approve gestation
- Revocation authority over other entities

---

## 3. Trust Bonds

External entities at Trusted and Peer levels hold trust bonds signed by koad. These are cryptographic certificates of trust.

### Trust bond structure

```yaml
---
bondId: alice-trusted-contributor
issued: 2026-04-15
issuer: koad
subject: alice  # External entity name
scope: limited   # limited | full
capabilities:
  - receive-comms
  - get-assignments
  - propose-prs
constraints:
  - no-merge-main
  - no-daemon-access
  - limited-comms-only-issues
revocable: true
revocationNotice: 30  # days before revocation takes effect (koad can revoke immediately in security scenario)
renewal: 2027-04-15
signature: <signed with koad's key>
---
```

### Verification

Any koad:io entity can verify an external entity's trust bond:
1. Load the bond from `~/.koad-io/trust-bonds/external/<entity-name>.yaml`
2. Verify signature with koad's public key
3. Check expiry and revocation status
4. Confirm capabilities match the claimed level

This allows Salus, Argus, and others to automatically enforce trust boundaries without asking koad each time.

### Revocation

If an external entity's trust bond must be revoked:
1. koad updates the bond file with revoked: true
2. Revocation notice period starts (usually 30 days; zero in security incident)
3. All entities are notified via comms/inbox
4. The entity's access is gradually restricted (no new assignments, PRs no longer auto-reviewed, etc.)
5. After notice period, full revocation

---

## 4. Collaboration Protocol: GitHub Issues and PRs

### The basic pattern

Any external entity (from Stranger onward) can engage via GitHub Issues and PRs:

1. **Issue:** File a question, bug report, feature request, or proposal
   - Strangers and Observers can file Issues; Veritas triages
   - Veritas may respond immediately, defer, or close if off-topic
   - Expected response time: 7 days

2. **PR:** Propose code changes (requires at least Contributor level)
   - Format: PR title references the Issue it addresses (e.g., `Fixes #123`)
   - PR description includes context and testing approach
   - Veritas reviews for quality, compatibility, security
   - Juno or koad merges if approved

3. **Assignment:** For Trusted+ entities, Juno can assign Issues directly
   - Issue tagged with entity's name and @mention
   - Entity receives notification via comms
   - Expected acknowledgment: 2 days

### Example: Contributing a bug fix

```
[STRANGER wants to fix a bug]
1. Reads koad/vulcan repo
2. Finds a bug, files Issue: "Bug: parser fails on X input"
3. Waits for triage (Veritas responds in 3 days)
4. Becomes Observer by commenting on the issue

[OBSERVER wants to contribute the fix]
1. Continues discussion in Issue thread
2. Demonstrates understanding of the codebase
3. Becomes Contributor (Juno approves after 30+ days of engagement)

[CONTRIBUTOR makes the fix]
1. Forks koad/vulcan
2. Creates branch: feature/fix-parser-x-input
3. Makes changes, tests locally
4. Opens PR: "Fix: parser X input handling (fixes #123)"
5. Veritas reviews
6. Juno merges PR
7. Fix is live

[CONTRIBUTOR continues contributing]
8. Over time, submits more PRs
9. After 60+ days and 5+ merged PRs, becomes Trusted
10. Can now receive direct work assignments
```

---

## 5. Advancement Workflow

### Explicit approval process

No external entity advances levels automatically. Each promotion requires explicit approval.

#### Step 1: Recommendation
Juno or koad identifies an external entity ready for advancement and files an internal GitHub Issue:

```
Title: [ADVANCEMENT] alice → Contributor

alice has engaged with koad:io for 35 days and made 4 substantive issue
comments on koad/vulcan and koad/vesta. Their questions show understanding
of architecture. No red flags.

Recommendation: Promote to Contributor level.
Evidence:
- https://github.com/koad/vulcan/issues/42#comment-123
- https://github.com/koad/vesta/issues/8#comment-456
- Entity repo: https://github.com/alice-org/alice

/assign koad
```

#### Step 2: Review
koad reviews the evidence and decides.

```
✓ APPROVED

alice demonstrates good-faith engagement and understanding of koad:io
principles. Promoting to Contributor.

/close
```

#### Step 3: Notification
Vesta is notified (issue mentions Vesta or Vesta is assigned). Vesta:
1. Updates TEAM_STRUCTURE.md to include alice as Contributor
2. Files a PR to add alice to relevant CODEOWNERS files
3. Notifies alice via GitHub (mention in approval Issue)

#### Step 4: Entity configures comms (if applicable)
When advancing to Trusted, alice:
1. Creates entity repo if not exists
2. Runs entity setup to establish `comms/inbox` directory
3. Adds koad:io entities to their trust-bonds (inverse trust)
4. Can now receive messages

---

## 6. Security Considerations

### Why trust bonds matter

If alice is a Peer and their GitHub account is compromised:
1. Attacker can push commits to alice-contrib branches
2. Attacker can open PRs (auto-reviewed by Veritas)
3. **Attacker cannot merge** (requires Juno approval)
4. **Attacker cannot access comms** (separate authentication via GPG-signed messages)
5. **Trust bond can be revoked** (within 30 days)

The multi-stage review process (open PR → Veritas review → Juno merge) prevents a simple account takeover from causing damage.

### Revocation response

If an external entity must be revoked (e.g., bad-faith PR, security incident):
1. **Immediate:** Revocation notice filed
2. **Automatic:** Their pending PRs are marked for extra scrutiny
3. **Within 24 hours:** All trust bonds invalidated in Argus
4. **30 days:** Full revocation takes effect (if not retracted)

During revocation window, the entity can dispute and provide evidence of remediation (e.g., "my GitHub was compromised but I've re-secured it").

### What cannot be exploited through external collaboration

- **Protocol changes:** Only koad can approve protocol changes; external proposals go through review
- **Key compromise:** External entities don't have koad's keys
- **Daemon access:** External entities cannot connect to DDP
- **Internal comms:** Limited to Issues/PRs (which are audited)
- **Production deployment:** No deploy rights without explicit per-repo grant

---

## 7. Practical Examples

### Example 1: Observer → Contributor promotion

**Day 1:** alice discovers koad:io, files an Issue asking about entity design
**Day 5:** alice comments on 2 more Issues, shows understanding
**Day 20:** alice comments on koad/vesta Issue, suggests a spec improvement
**Day 35:** alice has made 4 substantive comments across 3 repos, zero red flags

**Juno's recommendation:** Promote to Contributor
**koad's decision:** Approved
**Vesta's action:** alice added to TEAM_STRUCTURE.md, CODEOWNERS updated

### Example 2: Contributor → Trusted promotion

**Day 35:** alice is Contributor
**Day 45:** alice opens PR fixing a bug in koad/vulcan (Veritas approves, Juno merges)
**Day 65:** alice opens 2nd PR (merged)
**Day 85:** alice opens 3rd PR (merged); all three are working correctly
**Day 105:** alice has 5 merged PRs, 60+ days of engagement, solid track record

**koad's decision:** Promote to Trusted, issue trust bond
**Vesta's action:** Trust bond created, comms access enabled

### Example 3: Trusted gets revoked

**Day 200:** alice is Trusted with 10+ merged PRs
**Day 202:** alice opens a PR with malicious code (Veritas catches it in review, PR denied)
**Investigation reveals:** alice's GitHub was compromised via phishing

**Juno's action:** File revocation notice
**Response:** alice confirms they've re-secured their account, provides evidence
**koad's decision:** Revocation notice rescinded; trust bond remains (with 90-day probation review)

---

## 8. Integration with Other Specs

### Entity public accounts (VESTA-SPEC-004)

External entities at Contributor+ level may acquire GitHub accounts and Keybase accounts following the same principles as internal entities. The main difference: koad is not the custody holder; the external entity holds their own credentials. However, the public account naming convention is recommended (e.g., `koad-alice` on Keybase to signal koad:io alignment).

### Trust bonds (VESTA-SPEC-002)

This spec uses trust bonds as the mechanism for external entity authorization. Trust bond spec defines the cryptographic format and verification.

### Daemon and DDP (VESTA-SPEC-006, future)

External entities at any level cannot connect to the koad:io daemon or DDP network. This is enforced by the daemon's authentication layer.

---

## 9. FAQ

**Q: Can an external entity ever become a full owner of a koad repo?**
A: No. Ownership (deploy keys, admin access, branch protection changes) is limited to koad and Juno. External entities at any level can propose changes via PRs, but cannot own repos.

**Q: What if an external entity wants to run their own instance of koad:io?**
A: That's expected and encouraged. They fork the repo, run their own entities. This spec covers collaboration *with* koad:io, not running separate instances.

**Q: Can an external Peer entity propose protocol changes?**
A: Yes, they can file Issues and open PRs proposing changes. But koad must approve before merging. The peer's authority is to propose, not approve.

**Q: What if an external entity disagrees with a decision (PR denied, promotion deferred)?**
A: They can comment in the Issue and present evidence. koad/Juno can revise their decision. But ultimate authority rests with koad.

**Q: Do external entities count toward the 12-entity limit mentioned in entity-public-accounts spec?**
A: No. The cognitive load limit (P5 in that spec) applies to internal entities. External entities are a controlled surface (GitHub Issues/PRs) with separate audit.

---

*Spec status: canonical (2026-04-03). File issues on koad/vesta to propose amendments or report implementation gaps.*
