---
status: draft
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

**Behavior:**

1. Start with minimal shell environment (PATH, HOME, etc.)
2. Source `~/.koad-io/.env` (framework defaults)
3. Source `~/.entityname/.env` (entity overrides)
4. Source `~/.entityname/commands/<cmd>/.env` (command-specific overrides)
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

Commands execute in the **entity directory** (`$ENTITY_DIR`) by default, unless the command explicitly changes directory.

```bash
# Command executes in /home/koad/.vesta
cd ~/.vesta
command.sh
```

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

## 12. Implementation Reference

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

## 13. Conformance Checklist

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

## 14. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 (draft) | 2026-04-03 | Initial spec: discovery order, structure, execution environment, subcommand patterns, error handling |

---

## Appendix A: .gitignore Pattern for Commands

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

