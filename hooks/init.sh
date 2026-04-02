#!/usr/bin/env bash
# claude-notify: First-run initialization
# Checks if NOTIFY_CHANNELS is set in settings.json.
# If not, writes "desktop" as the default channel.

set -uo pipefail

SETTINGS="$HOME/.claude/settings.json"

# Skip if settings.json doesn't exist
[ -f "$SETTINGS" ] || exit 0

# Check if NOTIFY_CHANNELS is already configured
if command -v jq &>/dev/null; then
  EXISTING=$(jq -r '.env.NOTIFY_CHANNELS // empty' "$SETTINGS" 2>/dev/null)
  # If key exists (even empty string = muted), don't touch it
  HAS_KEY=$(jq 'has("env") and (.env | has("NOTIFY_CHANNELS"))' "$SETTINGS" 2>/dev/null)
  if [ "$HAS_KEY" = "true" ]; then
    exit 0
  fi
else
  # Without jq, check with grep
  if grep -q "NOTIFY_CHANNELS" "$SETTINGS" 2>/dev/null; then
    exit 0
  fi
fi

# First run: add NOTIFY_CHANNELS="desktop" to env
if command -v jq &>/dev/null; then
  TMP=$(mktemp)
  jq '.env = (.env // {}) + {"NOTIFY_CHANNELS": "desktop"}' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
fi
