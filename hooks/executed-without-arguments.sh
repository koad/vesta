#!/usr/bin/env bash
set -euo pipefail
# vesta — headquartered at fourty4. This hook connects any machine to their session there.

ENTITY_HOST="fourty4"
ENTITY_DIR="\$HOME/.vesta"
CLAUDE_BIN="\$HOME/.nvm/versions/node/v24.14.0/bin/claude"
NVM_INIT="export PATH=/opt/homebrew/bin:\$HOME/.nvm/versions/node/v24.14.0/bin:\$PATH"

PROMPT="${PROMPT:-}"
if [ -z "$PROMPT" ] && [ ! -t 0 ]; then
  PROMPT="$(cat)"
fi

if [ -n "$PROMPT" ]; then
  ssh "$ENTITY_HOST" "$NVM_INIT && cd $ENTITY_DIR && $CLAUDE_BIN --dangerously-skip-permissions -c --output-format=json -p '$PROMPT' 2>/dev/null" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',''))"
else
  exec ssh -t "$ENTITY_HOST" "$NVM_INIT && cd $ENTITY_DIR && $CLAUDE_BIN --dangerously-skip-permissions -c"
fi
