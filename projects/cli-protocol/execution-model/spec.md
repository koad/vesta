---
id: spec-execution-model
title: "Execution Model Specification"
type: spec
status: draft
priority: 1
created: 2026-04-02
updated: 2026-04-02
owner: vesta
description: "Canonical definition of CLI wrapper contract, environment loading, command resolution, hook protocol, and invocation flow"
---

# Execution Model

## 1. Wrapper Contract

The wrapper (`~/.koad-io/bin/koad-io`) is the universal entry point for all entity command invocations. It performs:

1. **Identity declaration**: Exports `ENTITY`, `ENTITY_DIR`, `CWD` for the command's context
2. **Environment loading**: Cascades configuration from global → entity → command-specific
3. **Command resolution**: Finds the deepest matching command across discovery paths
4. **Dispatch**: Executes the resolved command with remaining arguments

The wrapper is intentionally linear and human-readable. Each operation corresponds to one logical block.

## 2. Environment Cascade

Environment files are loaded in cascade order, with later loads overriding earlier ones:

| Priority | Source | Files Loaded |
|----------|--------|--------------|
| 1 (lowest) | Global | `~/.koad-io/.env`, `~/.koad-io/.credentials`, `~/.koad-io/.aliases` |
| 2 | Entity | `~/.{entity}/.env`, `~/.{entity}/.credentials` |
| 3 (highest) | Command | `{command_dir}/.env`, `{command_dir}/.credentials` |

Each file is sourced with `set -a` to export all variables automatically. The cascade ensures:
- Global defaults apply to all entities
- Entity-specific config overrides global
- Command-specific config overrides entity

### Environment Variable Derivation

```bash
ENTITY_DIR="$HOME/.$(echo "$ENTITY" | tr '[:upper:]' '[:lower:]')"
```

The entity directory is derived from the `ENTITY` environment variable, lowercased.

## 3. Command Resolution Algorithm

Commands are **directories** containing a `command.sh` entry point, not flat scripts.

### Discovery Order (lowest to highest priority)

1. **Global commands**: `~/.koad-io/commands/`
2. **Entity commands**: `~/.{entity}/commands/`
3. **Local commands**: `./commands/` (current working directory)

Within each priority level, resolution is **deepest match wins** — allowing nested commands like `commit self` to resolve to `~/.juno/commands/commit/self/command.sh`.

### Resolution Algorithm

```
input: command_path = $1 $2 $3 ... (space-separated tokens)

for each priority_level in [global, entity, local]:
    for depth from 1 to 5:
        candidate = {priority_level_commands_dir}/{tokens[0]}/.../{tokens[depth-1]}
        if candidate is a directory:
            set COMMAND_LOCATION = candidate
            set remaining_args = tokens[depth:]
            break  # deepest match wins for this priority level

# After finding COMMAND_LOCATION, resolve execution file:
if {COMMAND_LOCATION}/command.sh exists:
    EXEC_FILE = {COMMAND_LOCATION}/command.sh
else if {COMMAND_LOCATION}/{remaining_args[0]}.sh exists:
    EXEC_FILE = {COMMAND_LOCATION}/{remaining_args[0]}.sh
    remaining_args = remaining_args[1:]

# Fallback: command.sh in CWD matching $1
if {CWD}/{tokens[0]}.sh exists:
    EXEC_FILE = {CWD}/{tokens[0]}.sh
```

### Execution File Precedence

1. `{command_dir}/command.sh` (standard entry point)
2. `{command_dir}/{first_arg}.sh` (named subcommand)
3. `{CWD}/{command}.sh` (cwd fallback)

The wrapper prints the resolved `COMMAND_LOCATION` and `EXEC_FILE` to stderr for transparency.

## 4. Hook Protocol

Hooks are executable scripts triggered by specific conditions when no explicit command is given.

### Hook Naming

Hooks follow the pattern `{hook_name}.sh` stored in:
- `~/.{entity}/hooks/`
- `./hooks/`
- `~/.koad-io/hooks/`

### Hook Resolution (Waterfall)

```
hook trigger condition:
  if no arguments provided → "executed-without-arguments.sh"

resolution order (first match wins):
  1. ~/.{entity}/hooks/{hook_name}.sh
  2. ./hooks/{hook_name}.sh
  3. ~/.koad-io/hooks/{hook_name}.sh
```

If no hook is found, exit with code 64.

### Hook Execution

Hooks are executed via `exec` (replaces the wrapper process) with the current environment cascade loaded.

## 5. End-to-End Invocation Flow

```
user runs: juno commit self

┌─────────────────────────────────────────────────────────────┐
│ WRAPPER: ~/.koad-io/bin/koad-io                           │
├─────────────────────────────────────────────────────────────┤
│ 1. Capture CWD                                             │
│    export CWD=$PWD                                         │
│                                                             │
│ 2. Check for zero arguments                                │
│    → execute hook waterfall if empty                      │
│                                                             │
│ 3. Acknowledge invocation                                  │
│    echo "--koad-io [juno] commit start--"                 │
│                                                             │
│ 4. Load environment cascade                                │
│    a) source ~/.koad-io/.env, .credentials, .aliases     │
│    b) derive ENTITY_DIR from $ENTITY                      │
│    c) source ~/.juno/.env, .credentials                    │
│                                                             │
│ 5. Resolve command                                         │
│    a) search global commands ~/.koad-io/commands/        │
│    b) search entity commands ~/.juno/commands/           │
│    c) search local commands ./commands/                   │
│    d) deepest match wins: commit/self                     │
│                                                             │
│ 6. Resolve execution file                                  │
│    a) ~/.juno/commands/commit/self/command.sh exists    │
│    b) EXEC_FILE=~/.juno/commands/commit/self/command.sh  │
│                                                             │
│ 7. Load command-local env (if any)                         │
│    source {COMMAND_LOCATION}/.env, .credentials           │
│                                                             │
│ 8. Check --dry-run                                         │
│    export DRY_RUN=true if flag present                    │
│                                                             │
│ 9. Execute                                                 │
│    exec ~/.juno/commands/commit/self/command.sh self    │
│    (remaining args: self)                                  │
└─────────────────────────────────────────────────────────────┘
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 64 | No hook found for trigger condition |
| 66 | Command not found |
| 68 | Too many arguments (limit: 9) |

## 6. Reference Implementation Notes

The reference implementation (`~/.koad-io/bin/koad-io`) follows these principles:

- **Linear structure**: One logical block per operation, easily traceable by non-coders
- **Verbose but clear**: Explicit variable names, printed progress markers
- **Fail fast**: Exit with meaningful codes when resolution fails
- **Transparency**: Debug output via `DEBUG=1` environment variable

The script intentionally uses hardcoded `$1` through `$8` for argument handling — this is a known limitation requiring future refactoring to support arbitrary argument counts.
