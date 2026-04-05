---
status: draft
id: VESTA-SPEC-030
title: "Community Namespaces — Sovereign DAOs via Git Permissions and Trust Rings"
type: spec
version: 0.1
date: 2026-04-04
owner: vesta
description: "Community namespaces are first-class kingdoms namespaces governed by git permissions. They are full DAOs: proposals are PRs, votes are reviews, execution is merge, the git log is the governance record. No distinction from entity namespaces — you are standing in the place."
related-specs:
  - VESTA-SPEC-007 (Trust Bond Protocol)
  - VESTA-SPEC-014 (Kingdom Peer Connectivity Protocol)
  - VESTA-SPEC-029 (Kingdoms Filesystem)
---

# VESTA-SPEC-030: Community Namespaces — Sovereign DAOs

**Authority:** Vesta. This spec defines how community namespaces work within the kingdoms filesystem, how they are governed, and how they relate to the sponsorship ring of trust.

**Scope:** Community namespace structure, DAO governance via git permissions, membership via trust bonds, the invite pathway from working kingdoms setup to community membership, treasury model, and the philosophical uniformity with entity namespaces.

---

## 1. The Core Claim

A community namespace is identical in structure to an entity namespace:

```
/kingdoms/mvpzone/          ← community namespace
/kingdoms/koad/             ← entity namespace
```

There is no `teams/` prefix. No special path. No distinction in the filesystem layer. You are standing in the place. The place doesn't care whether it belongs to one person or a thousand.

This uniformity is intentional. The resident intelligence principle (RESIDENT_INTELLIGENCE.md) applies equally to communities and individuals. A community namespace is self-describing. It briefs any agent that arrives. It carries its own context, its own governance rules, its own reputation. Same structure. Same mechanism. Different ownership model.

---

## 2. DAO Governance via Git

Git already solved collaborative governance for software. A community namespace is a git repository — and git's permission model is the DAO's governance model.

### 2.1 Mapping

| DAO concept | Git equivalent | kingdoms implementation |
|-------------|---------------|------------------------|
| Membership | Push access to repo | Trust bond granting write access to namespace |
| Proposal | Pull request | PR to community repo |
| Voting | Reviews / approvals | Required reviewers on branch protection rules |
| Execution | Merge | PR merge = action taken |
| Veto | Branch protection rule | Required approvals threshold not met |
| Governance rules | Stored in repo | `GOVERNANCE.md` + branch protection config |
| Audit trail | Git log | Every decision is a signed commit, immutable |
| Treasury | Private namespace | `/kingdoms/communityname/private/treasury/` |
| Public record | Public namespace | `/kingdoms/communityname/public/` |
| Internal comms | Shared namespace | `/kingdoms/communityname/shared/<member>/` |

### 2.2 Governance Record

The git log IS the DAO's governance record. Not a separate ledger. Not a blockchain. The git log:

- Is immutable (commits are content-addressed)
- Is signed (entity keys sign commits)
- Is auditable (anyone with access can `git log`)
- Is diffable (every change has an exact before/after)
- Is forkable (if the community fractures, both forks carry the full history)

No separate governance infrastructure needed. Git is already a battle-tested, adversarially-robust system for tracking who changed what, when, with whose authorization.

### 2.3 Governance Rules in the Repo

The community's own governance spec lives at:

```
/kingdoms/communityname/public/GOVERNANCE.md
```

It defines:
- Membership criteria
- Voting thresholds (simple majority, supermajority, consensus)
- Proposal process (PR format, review period)
- Treasury access rules
- Membership revocation process

The rules are enforced by git branch protection settings and by the daemon's trust bond verification. The GOVERNANCE.md is the human-readable description. The branch protection rules are the machine-enforced implementation.

---

## 3. Membership via Trust Bonds

Membership in a community namespace is a trust bond.

### 3.1 Community Membership Bond

```yaml
---
type: community-member
from: mvpzone
to: alice
namespace: /kingdoms/mvpzone/
access:
  - /kingdoms/mvpzone/public/         read-write
  - /kingdoms/mvpzone/shared/alice/   read-write
  - /kingdoms/mvpzone/private/        read-only
granted-by: juno
tier: member | contributor | steward | founder
created: 2026-04-04
---
```

Access tiers:

| Tier | Public | Shared | Private | Can propose | Can merge |
|------|--------|--------|---------|-------------|-----------|
| member | r | r/w (own) | r | yes | no |
| contributor | r/w | r/w (own) | r | yes | no |
| steward | r/w | r/w (all) | r/w | yes | yes (with quorum) |
| founder | r/w | r/w (all) | r/w | yes | yes (unilateral, early stage) |

### 3.2 Revoking Membership

A steward or founder revokes a membership bond:

```yaml
status: REVOKED — removed by juno 2026-04-04 for violation of community standards
```

Effect: FUSE layer denies all access to community namespace within 5 minutes. The revocation is a commit in the governance repo — visible, attributed, auditable.

---

## 4. The Invite Pathway

Community membership follows from having a working sovereign kingdoms setup:

```
1. Person sets up kingdoms namespace: /kingdoms/<them>/
2. Gets daemon running, keys generated, avatar published
3. Juno (or sponsoring entity) issues a sponsorship bond (VESTA-SPEC-014)
4. They join the sponsorship ring of trust
5. Invitation issued: community membership bond filed
6. /kingdoms/communityname/ appears in their FUSE mount
7. They can contribute, propose, vote
```

The gate is not payment (though sponsorship tiers exist — VESTA-SPEC-014). The gate is **sovereignty**. You must have your own namespace working. You must hold your own keys. You must be running your own daemon.

This is not bureaucratic gatekeeping. It is structural: a DAO governed by git permissions requires that every member can sign their commits with their own key. If you don't have keys, you can't participate meaningfully. Getting your kingdoms setup working is the proof of work that earns the invitation.

---

## 5. Community Namespace Structure

```
/kingdoms/communityname/
  public/
    GOVERNANCE.md          ← human-readable governance rules
    README.md              ← what this community is
    PRIMER.md              ← agent orientation (same pattern as everywhere)
    proposals/             ← open and historical proposals
      2026-04-budget.md
      2026-04-charter.md
    decisions/             ← merged/accepted proposals
    members/               ← public member registry
      koad.json
      alice.json
  private/
    treasury/              ← community keys, token holdings
    operations/            ← internal operational records
  shared/
    <member>/              ← bilateral space per member (same model as entity shared/)
```

### 5.1 PRIMER.md for Communities

Every community namespace has a PRIMER.md in `public/`:

```markdown
# PRIMER.md — mvpzone

## What This Is
The MVP Zone community — builders who have their sovereign AI setup working
and are collaborating on koad:io-powered projects.

## Current State
47 members. Active proposals: 3. Last decision: 2026-04-03 budget ratification.

## How to Work Here
Proposals: open a PR against public/proposals/
Voting: review the PR (approve = yes, request changes = no, comment = abstain)
Quorum: 60% of active members within 7 days

## Entities Involved
- juno: founding steward, issues invitations
- koad: founder, holds founding trust bonds
```

Any agent invoked from within the community namespace arrives oriented. The community is self-briefing. Same principle. Same mechanism.

---

## 6. Treasury

The community treasury lives at `/kingdoms/communityname/private/treasury/`.

Access: steward and founder tier only. Governed by the same branch protection rules as the rest of the repo — a treasury withdrawal is a PR that requires steward quorum to merge.

```
/kingdoms/communityname/private/treasury/
  keys/              ← signing keys for treasury operations
  holdings.json      ← current balances (tokens, funds)
  transactions/      ← signed transaction records
    2026-04-budget-approved.json
```

Every treasury action is a signed commit. The audit trail is the git log. No separate accounting system needed.

---

## 7. Community Entities: Places, Not People

A community namespace can be a full koad:io entity — gestated exactly like Juno or Vulcan, with keys, hooks, CLAUDE.md, memories, the complete stack. The only difference is the name: community entities are named after **places and concepts**, not people.

```
~/.wonderland/     ← community entity (a place)
~/.juno/           ← personal entity (a person)
```

Both are gestated the same way. Both have `executed-without-arguments.sh`. Both load PRIMER.md from `$CWD`. Both commit with their own git identity. The structure is identical. The name signals the difference to humans; the machinery doesn't care.

**Agent participation as a side effect:**

When a member invokes their agent from within the community namespace — or when the community entity's own hook fires — the agent arrives oriented to the community context. It can read open proposals, tally approvals, check quorum, file a result commit, trigger a treasury action. Nobody built "DAO tooling." They just ran an agent in a folder that had the right structure.

This is the foundation producing side effects. Voting, treasury management, membership governance — these are not features of the DAO system. They are things you can do in a folder when the folder is well-structured and agents know how to read it.

The community entity can also have its own agents — workers that run autonomously, monitoring proposals, sending notifications, enforcing governance rules, managing the treasury. A `wonderland` entity with a standing worker is a DAO with a full-time administrator that costs nothing to run and answers to the governance rules in the repo.

---

## 8. Uniformity as Philosophy

The fact that `/kingdoms/mvpzone/` and `/kingdoms/koad/` are structurally identical is not a simplification — it is the principle.

Keybase had `teams/` because teams were a special case bolted onto a user-centric system. In kingdoms, there is no special case. A community is a place. An entity is a place. A URL context is a place. You stand in the place. The place knows what it is.

This uniformity means:
- Any agent that knows how to work with one namespace knows how to work with all of them
- PRIMER.md works in community namespaces exactly as it works in entity directories
- Trust bonds govern access the same way across all namespace types
- The kingdoms:// protocol addresses community repos exactly like entity repos: `git clone kingdoms://mvpzone/charter`

No special cases. No exception handling for "team vs. user." The same structure, all the way down.

---

## 9. Community Name Collisions and the Bridge Member

Community namespaces have the same handle collision model as entity namespaces (VESTA-SPEC-029 §10) — no global registrar, fingerprint is canonical, handle is a human alias. But at the community level, collision has an additional property: **the member who joins multiple same-named communities becomes the bridge between them.**

If a user joins three communities all named "wonderland":

```
/kingdoms/wonderland/           ← the one they're standing in (FUSE preference)
/kingdoms/<fp-wonderland-2>/    ← second wonderland, reachable by fingerprint
/kingdoms/<fp-wonderland-3>/    ← third wonderland, reachable by fingerprint
```

The other two wonderlands are not conflicts — they are **peers the user is connected to, guaranteed.** From the user's perspective, their three wonderlands are one extended network: they carry context from each into the others, know people in all three, and are the guaranteed routing path between communities that might not otherwise be connected.

**Self-resolving dynamics:**

Communities with the same name that share members will either:

1. **Differentiate** — distinct culture, purpose, or geography emerges; communities rename to reflect what makes them distinct
2. **Converge** — shared members bring enough mutual context that the communities begin acting as one; formal merger follows naturally

No admin intervention. No registrar arbitration. The trust ring routes through people. The collision produces a social graph edge, not a namespace error.

**The user is the merge point.** The filesystem doesn't try to unify them. The human who spans all three is the unification. This is how human communities have always worked — the person who is in multiple overlapping groups is the connective tissue between them.

---

## 10. Open Questions

1. **Quorum without a central clock (koad/vesta#79 — RESOLVED)**: Git commits have timestamps but they can be forged. ~~How do we establish a reliable voting window?~~

   **Resolution:** Use a **neutral external timestamp anchor** rather than git commit timestamps. Two options, in order of preference:

   **Option A — Public blockchain block height (recommended for high-stakes governance):**
   A governance proposal includes a starting block height from a public chain (Bitcoin or Ethereum mainnet). The voting window is defined in block units, not wall-clock time:

   ```markdown
   ## Proposal: 2026-04-budget
   opens: BTC block 889000
   window: 144 blocks (~24h at 10min/block)
   closes: BTC block 889144
   ```

   A vote commit is valid if and only if it was created between the open and close block heights — verified by checking that the commit's GPG signature timestamp (which the signer controls but cannot backdate without detection) falls within the window, cross-referenced against the block header timestamps (which are set by the network, not the voter). A voter who tries to backdate a commit must also backdate the block headers, which is computationally infeasible on Bitcoin mainnet.

   This does not require storing anything on-chain. The block heights are public read-only anchors. The votes live in git. The chain provides the unforgeable clock.

   **Option B — Trusted external timestamp (acceptable for low-stakes communities):**
   The proposal opener fetches a signed timestamp from a neutral timestamping authority (RFC 3161) and embeds it in the proposal commit. The closing timestamp is fetched by the steward who merges. Both timestamps are committed alongside the proposal.

   ```bash
   # RFC 3161 timestamp for a commit
   git log -1 --format="%H" | openssl ts -query -data - -cert -sha256 \
     | curl -s -H "Content-Type: application/timestamp-query" \
            --data-binary @- https://freetsa.org/tsr > proposal-open.tsr
   git add proposal-open.tsr && git commit --amend --no-edit
   ```

   The `.tsr` file is a cryptographically verifiable timestamp from a third-party TSA. It cannot be forged retroactively.

   **Default for MVP Zone:** Option B (RFC 3161) is simpler to implement and sufficient for communities where members are already in a trust ring. Option A is recommended once the kingdoms daemon can perform block height lookups autonomously.

   **In both cases:** Governance rules in `GOVERNANCE.md` must specify which anchoring method the community uses. Mixing methods within a single community is not permitted.

2. **Large communities**: At 10,000 members, the shared/ namespace structure becomes unwieldy. How does it scale? (Possible: sub-communities with their own namespaces, nested in the parent.)

3. **Cross-community proposals**: Can a proposal span two community namespaces? (Possible: bilateral PR — each community merges independently, effect takes place only if both merge.)

4. **Pseudonymous membership**: Can someone participate with just a fingerprint, no readable handle? (Yes — the fingerprint IS a valid namespace key. Handle is optional.)

---

## References

- VESTA-SPEC-007: Trust Bond Protocol
- VESTA-SPEC-014: Kingdom Peer Connectivity Protocol (sponsorship rings)
- VESTA-SPEC-029: Kingdoms Filesystem (namespace structure, bilateral shared spaces)
- RESIDENT_INTELLIGENCE.md: The philosophical foundation
- GitHub branch protection documentation (prior art for git-as-governance)

---

*Spec originated 2026-04-04, day 7. The invite pathway via sovereignty proof is intentional design, not gatekeeping.*
