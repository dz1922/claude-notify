---
description: "Show current notification configuration and channel status"
---

# Notification Status

Read `~/.claude/settings.json` and display the current notification configuration.

## What to Show

1. **Enabled channels**: Read `env.NOTIFY_CHANNELS` (default: "desktop")
2. **Hook events**: List which events are wired (SubagentStop, TaskCompleted, Notification, Stop, StopFailure)
3. **Channel credentials status** (show set/not set, mask actual values):
   - Telegram: token and chat ID
   - Slack: webhook URL
   - Teams: webhook URL
   - Lark: webhook URL
   - Custom webhook: URL
4. **Optional settings**:
   - Sound: `env.NOTIFY_SOUND` (default: Glass)
   - Quiet hours: `env.NOTIFY_QUIET_HOURS`

## Output Format

```
notify status
──────────────

Channels:  desktop, telegram
Events:    SubagentStop, TaskCompleted, Notification, Stop, StopFailure

Desktop:   ✓ enabled
Telegram:  ✓ token=bot***...***  chat=12***89
Slack:     ✗ not configured
Teams:     ✗ not configured
Lark:      ✗ not configured
Webhook:   ✗ not configured

Sound:     Glass
Quiet:     22:00-08:00
```

Mask credentials: show first 3 and last 2 characters only, with `***...***` in between.
If a channel is listed in NOTIFY_CHANNELS but credentials are missing, show a warning.
