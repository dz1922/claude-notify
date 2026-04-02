#!/usr/bin/env bash
# claude-notify: Unified notification dispatcher
# Reads hook event from stdin, sends notifications to configured channels.
#
# Configuration via environment variables (set in Claude Code settings.json env):
#   NOTIFY_CHANNELS        - comma-separated: desktop,telegram,slack,teams,lark,webhook
#   NOTIFY_TELEGRAM_TOKEN  - Telegram bot token
#   NOTIFY_TELEGRAM_CHAT   - Telegram chat ID
#   NOTIFY_SLACK_WEBHOOK   - Slack incoming webhook URL
#   NOTIFY_TEAMS_WEBHOOK   - Teams incoming webhook URL
#   NOTIFY_LARK_WEBHOOK  - Feishu/Lark custom bot webhook URL
#   NOTIFY_WEBHOOK_URL     - Custom webhook URL (POST JSON)
#   NOTIFY_SOUND           - macOS sound name (default: Glass)
#   NOTIFY_QUIET_HOURS     - e.g. "22:00-08:00" to suppress desktop notifications

set -uo pipefail
# Note: -e intentionally omitted — we handle errors per-channel gracefully.

# ---- DEPENDENCY CHECKS ----

HAS_JQ=false
HAS_CURL=false
command -v jq &>/dev/null && HAS_JQ=true
command -v curl &>/dev/null && HAS_CURL=true

# ---- READ INPUT ----

INPUT=$(cat 2>/dev/null || echo "{}")

# Extract event info (graceful when jq missing)
HOOK_EVENT="${CLAUDE_HOOK_EVENT:-unknown}"
TOOL_NAME=""
SESSION_ID=""
PROJECT=""
NOTIF_TYPE="idle_prompt"

if $HAS_JQ; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
  PROJECT=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
fi

# Use last directory component as project name
if [ -n "$PROJECT" ]; then
  PROJECT="${PROJECT##*/}"
else
  PROJECT="${PWD##*/}"
fi

# ---- JSON ESCAPE ----

json_escape() {
  local str="$1"
  if $HAS_JQ; then
    printf '%s' "$str" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//'
  else
    # Fallback: escape \, ", newlines, tabs
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
  fi
}

# ---- BUILD MESSAGE ----

# Full path for message body
FULL_CWD=""
if $HAS_JQ; then
  FULL_CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
fi
[ -z "$FULL_CWD" ] && FULL_CWD="$PWD"

case "$HOOK_EVENT" in
  SubagentStop)    EVENT_LABEL="Agent Completed" ;;
  TaskCompleted)   EVENT_LABEL="Task Completed" ;;
  Stop)            EVENT_LABEL="Session Stopped" ;;
  StopFailure)     EVENT_LABEL="Session Stop Failed" ;;
  Notification)
    if $HAS_JQ; then
      NOTIF_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "idle_prompt"' 2>/dev/null || echo "idle_prompt")
    fi
    case "$NOTIF_TYPE" in
      idle_prompt) EVENT_LABEL="Waiting for Input" ;;
      *)           EVENT_LABEL="$NOTIF_TYPE" ;;
    esac
    ;;
  *)               EVENT_LABEL="$HOOK_EVENT" ;;
esac

HOSTNAME=$(hostname -s 2>/dev/null || echo "unknown")
TITLE="[$PROJECT] $EVENT_LABEL"
MSG="Source: $HOSTNAME:$FULL_CWD"

# Pre-escape for JSON payloads
TITLE_ESC=$(json_escape "$TITLE")
MSG_ESC=$(json_escape "$MSG")

# Read channels: env var takes priority, then settings.json
if [ -n "${NOTIFY_CHANNELS+x}" ]; then
  # Env var is set (even if empty = muted)
  CHANNELS="$NOTIFY_CHANNELS"
elif $HAS_JQ && [ -f "$HOME/.claude/settings.json" ]; then
  # Env var not set — read from settings.json directly
  HAS_KEY=$(jq 'has("env") and (.env | has("NOTIFY_CHANNELS"))' "$HOME/.claude/settings.json" 2>/dev/null || echo "false")
  if [ "$HAS_KEY" = "true" ]; then
    CHANNELS=$(jq -r '.env.NOTIFY_CHANNELS' "$HOME/.claude/settings.json" 2>/dev/null || echo "")
  else
    CHANNELS=""
  fi
else
  CHANNELS=""
fi
SOUND="${NOTIFY_SOUND:-Glass}"

# ---- QUIET HOURS ----

in_quiet_hours() {
  local range="${NOTIFY_QUIET_HOURS:-}"
  [ -z "$range" ] && return 1
  local start end now
  start=$(echo "$range" | cut -d- -f1 | tr -d ':')
  end=$(echo "$range" | cut -d- -f2 | tr -d ':')
  now=$(date +%H%M)
  if [ "$start" -gt "$end" ] 2>/dev/null; then
    [ "$now" -ge "$start" ] || [ "$now" -lt "$end" ]
  else
    [ "$now" -ge "$start" ] && [ "$now" -lt "$end" ]
  fi
}

# ---- CHANNEL DISPATCHERS ----

send_desktop() {
  if in_quiet_hours; then return 0; fi

  # Escape for osascript (double quotes and backslashes)
  local osa_title="${TITLE//\\/\\\\}"
  osa_title="${osa_title//\"/\\\"}"
  local osa_msg="${MSG//\\/\\\\}"
  osa_msg="${osa_msg//\"/\\\"}"

  case "$(uname)" in
    Darwin)
      osascript -e "display notification \"${osa_msg}\" with title \"${osa_title}\" sound name \"${SOUND}\"" 2>/dev/null || true
      ;;
    Linux)
      if command -v notify-send &>/dev/null; then
        notify-send "$TITLE" "$MSG" 2>/dev/null || true
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      powershell.exe -Command "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; \$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); \$text = \$xml.GetElementsByTagName('text'); \$text[0].AppendChild(\$xml.CreateTextNode('${osa_title}')) | Out-Null; \$text[1].AppendChild(\$xml.CreateTextNode('${osa_msg}')) | Out-Null; [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show([Windows.UI.Notifications.ToastNotification]::new(\$xml))" 2>/dev/null || true
      ;;
  esac
}

send_telegram() {
  $HAS_CURL || return 0
  local token="${NOTIFY_TELEGRAM_TOKEN:-}"
  local chat="${NOTIFY_TELEGRAM_CHAT:-}"
  [ -z "$token" ] || [ -z "$chat" ] && return 0

  curl -s --max-time 5 -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"${chat}\",\"text\":\"<b>${TITLE_ESC}</b>\n${MSG_ESC}\",\"parse_mode\":\"HTML\"}" \
    >/dev/null 2>&1 || true
}

send_slack() {
  $HAS_CURL || return 0
  local webhook="${NOTIFY_SLACK_WEBHOOK:-}"
  [ -z "$webhook" ] && return 0

  curl -s --max-time 5 -X POST "$webhook" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"*${TITLE_ESC}*\n${MSG_ESC}\"}" \
    >/dev/null 2>&1 || true
}

send_teams() {
  $HAS_CURL || return 0
  local webhook="${NOTIFY_TEAMS_WEBHOOK:-}"
  [ -z "$webhook" ] && return 0

  # Support both legacy Incoming Webhook (MessageCard) and Power Automate Workflow (Adaptive Card)
  if echo "$webhook" | grep -q "powerautomate\|workflows"; then
    # Power Automate Workflow format
    curl -s --max-time 5 -X POST "$webhook" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"message\",\"attachments\":[{\"contentType\":\"application/vnd.microsoft.card.adaptive\",\"content\":{\"type\":\"AdaptiveCard\",\"\$schema\":\"http://adaptivecards.io/schemas/adaptive-card.json\",\"version\":\"1.4\",\"body\":[{\"type\":\"TextBlock\",\"text\":\"${TITLE_ESC}\",\"weight\":\"bolder\",\"size\":\"medium\"},{\"type\":\"TextBlock\",\"text\":\"${MSG_ESC}\",\"wrap\":true}]}}]}" \
      >/dev/null 2>&1 || true
  else
    # Legacy Incoming Webhook format
    curl -s --max-time 5 -X POST "$webhook" \
      -H "Content-Type: application/json" \
      -d "{\"@type\":\"MessageCard\",\"summary\":\"${TITLE_ESC}\",\"sections\":[{\"activityTitle\":\"${TITLE_ESC}\",\"text\":\"${MSG_ESC}\"}]}" \
      >/dev/null 2>&1 || true
  fi
}

send_lark() {
  $HAS_CURL || return 0
  local webhook="${NOTIFY_LARK_WEBHOOK:-}"
  [ -z "$webhook" ] && return 0

  curl -s --max-time 5 -X POST "$webhook" \
    -H "Content-Type: application/json" \
    -d "{\"msg_type\":\"interactive\",\"card\":{\"header\":{\"title\":{\"tag\":\"plain_text\",\"content\":\"${TITLE_ESC}\"},\"template\":\"blue\"},\"elements\":[{\"tag\":\"markdown\",\"content\":\"${MSG_ESC}\"}]}}" \
    >/dev/null 2>&1 || true
}

send_webhook() {
  $HAS_CURL || return 0
  local url="${NOTIFY_WEBHOOK_URL:-}"
  [ -z "$url" ] && return 0

  local tool_esc=$(json_escape "$TOOL_NAME")
  local session_esc=$(json_escape "$SESSION_ID")
  local event_esc=$(json_escape "$HOOK_EVENT")

  curl -s --max-time 5 -X POST "$url" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"${TITLE_ESC}\",\"message\":\"${MSG_ESC}\",\"event\":\"${event_esc}\",\"tool\":\"${tool_esc}\",\"session\":\"${session_esc}\"}" \
    >/dev/null 2>&1 || true
}

# ---- DISPATCH ----

IFS=',' read -ra CHANNEL_LIST <<< "$CHANNELS"
for ch in "${CHANNEL_LIST[@]}"; do
  ch="${ch#"${ch%%[![:space:]]*}"}"  # trim leading whitespace
  ch="${ch%"${ch##*[![:space:]]}"}"  # trim trailing whitespace
  case "$ch" in
    desktop)  send_desktop ;;
    telegram) send_telegram ;;
    slack)    send_slack ;;
    teams)    send_teams ;;
    lark)     send_lark ;;
    webhook)  send_webhook ;;
  esac
done
