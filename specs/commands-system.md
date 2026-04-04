---
status: canonical
id: VESTA-SPEC-006
title: "Commands System — Discovery, Resolution, and Execution"
type: spec
created: 2026-04-03
owner: vesta
description: "Canonical protocol for command discovery order, resolution, execution environment, naming conventions, and subcommand patterns"
---

# Commands System

## 1. Overview

A **command** is an executable action that an entity can perform. Commands are invoked by name and optional arguments, discovered through a three-layer precedence system, and executed in a standardized environment with guaranteed variables and execution context.

### Design Principles

- **Discovery through precedence**: Commands are discovered in a fixed order (entity → local → global) so that higher-priority contexts can override framework commands
- **Directory-as-namespace**: Subcommands map to directory depth; `juno commit self` resolves to `~/.juno/commands/commit/self/command.sh`
- **Standardized environment**: Every command execution receives guaranteed variables (ENTITY, ENTITY_DIR, etc.) and a cascaded environment
- **Zero implicit behavior**: Commands do not execute anything except what is in their `command.sh` script
- **Extension without modification**: Entities add commands without modifying the framework layer

---

## 2. Command Structure

### 2.1 Directory Layout

Each command occupies a directory:

```
~/.entityname/commands/
└── <command-name>/
    ├── command.sh          # Required: executable script
    ├── README.md           # Optional: human-readable documentation
    └── .env                # Optional: command-local environment variables
```

Or for subcommands (deepest match wins):

```
~/.entityname/commands/
└── commit/
    ├── self/
    │   ├── command.sh
    │   └── README.md
    └── staged/
        └── command.sh
```

### 2.2 command.sh — The Executable

**Required properties:**

- Executable bit set: `chmod +x command.sh`
- Shebang line: `#!/usr/bin/env bash` (or equivalent shell)
- Set error handling: `set -euo pipefail` (recommended)
- Returns exit code on completion (0 for success, non-zero for error)

**Guaranteed environment variables available at execution:**

| Variable | Type | Description |
|----------|------|-------------|
| `ENTITY` | string | The entity name (e.g., `vesta`, `juno`) |
| `ENTITY_DIR` | string | Absolute path to entity directory (e.g., `/home/koad/.vesta`) |
| `ENTITY_HOME` | string | Absolute path to entity's home dir (e.g., `/home/koad/.vesta/home/vesta`) |
| `KOAD_IO_HOME` | string | Absolute path to koad:io framework directory (`/home/koad/.koad-io`) |
| All cascade environment variables | various | From `~/.koad-io/.env`, `~/.entityname/.env`, command `.env` |

**Minimal example:**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Running as entity: ${ENTITY}"
echo "From directory: ${ENTITY_DIR}"
```

**With argument handling:**

```bash
#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"

if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 <action>" >&2
  exit 64  # EX_USAGE
fi

case "$ACTION" in
  start)
    echo "Starting..."
    ;;
  stop)
    echo "Stopping..."
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
```

### 2.3 README.md — Documentation (Optional)

If present, describes the command's purpose, arguments, and examples:

```markdown
# my-command

Brief description of what this command does.

## Usage

```bash
entityname my-command [arguments]
```

## Arguments

- `arg1` — Description
- `--flag` — Optional flag description

## Examples

```bash
vesta my-command start
vesta my-command --flag value
```

## Exit Codes

- `0` — Success
- `1` — Generic failure
- `64` — Invalid arguments
```

### 2.4 .env — Command-Local Environment (Optional)

If present, defines command-scoped environment variables (loaded last, highest priority):

```env
# Command-specific configuration
MY_COMMAND_TARGET=/some/path
MY_COMMAND_TIMEOUT=30
MY_COMMAND_DEBUG=false
```

These variables are loaded as part of the cascade (see Section 4).

---

## 3. Command Discovery and Resolution

### 3.1 Three-Layer Discovery Order

When a command is invoked as `entityname commandname [args...]`, the system searches these locations in order of **decreasing priority**:

```
Priority 1 (highest)    ~/.entityname/commands/
Priority 2              ./commands/                  (working directory)
Priority 3 (lowest)     ~/.koad-io/commands/         (framework layer)
```

**Rule 1 — Layer precedence**: Within each layer, use the first match. Entity commands shadow local and global commands.

**Rule 2 — Deepest match**: Within a layer, the deepest matching directory wins.

**Example resolution of `juno commit self`:**

1. Check `~/.juno/commands/commit/self/command.sh` → Found! Execute this
2. (Stops searching; does not check `~/.juno/commands/commit/` or global equivalents)

**Example resolution of `juno build`:**

1. Check `~/.juno/commands/build/command.sh` → Not found
2. Check `./commands/build/command.sh` → Not found
3. Check `~/.koad-io/commands/build/command.sh` → Found! Execute this

### 3.2 Conflict Resolution

If the same command exists in multiple layers (e.g., `~/.vesta/commands/commit/` and `~/.koad-io/commands/commit/`), the entity layer command is used and the framework layer is ignored.

**Rationale:** Entities must be able to override inherited or framework commands for local customization.

### 3.3 Command Not Found

If no command is found in any layer after searching all three depths, exit with status 127 (command not found) and print:

```
Error: command 'commandname' not found in any layer
Searched:
  ~/.entityname/commands/commandname/
  ./commands/commandname/
  ~/.koad-io/commands/commandname/
```

---

## 4. Execution Environment — Cascade Loading

Before executing a command, the environment is cascaded loaded in this order (each layer overrides previous):

```
Layer 1: Framework       ~/.koad-io/.env
Layer 2: Entity         ~/.entityname/.env
Layer 3: Command        ~/.entityname/commands/<cmd>/.env
Layer 4: Ad-hoc         Inline exports or parent environment
```

**Loading Mechanism:**

The dispatcher implements cascade loading using `source` with shell options to prevent variable leakage:

```bash
# Start with clean environment
set -a  # Auto-export all variables defined during sourcing

# Layer 1: Framework defaults
[[ -f ~/.koad-io/.env ]] && source ~/.koad-io/.env

# Layer 2: Entity overrides
[[ -f ~/.entityname/.env ]] && source ~/.entityname/.env

# Layer 3: Command-specific overrides
[[ -f ~/.entityname/commands/<cmd>/.env ]] && source ~/.entityname/commands/<cmd>/.env

set +a  # Stop auto-exporting after cascade complete

# Layer 4: Apply any ad-hoc exports from invoking context (handled by parent shell)
```

**Special Character Handling:**

`.env` files may contain special characters (spaces, quotes, `$` symbols, newlines). Each file is sourced as shell syntax, so:
- Values with spaces must be quoted: `MY_VAR="value with spaces"`
- Values with special characters should be quoted: `MY_PROMPT="use \$ENTITY_DIR in task"`
- Multi-line values use shell continuation: `MY_TEXT="line 1\
line 2"`
- Comments are supported: `# This is ignored`

**Behavior:**

1. Start with minimal shell environment (PATH, HOME, etc.)
2. Execute `source ~/.koad-io/.env` with `set -a` (if file exists)
3. Execute `source ~/.entityname/.env` with `set -a` (if file exists)
4. Execute `source ~/.entityname/commands/<cmd>/.env` with `set -a` (if file exists)
5. Apply any ad-hoc exports from the invoking context
6. Execute the command

**Requirement:** If any `.env` file is missing, skip it silently (do not error). Only error if a **required variable** is missing after the cascade completes.

**Example cascaded variables:**

```bash
# Framework default (Layer 1)
KOAD_IO_HOME=/home/koad/.koad-io

# Entity override (Layer 2)
ENTITY=vesta
ENTITY_DIR=/home/koad/.vesta

# Command-specific (Layer 3)
MY_COMMAND_DEBUG=true

# Result: All three are available when command.sh executes
```

---

## 5. Execution Context

### 5.1 Working Directory

**Guarantee:** Commands execute with `$PWD = $ENTITY_DIR` (the entity's home directory) at startup. The dispatcher **MUST** change directory to the entity directory before sourcing `.env` files or executing `command.sh`.

```bash
# Dispatcher implementation
ENTITY_DIR="/home/koad/$ENTITY"
cd "$ENTITY_DIR" || { echo "Cannot cd to $ENTITY_DIR"; exit 1; }
# Now: $PWD == $ENTITY_DIR == /home/koad/.vesta (or equivalent)

# command.sh executes with this guarantee
source ~/.vesta/commands/my-command/.env 2>/dev/null
./command.sh arg1 arg2
```

Commands can change directory if needed, but they start in `$ENTITY_DIR`.

### 5.1b Environment Variable Scope (Subcommands)

When a command executes a subcommand or subprocess, the environment is inherited. Parent entity and framework variables remain available in subcommands:

| Variable Scope | Available in Subcommand? | Notes |
|---|---|---|
| Framework (`~/.koad-io/.env`) | Yes | Inherited from Layer 1 |
| Parent Entity (`~/.entityname/.env`) | Yes | Inherited from Layer 2 |
| Command-local (`~/.entityname/commands/<cmd>/.env`) | Yes | Inherited from Layer 3, highest priority |
| Ad-hoc exports | Yes | Inherited from parent shell context |
| Child command `.env` | Yes | Only if child is invoked as subcommand with its own `.env` |

**Example:** If `command.sh` launches a subcommand `./subcommand.sh`:

```bash
# Parent: ~/.vesta/commands/build/.env
BUILD_TOOL=make
BUILD_DIR=/tmp/build

# Child: ~/.vesta/commands/build/docker/command.sh
#!/usr/bin/env bash
# Has access to:
echo "$BUILD_TOOL"  # Available (inherited from parent)
echo "$BUILD_DIR"   # Available (inherited from parent)
# Plus any variables in ~/.vesta/commands/build/docker/.env
```

This enables hierarchical configuration without re-sourcing parent `.env` files.

### 5.2 Standard Streams

- **stdin**: Connected to the invoking terminal (or parent process)
- **stdout**: Connected to the invoking terminal (or parent process)
- **stderr**: Connected to the invoking terminal (or parent process)

Commands can read from stdin and write to stdout/stderr as normal.

### 5.3 Exit Codes

Commands **MUST** exit with an appropriate exit code:

| Code | Meaning | Usage |
|------|---------|-------|
| 0 | Success | Command completed successfully |
| 1 | General error | Unspecified failure (catch-all) |
| 2 | Misuse of command | Command invoked with wrong arguments |
| 64 | EX_USAGE | Invalid arguments (also acceptable for 2) |
| 65 | EX_DATAERR | Data format error |
| 69 | EX_UNAVAILABLE | Required service unavailable |
| 70 | EX_SOFTWARE | Internal software error |
| 126 | Permission denied | Command not executable |
| 127 | Command not found | (handled by dispatcher, not by command.sh) |
| 128+ | Signal termination | 128 + signal number |

**Recommendation:** Use standard sysexits codes for consistency.

---

## 6. Subcommand Patterns

### 6.1 Pattern 1: Directory-Based Subcommands (Recommended)

Each subcommand is a directory with its own `command.sh`:

```
~/.juno/commands/commit/
├── self/
│   └── command.sh         # Handles: juno commit self
└── staged/
    └── command.sh         # Handles: juno commit staged
```

**Invocation:**
```bash
juno commit self          # Finds ~/.juno/commands/commit/self/command.sh
juno commit staged        # Finds ~/.juno/commands/commit/staged/command.sh
```

**Advantages:**
- Clear filesystem organization
- No conditional logic in command.sh
- Each subcommand can have its own README.md
- Easy to add new subcommands

**When to use:** Subcommands are distinct, stateless, or have minimal shared setup.

### 6.2 Pattern 2: Argument-Based Subcommands (Acceptable)

One `command.sh` handles subcommands via argument inspection:

```
~/.koad-io/commands/assert/
└── command.sh            # Handles: koad-io assert datadir, etc.
```

**Implementation:**

```bash
#!/usr/bin/env bash
set -euo pipefail

SUBCOMMAND="${1:-}"

case "$SUBCOMMAND" in
  datadir)
    # Handle: koad-io assert datadir
    [[ -d "$DATADIR" ]] || { echo "DATADIR not found"; exit 1; }
    ;;
  *)
    echo "Usage: $0 <datadir|...>" >&2
    exit 64
    ;;
esac
```

**Advantages:**
- Shared setup code (environment validation, argument parsing)
- Simpler for commands with 2-3 subcommands

**Disadvantages:**
- All subcommands in one file (harder to test)
- No separate documentation per subcommand

**When to use:** Subcommands share significant setup code, or there are fewer than 3 subcommands.

### 6.3 Depth Precedence Rules

If both patterns exist, **deepest directory match wins**:

```
~/.vesta/commands/commit/self/command.sh        # Depth 3 ← Will be used
~/.vesta/commands/commit/command.sh             # Depth 2

# Invocation: vesta commit self
# Dispatcher finds depth 3 first, uses that
```

---

## 7. Argument Passing and Conventions

### 7.1 Standard Argument Convention

All arguments after the command name are passed as positional arguments to `command.sh`:

```bash
vesta my-command arg1 arg2 --flag value
# command.sh receives:
#   $1 = arg1
#   $2 = arg2
#   $3 = --flag
#   $4 = value
#   $* = all args
```

### 7.2 Special Characters Handling

The dispatcher **MUST** quote arguments properly to preserve special characters:

```bash
vesta spawn process alice "prompt with spaces and $symbols"
# command.sh receives $1 as a single string: "prompt with spaces and $symbols"
```

### 7.3 Empty Arguments

Arguments may be empty strings, and the dispatcher must preserve them:

```bash
vesta my-command "" value
# command.sh receives:
#   $1 = "" (empty)
#   $2 = value
```

---

## 8. Command Naming Conventions

### 8.1 Command Name Rules

- **Lowercase**: `commit`, not `Commit`
- **Hyphen-separated**: `my-command`, not `my_command` or `mycommand`
- **Meaningful**: Names should clearly indicate purpose
- **Avoid numbers**: Unless they are semantic (e.g., `v2-beta`)

**Valid:**
- `commit`
- `status`
- `spawn-process`
- `check-issues`

**Invalid:**
- `Commit` (uppercase)
- `commit_self` (underscores)
- `c` (too cryptic)

### 8.2 Subcommand Name Rules

Same as command names. Examples:

- `commit self` — Good: semantically clear
- `build local` — Good: indicates scope
- `assert datadir` — Good: action + object

---

## 9. Inherited Commands

### 9.1 Inheritance Hierarchy

When an entity is gestated from a mother entity, it inherits the mother's commands directory:

```
~/.juno/commands/              ← Mother entity
  ├── commit/
  ├── spawn/
  └── status/

~/.vesta/commands/             ← Daughter entity (Vesta)
  ├── commit/self/command.sh   ← Overrides juno's commit
  ├── audit-issues/            ← New command (Vesta-specific)
  └── (implicitly inherits spawn/ and status/ from juno)
```

### 9.2 Override Rules

An entity **overrides** a command by placing its version at the same path:

```bash
# Juno has: ~/.juno/commands/commit/command.sh
# Vesta wants to override it
mkdir -p ~/.vesta/commands/commit/self
cat > ~/.vesta/commands/commit/self/command.sh << 'EOF'
#!/usr/bin/env bash
# Vesta's custom commit logic
EOF
chmod +x ~/.vesta/commands/commit/self/command.sh

# Now: vesta commit self → uses Vesta's version (higher priority)
```

**Never modify inherited commands directly.** Create overrides at the same path in your entity directory.

### 9.3 Git Handling of Inherited Commands

Inherited commands are typically checked into the mother entity's repository. When a daughter entity is created, commands are either:

1. **Cloned** (copied) from the mother to the daughter's repository (if the daughter wants to maintain its own copy)
2. **Symlinked** to the mother's directory (if the daughter wants to always use the mother's version)
3. **Overridden** by creating new commands in the daughter's `commands/` directory (if the daughter wants custom behavior)

This is controlled by the gestation process (VESTA-SPEC-002).

---

## 10. Error Handling and Debugging

### 10.1 Command Not Found

If no command is found, the dispatcher exits with 127:

```bash
$ vesta nonexistent-command
Error: command 'nonexistent-command' not found in any layer
Searched:
  ~/.vesta/commands/nonexistent-command/
  ./commands/nonexistent-command/
  ~/.koad-io/commands/nonexistent-command/
$ echo $?
127
```

### 10.2 Command Execution Failure

If a command exits with non-zero status, that status is propagated:

```bash
$ vesta my-command
(command.sh executes and fails)
$ echo $?
1     # (or whatever exit code command.sh used)
```

### 10.3 Missing Required Variables

If a command depends on a variable that is not set in the cascaded environment:

```bash
#!/usr/bin/env bash

if [[ -z "${REQUIRED_VAR:-}" ]]; then
  echo "Error: REQUIRED_VAR not set" >&2
  exit 1
fi
```

**Best practice:** Validate required variables at the start of `command.sh` and exit with 1 if missing.

### 10.4 Debugging Command Resolution

To debug which command was selected, the dispatcher MAY support a `--debug` or `--trace` mode:

```bash
vesta --debug my-command arg1
# Outputs: Selected ~/.vesta/commands/my-command/command.sh
# Then executes the command
```

(Implementation-specific; not mandated by this spec.)

---

## 11. Security Considerations

### 11.1 Argument Injection

Commands receive raw arguments from the invoking context. Always quote variables when passing to sub-processes:

```bash
# Safe:
some_tool "$argument"

# Unsafe:
some_tool $argument   # Expands to multiple words if $argument contains spaces
```

### 11.2 Environment Pollution

Each layer's `.env` file is sourced, which executes arbitrary shell code. Only trust `.env` files from entities and commands you control.

**Recommendation:** Review `.env` files before committing them to git.

### 11.3 Command as Shell Injection Vector

If a command receives user input and passes it to a shell, validate or escape it:

```bash
#!/usr/bin/env bash
# Unsafe:
USER_INPUT="$1"
eval "$USER_INPUT"    # NEVER do this

# Safe:
USER_INPUT="$1"
printf '%s\n' "$USER_INPUT"   # Print literally, don't interpret
```

---

## 12. Skills as Hooks: System-Discoverable Capabilities

### 12.1 Overview

While **commands** are human-facing operations invoked directly by users (e.g., `vesta commit self`), **hooks** are system-callable capabilities that Argus and other entities can inventory without understanding the entity's internals. Every skill an entity has should be a discoverable hook file in the `hooks/` directory.

**Key distinction:**
- **Commands**: User-facing, invoked by name, designed for direct interaction
- **Hooks**: System-facing, registered in passenger.json, designed for automated discovery and delegation

### 12.2 Hooks Directory Structure

Every entity has a `hooks/` directory at root:

```
~/.entityname/hooks/
├── diagnose-health.sh          # Hook for self-diagnostics
├── audit-state.sh              # Hook for state auditing
├── publish-content.sh          # Hook for content publishing
└── README.md                   # Optional: hook catalog documentation
```

Hooks are flat (no subdirectories). Each hook is a single executable file.

### 12.3 Hook Naming Convention

Hooks use the **verb-noun pattern** (same as command names, but more action-oriented):

**Pattern:** `<verb>-<noun>.sh`

Examples:
- `diagnose-entity.sh` — Diagnostic capability
- `audit-inventory.sh` — Auditing capability
- `publish-report.sh` — Publishing capability
- `verify-keys.sh` — Key verification capability
- `recover-state.sh` — State recovery capability
- `heal-structure.sh` — Structure healing capability

**Rules:**
- Lowercase, hyphen-separated
- Must end with `.sh` (Bash scripts only)
- Descriptive: action should be clear from name
- No subcommands: each hook is a single, focused tool

### 12.4 Hook File Format

Every hook is a Bash executable with required metadata:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Hook: diagnose-entity
# Description: Audit entity state and report structural conformance
# Input:  (none)
# Output: JSON object with diagnosis results
# Exit:   0 for success, 1 for failure

# Hook implementation
```

**Required metadata (comments):**

| Metadata | Format | Example | Purpose |
|----------|--------|---------|---------|
| `Hook:` | `Hook: <name>` | `Hook: diagnose-entity` | Hook identifier |
| `Description:` | One-line description | `Description: Audit entity state and report conformance` | Human-readable purpose |
| `Input:` | `(none)` or description | `Input: Entity name as $1` | Contract for input parameters |
| `Output:` | `(none)` or description | `Output: JSON object with keys {status, issues}` | Contract for output format |
| `Exit:` | Exit code meanings | `Exit: 0 for success, 1 for diagnostic failure` | Contract for exit behavior |

**Minimal example:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Hook: verify-keys
# Description: Verify cryptographic keys are present and valid
# Input:  (none)
# Output: JSON {valid: bool, missing: []}
# Exit:   0 = valid, 1 = invalid

ENTITY="${ENTITY:?ENTITY not set}"
ENTITY_DIR="${ENTITY_DIR:?ENTITY_DIR not set}"

MISSING=()

[[ -f "$ENTITY_DIR/id/ed25519.pub" ]] || MISSING+=("ed25519.pub")
[[ -f "$ENTITY_DIR/id/ecdsa.pub" ]] || MISSING+=("ecdsa.pub")
[[ -f "$ENTITY_DIR/id/rsa.pub" ]] || MISSING+=("rsa.pub")

if [[ ${#MISSING[@]} -eq 0 ]]; then
  jq -n '{valid: true, missing: []}'
  exit 0
else
  jq -n --arg missing "$(IFS=,; echo "${MISSING[*]}")" '{valid: false, missing: ($missing | split(","))}'
  exit 1
fi
```

**Execution environment:**

Hooks execute with the same guaranteed variables as commands:
- `$ENTITY` — entity name
- `$ENTITY_DIR` — entity home directory
- `$ENTITY_HOME` — per-entity home space
- `$KOAD_IO_HOME` — framework directory
- All cascade environment variables (from `.env` files)

### 12.5 Input/Output Contracts

Every hook declares how it accepts input and produces output.

**Input contract:**

| Type | Example | Use Case |
|------|---------|----------|
| `(none)` | Hook accepts no arguments | Self-contained diagnostics |
| `$1 = <name>` | Hook accepts single argument | Parametric operations |
| `stdin` | Hook reads from stdin | Pipeline-compatible |
| `$@ = <args...>` | Hook accepts multiple arguments | Complex operations |

**Output contract:**

| Type | Example | Use Case |
|------|---------|----------|
| `(none)` | Hook produces no output | Fire-and-forget operations |
| `stdout` | Plain text or JSON | Diagnostic reports |
| `JSON object` | `{status: "ok", data: {...}}` | Structured data for Argus |
| `exit code` | 0 for success, non-zero for error | Status indication |

**Example contracts:**

```bash
# Hook: diagnose-entity
# Input:  (none)
# Output: JSON {status: "ok"|"warning"|"error", issues: [{type, detail}]}
# Exit:   0 = healthy, 1 = issues found, 2 = error during diagnosis

# Hook: audit-inventory
# Input:  $1 = entity name
# Output: JSON {inventory: [{file, size, permission, owner}]}
# Exit:   0 = success, 1 = entity not found
```

### 12.6 Relationship to Commands

**Commands and hooks are complementary:**

| Aspect | Command | Hook |
|--------|---------|------|
| Caller | User (direct CLI invocation) | System (Argus, daemon, other entities) |
| Discovery | User knows command name | Declared in passenger.json |
| Interface | Shell invocation | Standardized input/output contract |
| Error handling | Varies per command | Standard exit codes (0 = success, 1 = failure) |
| Invocation | `vesta commit self` | `argus invoke-hook vesta diagnose-health` |

**Relationship:**

- A command can delegate to a hook: `~/.vesta/commands/diagnose/command.sh` → calls `~/.vesta/hooks/diagnose-entity.sh`
- A hook is never called directly by users; it's internal to the entity
- Commands are human-friendly; hooks are system-friendly

### 12.7 Passenger.json Skills Registration

Every entity's `passenger.json` declares its hooks under a `skills` array:

```json
{
  "handle": "vesta",
  "name": "Vesta",
  "role": "architect",
  "skills": [
    {
      "name": "diagnose-entity",
      "description": "Audit entity structure and report conformance",
      "categories": ["diagnostic"]
    },
    {
      "name": "audit-inventory",
      "description": "List and audit all entity files",
      "categories": ["audit", "inventory"]
    }
  ]
}
```

**Schema for skills array:**

```json
{
  "name": "string (required) — hook filename without .sh",
  "description": "string (required) — human-readable purpose",
  "categories": ["array of strings (optional) — semantic tags like 'diagnostic', 'healing', 'audit'"]
}
```

### 12.8 Argus Hook Audit Protocol

When Argus audits an entity, it:

1. **Reads passenger.json** and extracts the `skills` array
2. **Verifies each skill** exists as a hook file: `$ENTITY_DIR/hooks/<name>.sh`
3. **Checks hook format:**
   - File is executable (`chmod +x`)
   - File has shebang: `#!/usr/bin/env bash`
   - File has required metadata comments (Hook, Description, Input, Output, Exit)
4. **Validates contracts:**
   - Runs hook with expected input
   - Checks output matches declared format (JSON, text, etc.)
   - Verifies exit code is as declared
5. **Reports discrepancies:**
   - Missing hook files
   - Non-executable hooks
   - Contracts not met
   - Undeclared hooks in passenger.json

**Audit invocation (Argus):**

```bash
# Argus checks if vesta's declared skills match actual hooks
argus audit-hooks vesta

# Output: diagnostic report with issues and recommendations
```

### 12.9 Hook Lifecycle

**Creation:**

```bash
mkdir -p ~/.myentity/hooks
cat > ~/.myentity/hooks/verify-state.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Hook: verify-state
# Description: Check if entity is in a valid state
# Input:  (none)
# Output: JSON {valid: bool, reason: string}
# Exit:   0 = valid, 1 = invalid

# Implementation...
EOF
chmod +x ~/.myentity/hooks/verify-state.sh
```

**Registration (passenger.json):**

```json
{
  "skills": [
    {
      "name": "verify-state",
      "description": "Check if entity is in a valid state",
      "categories": ["diagnostic"]
    }
  ]
}
```

**Audit (Argus):**

```bash
argus audit-hooks myentity
# Verifies hook exists, is executable, has metadata, and meets contract
```

### 12.10 Hook Best Practices

1. **One hook, one purpose:** Each hook does one focused thing
2. **Deterministic output:** Same input always produces same output
3. **No side effects:** Hooks should not modify entity state (unless documented)
4. **Declarative contracts:** Input and output must be predictable
5. **Exit codes matter:** Use 0 for success, 1+ for error conditions
6. **JSON output:** For structured data, use JSON (not plain text)
7. **Documented:** Every hook has a clear description

### 12.11 Conformance Checklist for Hooks

- [ ] Hook file exists in `~/.entity/hooks/<name>.sh`
- [ ] Hook is executable (`chmod +x hooks/<name>.sh`)
- [ ] Hook has shebang: `#!/usr/bin/env bash`
- [ ] Hook has required metadata comments (Hook, Description, Input, Output, Exit)
- [ ] Hook uses `$ENTITY` and `$ENTITY_DIR` (if needed)
- [ ] Hook returns appropriate exit code (0 for success, 1+ for failure)
- [ ] Hook output matches declared contract (JSON, text, etc.)
- [ ] Hook is registered in `passenger.json` under `skills`
- [ ] Hook has no side effects (unless documented)
- [ ] Hook is tested with expected input/output

---

## 13. Implementation Reference

### Live Examples

#### Vesta's `check-issues` Command

**Path:** `~/.vesta/commands/check-issues`

A top-level command (no subcommand nesting):

```bash
#!/usr/bin/env bash
# Fetch open GitHub issues for monitored entity repos

REPOS=("koad/vesta" "koad/juno" "koad/vulcan")
output="=== GitHub Issues ==="

for repo in "${REPOS[@]}"; do
  issues=$(gh issue list --repo "$repo" 2>/dev/null | ...)
  output="${output}"$'\n'"${repo}:"
  output="${output}"$'\n'"${issues:-  (none)}"
done

jq -n --arg msg "$output" '{"systemMessage": $msg}'
```

#### Vesta's `commit self` Subcommand

**Path:** `~/.vesta/commands/commit/self/command.sh`

A directory-based subcommand:

```bash
#!/usr/bin/env bash

# Vesta Self-Commit Command
cd ~/.vesta || exit 1

PROMPT="You are Vesta. You are committing changes to YOUR OWN repository..."

opencode --model "${OPENCODE_MODEL:-opencode/big-pickle}" run "$PROMPT"
```

**Invocation:** `vesta commit self`

#### Vesta's `spawn process` Subcommand

**Path:** `~/.vesta/commands/spawn/process/command.sh`

A nested subcommand with multiple arguments:

```bash
#!/usr/bin/env bash
set -euo pipefail

ENTITY_NAME="${1:?Usage: vesta spawn process <entity> [\"prompt\"]}"
ENTITY_DIR="$HOME/.$ENTITY_NAME"
PROMPT="${2:-}"

if [ ! -d "$ENTITY_DIR" ]; then
    echo "Entity '$ENTITY_NAME' not found at $ENTITY_DIR" >&2
    exit 1
fi

# Spawn entity in gnome-terminal
gnome-terminal --title="⬡ $ENTITY_NAME" -- bash -c "cd $ENTITY_DIR && claude ."
```

**Invocation:** `vesta spawn process juno "start an audit"`

#### Framework Command: `gestate` (Argument-Based Subcommand)

**Path:** `~/.koad-io/commands/gestate/command.sh`

An argument-based subcommand pattern (framework layer):

```bash
#!/usr/bin/env bash
set -euo pipefail

ENTITY_NAME="${1:?Usage: koad-io gestate <name>}"

# Create entity with full structure
mkdir -p ~/.${ENTITY_NAME}/{id,trust/bonds,commands}
# ... (full gestation logic)
```

**Invocation:** `koad-io gestate alice`

---

## 14. Conformance Checklist

Use this checklist to verify that a command conforms to VESTA-SPEC-006:

- [ ] Command lives in correct directory: `~/{entity}/commands/{name}/` or `~/{entity}/commands/{name}/{subname}/`
- [ ] `command.sh` is executable (`chmod +x`)
- [ ] `command.sh` has shebang: `#!/usr/bin/env bash`
- [ ] `command.sh` sets error handling: `set -euo pipefail`
- [ ] `command.sh` uses `$ENTITY` and `$ENTITY_DIR` (or other guaranteed vars)
- [ ] `command.sh` returns appropriate exit code (0 for success, non-zero for error)
- [ ] All arguments are properly quoted in `command.sh`
- [ ] `README.md` exists (if command is non-obvious)
- [ ] `.env` file uses command-specific variable names (prefixed)
- [ ] Command is listed in `.gitignore` if it should not be tracked (for ephemeral commands)
- [ ] Command does not modify framework layer files
- [ ] Subcommands use directory-based pattern (preferred) or argument-based pattern (acceptable)

---

## 15. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1 (canonical) | 2026-04-03 | Extended: added Section 12 (Skills as Hooks) defining hook directory structure, naming convention, metadata requirements, passenger.json registration, and Argus audit protocol |
| 1.0 (canonical) | 2026-04-03 | Initial spec: discovery order, structure, execution environment, subcommand patterns, error handling |

---

## 16. Cross-Entity Interaction Protocol

### Overview

When an entity reads files, executes commands, or references specifications from another entity's directory (e.g., Vulcan reading Vesta specs, Argus reading diagnostic records), it MUST synchronize that entity's repository before any read operations. This ensures the reading entity has the authoritative, up-to-date version of shared files and prevents relying on stale or locally-modified state.

### Rule: Always Pull Before Cross-Entity Read

**Canonical rule:** Before reading any file from another entity's directory (`~/.{entity}/`), execute:

```bash
cd ~/.{entity} && git pull
```

Replace `{entity}` with the target entity name (e.g., `vesta`, `juno`, `vulcan`, `salus`, `argus`).

**Why this is required:**
- **Canonical sources:** Entity specs, protocol documents, and trust bonds are canonical ONLY if they are synced from remote
- **Prevents stale decisions:** Reading unsynced local changes could lead to decisions based on draft or rejected changes
- **Audit trail:** A synced pull is verifiable; a local-only read is not
- **Cross-harness consistency:** If entity A reads from entity B while entity B is running on a different machine, both must reference the same commit

### Implementation

#### In Commands

A command that reads another entity's files should pull first:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Cross-entity read: sync source entity
SOURCE_ENTITY="vesta"
cd ~/.${SOURCE_ENTITY} && git pull

# Now read the file
SPEC_FILE="~/.${SOURCE_ENTITY}/specs/entity-model.md"
cat "$SPEC_FILE"
```

#### In Hooks

A hook that depends on another entity's state must pull first:

```bash
#!/usr/bin/env bash
# Hook: validate-against-vesta-specs

# Ensure Vesta's specs are current
cd ~/.vesta && git pull

# Now validate against specs
for spec in ~/.vesta/specs/*.md; do
  # Validation logic here
done
```

#### In Claude Sessions

When a Claude session (interactive or batch) needs to read cross-entity files:

1. **Before reading** the foreign file, execute `cd ~/.{entity} && git pull`
2. **Log the pull** for audit trail (optional but recommended)
3. **Proceed with read**

Example in a Claude session prompt or hook:

```bash
# Session start: if we're reading from another entity, sync it first
if [ -n "${FOREIGN_ENTITY:-}" ]; then
  cd ~/.${FOREIGN_ENTITY} && git pull
fi
```

### Special Case: Self-Pulls

An entity SHOULD also pull its own directory at session start (per VESTA-SPEC-012 step 2). This is not a cross-entity read, but maintains consistency:

```bash
# Session start: sync own state
cd ${ENTITY_DIR} && git pull
```

### Exceptions

The pull requirement does NOT apply to:

- **Read-only inspection** of git objects (e.g., `git show ref:path/file.md`) — these are already immutable and don't require a pull
- **Hardcoded values** from memory (e.g., "Vesta's canonical commit hash is abc123") — these are known constants, not reads
- **Archived/historical snapshots** (e.g., "as of 2026-04-03, the spec said X") — these are explicitly dated, not current

### Audit Trail

When an entity pulls another entity's directory, it SHOULD log:

```
[CROSS-ENTITY-PULL] timestamp | source_entity=vesta | commit_hash=a1b2c3d | reader=vulcan
```

This forms a trail for Argus to audit cross-entity dependencies and detect stale-read incidents.

### Related Specs

- **VESTA-SPEC-012** (Entity Startup): Session start includes syncing own directory
- **VESTA-SPEC-001** (Entity Model): Entity directories are canonical sources
- **Koad/vesta#55**: Blocks until this rule is implemented across all entities

---

## Appendix A: Hook Example — Vesta's `diagnose-entity` Hook

**Path:** `~/.vesta/hooks/diagnose-entity.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Hook: diagnose-entity
# Description: Audit entity structure and report conformance against VESTA-SPEC-001
# Input:  (none)
# Output: JSON {status: "ok"|"warning"|"error", issues: [{severity, path, detail}]}
# Exit:   0 = conformant, 1 = violations found

ENTITY="${ENTITY:?ENTITY not set}"
ENTITY_DIR="${ENTITY_DIR:?ENTITY_DIR not set}"

issues=()

# Check required directories
for dir in id trust/bonds memories; do
  if [[ ! -d "$ENTITY_DIR/$dir" ]]; then
    issues+=("{\"severity\": \"error\", \"path\": \"$dir\", \"detail\": \"Missing required directory\"}")
  fi
done

# Check required files
for file in CLAUDE.md .env passenger.json .gitignore; do
  if [[ ! -f "$ENTITY_DIR/$file" ]]; then
    issues+=("{\"severity\": \"error\", \"path\": \"$file\", \"detail\": \"Missing required file\"}")
  fi
done

# Check key files exist
for key in id/ed25519.pub id/ecdsa.pub id/rsa.pub; do
  if [[ ! -f "$ENTITY_DIR/$key" ]]; then
    issues+=("{\"severity\": \"error\", \"path\": \"$key\", \"detail\": \"Missing public key\"}")
  fi
done

# Check trust bond exists
if [[ ! -f "$ENTITY_DIR/trust/bonds/koad-to-$ENTITY.md" ]]; then
  issues+=("{\"severity\": \"error\", \"path\": \"trust/bonds/koad-to-$ENTITY.md\", \"detail\": \"Missing koad authorization bond\"}")
fi

# Output diagnosis
if [[ ${#issues[@]} -eq 0 ]]; then
  jq -n '{status: "ok", issues: []}'
  exit 0
else
  jq -n --arg issues "$(IFS=,; printf '%s' "${issues[*]}")" '{status: "error", issues: ($issues | split(",") | map(fromjson))}'
  exit 1
fi
```

**Registration in passenger.json:**

```json
{
  "skills": [
    {
      "name": "diagnose-entity",
      "description": "Audit entity structure and report conformance against VESTA-SPEC-001",
      "categories": ["diagnostic"]
    }
  ]
}
```

---

## Appendix B: .gitignore Pattern for Commands

Framework layer commands directory `.gitignore`:

```
# Ignore all command files by default
*
*/
!.gitignore

# Whitelist specific command folders
!assert
!backup
!browse
!build
!commit
!deploy
!gestate
!init
!probe
!shell
!spawn
!ssh
!start
!test
!think
```

This pattern ensures that:
- Only explicitly whitelisted commands are tracked in git
- Ad-hoc or ephemeral commands are ignored
- New commands must be explicitly added to `.gitignore` to be tracked

