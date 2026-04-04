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
  # Base64-encode the prompt to safely pass it through SSH without quoting issues
  ENCODED=$(printf '%s' "$PROMPT" | base64 -w0 2>/dev/null || printf '%s' "$PROMPT" | base64)
  ssh "$ENTITY_HOST" "$NVM_INIT && cd $ENTITY_DIR && DECODED=\$(echo '$ENCODED' | base64 -d) && $CLAUDE_BIN --model sonnet --dangerously-skip-permissions --output-format=json -p \"\$DECODED\" 2>/dev/null" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',''))"
else
  exec ssh -t "$ENTITY_HOST" "$NVM_INIT && cd $ENTITY_DIR && $CLAUDE_BIN --model sonnet --dangerously-skip-permissions -c"
fi
