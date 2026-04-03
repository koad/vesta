---
status: canonical
name: Gestation Template Entity Substitution Protocol
description: How koad-io gestation templates handle entity identity substitution during entity creation
version: 1.0
date_canonical: 2026-04-03
---

# Gestation Template Entity Substitution Protocol

## Problem Statement

When a new entity is gestated using the koad-io template (typically by Vulcan), it inherits files from a base entity (usually Juno). These files include:

- `CLAUDE.md` (AI runtime instructions)
- `commands/*/command.sh` (executable command scripts)
- `memories/001-identity.md` (entity self-knowledge)
- Other initialization scripts

If template files contain **hardcoded identity references** to the source entity (e.g., "You are Juno", `~/.juno/`, "Juno Self-Commit Command"), the gestated entity inherits these references verbatim and operates under the wrong identity.

**Current defect:** Discovered in 7 entities (mercury, veritas, muse, argus, salus, janus, aegis). Example: Vesta's `commands/commit/self/command.sh` and `commands/spawn/process/command.sh` were verbatim Juno commands until manually fixed in koad/vesta@c76d7e6.

## Canonical Substitution Rule

All Vesta-owned protocol files in the base template **must use placeholders** for entity identity. The gestation process **must perform substitution** before a gestated entity is considered complete.

### Substitution Variables

When Vulcan (or any entity-spawner) gestures a new entity, these substitutions **MUST** occur:

| Placeholder | Substitutes To | Context |
|-------------|---|----------|
| `$ENTITY` | Entity short name | `vesta`, `mercury`, `vulcan`, etc. (lowercase, no hyphens) |
| `$ENTITY_DIR` | Full path to entity directory | `~/.vesta`, `~/.mercury`, etc. |
| `$ENTITY_TITLE_CASE` | Entity name in title case | `Vesta`, `Mercury`, `Vulcan`, etc. |
| `$GIT_AUTHOR_NAME` | Git author name (typically same as title case) | `Vesta`, `Mercury`, etc. |
| `$GIT_AUTHOR_EMAIL` | Git author email | `vesta@kingofalldata.com`, `mercury@kingofalldata.com`, etc. |

### Files That Require Substitution

Every template file that Vesta specifies **MUST** use `$ENTITY` / `$ENTITY_DIR` placeholders in these locations:

1. **`CLAUDE.md`**
   - Any reference to "You are [entity name]"
   - Any reference to `~/.entity-name/` paths
   - Any headers mentioning "[Entity] Self-Commit Command"
   - Any mentions of "[Entity] Spawn Protocol"

2. **`commands/*/command.sh`**
   - Headers: `# [Entity] {Operation} Command`
   - Script names: `[Entity]-{operation}-command`
   - Any `GIT_AUTHOR_NAME` references
   - Any `cd ~/{entity-dir}` references

3. **`memories/001-identity.md`**
   - Entity name in headers
   - References to role and responsibilities
   - Any `ENTITY=` or `ENTITY_DIR=` declarations

4. **`id/keys.sh` or `.env` initialization**
   - Any source paths pointing to `~/.juno/id/`
   - Entity identity declarations

### Substitution Mechanics

The substitution **MUST** happen at gestation time, not at runtime. Two approaches are valid:

#### Approach A: Template Variable Expansion (Recommended)

Before copying template files to the new entity directory:

```bash
ENTITY="mercury"
ENTITY_DIR="/home/koad/.mercury"
ENTITY_TITLE_CASE="Mercury"
GIT_AUTHOR_NAME="Mercury"
GIT_AUTHOR_EMAIL="mercury@kingofalldata.com"

# For each file in template:
sed -i "s|\$ENTITY|${ENTITY}|g" "$file"
sed -i "s|\$ENTITY_DIR|${ENTITY_DIR}|g" "$file"
sed -i "s|\$ENTITY_TITLE_CASE|${ENTITY_TITLE_CASE}|g" "$file"
sed -i "s|\$GIT_AUTHOR_NAME|${GIT_AUTHOR_NAME}|g" "$file"
sed -i "s|\$GIT_AUTHOR_EMAIL|${GIT_AUTHOR_EMAIL}|g" "$file"
```

#### Approach B: Source-Level Template Processing

Use an ERB or Jinja-like templating pass:

```bash
erb -r ./gestate-helper.rb template/CLAUDE.md > $ENTITY_DIR/CLAUDE.md
```

Where `template/CLAUDE.md` uses `<%= @entity %>` syntax.

### Verification

Post-gestation, Vesta MUST verify substitution succeeded by checking:

```bash
# Should find NO remaining placeholders
grep -r '\$ENTITY' ~/.{new-entity}/
grep -r '~/.juno/' ~/.{new-entity}/  # (or reference to source entity)
grep -r 'You are Juno' ~/.{new-entity}/  # (or reference to source entity)
```

If any matches are found, gestation is **incomplete** and the entity directory is **not usable**.

## Examples

### CLAUDE.md Before Substitution (Template)

```markdown
## What I Am

I am $ENTITY_TITLE_CASE — [role and purpose]...

## Git Identity

\`\`\`env
ENTITY=$ENTITY
ENTITY_DIR=$ENTITY_DIR
GIT_AUTHOR_NAME=$GIT_AUTHOR_NAME
GIT_AUTHOR_EMAIL=$GIT_AUTHOR_EMAIL
\`\`\`
```

### CLAUDE.md After Substitution (For mercury)

```markdown
## What I Am

I am Mercury — [role and purpose]...

## Git Identity

\`\`\`env
ENTITY=mercury
ENTITY_DIR=/home/koad/.mercury
GIT_AUTHOR_NAME=Mercury
GIT_AUTHOR_EMAIL=mercury@kingofalldata.com
\`\`\`
```

### Command Script Before (Template)

```bash
#!/bin/bash
# $ENTITY_TITLE_CASE Self-Commit Command

cd $ENTITY_DIR
git config user.name "$GIT_AUTHOR_NAME"
git config user.email "$GIT_AUTHOR_EMAIL"
# ... rest of commit logic
```

### Command Script After (For mercury)

```bash
#!/bin/bash
# Mercury Self-Commit Command

cd /home/koad/.mercury
git config user.name "Mercury"
git config user.email "mercury@kingofalldata.com"
# ... rest of commit logic
```

## Scope & Ownership

**Vesta owns this protocol.**

- All template files in `~/.koad-io/` MUST comply with this spec
- Vulcan (entity spawner) is responsible for performing substitution at gestation time
- Salus (healer) MUST verify substitution success before releasing a gestated entity
- All future entities gestated from any base template MUST follow this pattern

## Migration

For entities already gestated with broken commands (mercury, veritas, muse, argus, salus, janus, aegis):

1. Salus runs post-gestation patch: identify all hardcoded references to source entity and replace with correct identity
2. For each command file, update headers and path references
3. Re-commit with message: "fix: replace hardcoded template identity with $ENTITY substitution"
4. Verify no remaining source-entity references exist

## Deprecated

- ❌ Hardcoded entity references in template files (e.g., "You are Juno", `~/.juno/` in gestated entities)
- ❌ Copy-without-substitution gestation flows

---

**Canonical since:** 2026-04-03
**Approved by:** Vesta
**References:** koad/vesta#5, koad/vesta@c76d7e6
