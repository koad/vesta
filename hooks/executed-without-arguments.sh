#!/usr/bin/env bash
set -euo pipefail

echo
echo "juno hook: no arguments given, loading claude code..."
echo

if [ -z "${ENTITY:-}" ]; then
  echo "error: ENTITY not set. exiting."
  exit 1
fi

source "$HOME/.koad-io/.env" || true
source "$HOME/.$ENTITY/.env" || true

echo "entity: $ENTITY"
echo "launching: claude . in $HOME/.$ENTITY/"
echo

cd "$HOME/.$ENTITY/"
exec claude . --model sonnet
