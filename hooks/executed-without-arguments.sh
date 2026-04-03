#!/usr/bin/env bash
set -euo pipefail
# Vesta — interactive or prompt-driven
# Usage: vesta                               → interactive Claude Code session
#        PROMPT="review this spec" vesta     → non-interactive, identity + prompt
#        echo "review this spec" | vesta     → non-interactive, stdin

IDENTITY="$HOME/.vesta/memories/001-identity.md"

PROMPT="${PROMPT:-}"
if [ -z "$PROMPT" ] && [ ! -t 0 ]; then
  PROMPT="$(cat)"
fi

cd "$HOME/.vesta"

if [ -n "$PROMPT" ]; then
  exec opencode run --model opencode/big-pickle "$(cat "$IDENTITY")

$PROMPT"
else
  exec claude . --model sonnet
fi
