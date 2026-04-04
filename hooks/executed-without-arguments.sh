#!/usr/bin/env bash
set -euo pipefail
# Vesta — lives on wonderland (10.10.10.10). This hook connects any machine to her session there.
# Hardcoded host is OK for now; daemon state machine will route this properly when live.
#
# Usage:
#   vesta                            → portal to Vesta on wonderland (interactive)
#   PROMPT="review this spec" vesta  → send task non-interactively, get result
#   echo "review this spec" | vesta  → send task via stdin

VESTA_HOST="10.10.10.10"
VESTA_DIR="\$HOME/.vesta"
CLAUDE_BIN="\$HOME/.local/bin/claude"

PROMPT="${PROMPT:-}"
if [ -z "$PROMPT" ] && [ ! -t 0 ]; then
  PROMPT="$(cat)"
fi

if [ -n "$PROMPT" ]; then
  # Non-interactive: send task, return only the result
  ssh "$VESTA_HOST" "cd $VESTA_DIR && $CLAUDE_BIN --dangerously-skip-permissions -c --output-format=json -p '$PROMPT' 2>/dev/null" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',''))"
else
  # Interactive: open live terminal portal to Vesta on wonderland
  exec ssh -t "$VESTA_HOST" "cd $VESTA_DIR && $CLAUDE_BIN --dangerously-skip-permissions -c"
fi
