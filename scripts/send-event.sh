#!/bin/bash
# Sends a test event to the running app. Usage: scripts/send-event.sh <Event> [session-id] [message]
set -euo pipefail
EVENT="$1"
SESSION="${2:-demo}"
MESSAGE="${3:-}"
HOOK="$(swift build --show-bin-path)/deskling-hook"
printf '{"session_id":"%s","cwd":"%s","message":"%s"}' "$SESSION" "$PWD" "$MESSAGE" | "$HOOK" "$EVENT"
