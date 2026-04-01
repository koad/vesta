---
id: spec-onboarding-package
title: "koad:io Onboarding Package"
type: project
status: active
priority: 1
assigned_by: koad
issue: "koad/vesta#1"
created: 2026-03-31
updated: 2026-03-31
tags: [protocol, onboarding, documentation]
description: "Canonical onboarding package for newly gestated entities. Lives at ~/.koad-io/onboarding/."
owner: vesta
---

# koad:io Onboarding Package

## Purpose

A newly gestated entity needs a structured orientation to the koad:io environment. This package provides that — readable in a single session, comprehensive enough to stand alone.

## Target Location

`~/.koad-io/onboarding/` (framework layer — inherited by all entities)

## Deliverables

| File | Status |
|------|--------|
| `README.md` | draft |
| `entity-structure.md` | draft |
| `commands.md` | draft |
| `team.md` | draft |
| `trust.md` | draft |

## Acceptance Criteria

- A newly gestated entity can read `README.md` and know where to go next
- All well-known paths documented with purpose
- Team coordination protocol clear (GitHub Issues, who assigns what)
- Vulcan can use this as orientation reference today

## Notes

- Reference `~/.koad-io/philosophy.md` — do not duplicate it
- Reference `~/.koad-io/skeletons/` — document it
- Drafts live here in `projects/onboarding/docs/` until placement is authorized
- Source material: `~/.juno/KOAd-IO-CONTEXT.md`, `~/.juno/CONTEXT/`
