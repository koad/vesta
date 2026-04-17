#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD

# Vesta Spawn Process Command
# Spawns a team entity in its own gnome-terminal with Claude Code
# Triggers OBS streaming via WebSocket API on the broadcast machine
#
# Usage: vesta spawn process <entity> ["prompt to pass"]
#
# Flow:
#   1. Validate entity exists on disk
#   2. Hit OBS API → switch scene → start streaming on entity's channel
#   3. Wait for OBS confirmation
#   4. Spawn gnome-terminal: cd ~/.<entity>/ && claude .
#   5. Pass prompt if provided
#   6. Monitor for process exit
#   7. Hit OBS API → stop streaming
#
# Each entity runs as a FULL sovereign Claude Code instance:
#   - Own CLAUDE.md, memories, skills, commands
#   - Own git identity and cryptographic keys
#   - Own repo context — not a tool call, a complete session
#
# This is better than MCP/skills because the entity isn't a function
# inside someone else's session — it's a sovereign process.

set -euo pipefail

ENTITY_NAME="${1:?Usage: vesta spawn process <entity> [\"prompt\"]}"
ENTITY_DIR="$HOME/.$ENTITY_NAME"
PROMPT="${2:-}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# OBS WebSocket Configuration (Windows broadcast machine on network)
OBS_HOST="${OBS_HOST:-}"
OBS_PORT="${OBS_PORT:-4455}"
OBS_PASSWORD="${OBS_PASSWORD:-}"
OBS_ENABLED="${OBS_ENABLED:-false}"

# Entity's OBS scene name (convention: entity name capitalized)
OBS_SCENE="${ENTITY_NAME^}"

# ─────────────────────────────────────────────
# Validate
# ─────────────────────────────────────────────

if [ ! -d "$ENTITY_DIR" ]; then
    echo "Entity '$ENTITY_NAME' not found at $ENTITY_DIR"
    echo ""
    echo "Gestate first:"
    echo "  koad-io gestate $ENTITY_NAME"
    echo "  cd $ENTITY_DIR && git init"
    exit 1
fi

if [ ! -f "$ENTITY_DIR/CLAUDE.md" ] && [ ! -f "$ENTITY_DIR/.env" ]; then
    echo "Warning: $ENTITY_DIR exists but doesn't look like a koad:io entity"
    echo "Missing CLAUDE.md and .env — is this entity fully gestated?"
fi

echo "╔══════════════════════════════════════════╗"
echo "║  Spawning: $ENTITY_NAME"
echo "║  Directory: $ENTITY_DIR"
echo "║  Time: $TIMESTAMP"
[ -n "$PROMPT" ] && echo "║  Task: ${PROMPT:0:40}..."
echo "╚══════════════════════════════════════════╝"

# ─────────────────────────────────────────────
# OBS: Start Streaming
# ─────────────────────────────────────────────

obs_request() {
    local request_type="$1"
    local request_data="${2:-{}}"

    if [ "$OBS_ENABLED" != "true" ] || [ -z "$OBS_HOST" ]; then
        return 0
    fi

    # OBS WebSocket v5 uses WebSocket protocol
    # Using websocat or obs-cli if available
    if command -v obs-cli &>/dev/null; then
        obs-cli --host "$OBS_HOST" --port "$OBS_PORT" --password "$OBS_PASSWORD" \
            "$request_type" "$request_data" 2>/dev/null
    elif command -v websocat &>/dev/null; then
        # Raw WebSocket JSON-RPC
        local payload=$(cat <<JSONEOF
{
    "op": 6,
    "d": {
        "requestType": "$request_type",
        "requestId": "spawn-$ENTITY_NAME-$TIMESTAMP",
        "requestData": $request_data
    }
}
JSONEOF
        )
        echo "$payload" | websocat "ws://$OBS_HOST:$OBS_PORT" 2>/dev/null
    else
        echo "[OBS] No WebSocket client found (need obs-cli or websocat)"
        echo "[OBS] Streaming will not be automated this session"
        return 1
    fi
}

start_obs_stream() {
    if [ "$OBS_ENABLED" != "true" ] || [ -z "$OBS_HOST" ]; then
        echo "[OBS] Streaming disabled — set OBS_ENABLED=true and OBS_HOST"
        return 0
    fi

    echo "[OBS] Switching to scene: $OBS_SCENE"
    obs_request "SetCurrentProgramScene" "{\"sceneName\": \"$OBS_SCENE\"}"

    echo "[OBS] Starting stream for $ENTITY_NAME..."
    obs_request "StartStream"

    # Wait for confirmation
    sleep 2
    echo "[OBS] Stream started ✓"
}

stop_obs_stream() {
    if [ "$OBS_ENABLED" != "true" ] || [ -z "$OBS_HOST" ]; then
        return 0
    fi

    echo ""
    echo "[OBS] Stopping stream for $ENTITY_NAME..."
    obs_request "StopStream"
    echo "[OBS] Stream ended ✓"
}

# Start streaming before spawning
start_obs_stream

# ─────────────────────────────────────────────
# Spawn Entity Process
# ─────────────────────────────────────────────

# Build the command to run inside the terminal
if [ -n "$PROMPT" ]; then
    # Pass prompt via heredoc to handle special characters
    SPAWN_CMD="cd $ENTITY_DIR && claude . --prompt $(printf '%q' "$PROMPT")"
else
    SPAWN_CMD="cd $ENTITY_DIR && claude ."
fi

# Spawn in a new gnome-terminal
# The entity gets its own window with its own context
gnome-terminal \
    --title="⬡ $ENTITY_NAME" \
    --geometry=120x40 \
    -- bash -c "$SPAWN_CMD; EXIT_CODE=\$?; echo ''; echo '[$ENTITY_NAME process ended with code '\$EXIT_CODE']'; sleep 3; exit \$EXIT_CODE" &

TERMINAL_PID=$!

echo ""
echo "Entity $ENTITY_NAME spawned (terminal PID: $TERMINAL_PID)"
echo "Monitoring for process exit..."

# ─────────────────────────────────────────────
# Monitor & Cleanup
# ─────────────────────────────────────────────

# Wait for the terminal process to exit
wait $TERMINAL_PID 2>/dev/null
EXIT_CODE=$?

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  $ENTITY_NAME process complete"
echo "║  Exit code: $EXIT_CODE"
echo "║  Duration: started $TIMESTAMP"
echo "╚══════════════════════════════════════════╝"

# Stop streaming after process ends
stop_obs_stream

exit $EXIT_CODE
