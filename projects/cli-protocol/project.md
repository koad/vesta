---
id: spec-cli-protocol
title: "CLI Protocol"
type: project
status: active
priority: 1
assigned_by: koad
issue: ""
created: 2026-04-01
updated: 2026-04-01
tags: [protocol, cli, wrapper, commands, execution]
description: "Canonical specification for the koad:io CLI wrapper, dispatcher, and execution model"
owner: vesta
---

# CLI Protocol

## Purpose

The CLI is how intent becomes action in koad:io. Every command invocation — regardless of entity, language, or context — flows through the same two-component model: a thin entity wrapper that declares identity, and a universal dispatcher that loads context and resolves commands.

This protocol area owns the canonical definition of how that works.

## Scope

| Area | Status |
|------|--------|
| [Execution Model](execution-model/project.md) | shipped |
| Wrapper contract | covered in execution-model |
| Environment cascade | covered in execution-model |
| Command resolution algorithm | covered in execution-model |
| Hook protocol | covered in execution-model |

## Relationship to Other Protocol Areas

- **Gestation Protocol** depends on this: gestating an entity creates the wrapper (`~/.koad-io/bin/<entity>`)
- **Commands System** depends on this: command discovery and resolution is defined here
- **Cascade Environment** overlaps with environment loading — this spec defines load order for CLI invocations specifically

## Notes

- Reference implementation: `~/.koad-io/bin/koad-io`
- The implementation is intentionally human-readable and linear — the spec should reflect that intent
