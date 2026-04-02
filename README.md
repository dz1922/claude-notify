# claude-notify

Notification center for Claude Code. Get notified when background tasks complete, agents finish, or Claude is waiting for input.

## Why

Claude Code runs background agents and long tasks, but doesn't notify you when they finish. You end up checking back repeatedly, or missing the moment entirely. **claude-notify** fixes this by sending notifications to your preferred channels the instant events happen.

## Supported Events

| Event | When it fires |
|-------|--------------|
| `SubagentStop` | A background agent finishes |
| `TaskCompleted` | A task is completed |
| `Notification` (idle_prompt) | Claude is waiting for your input |
| `Stop` | Session stops normally |
| `StopFailure` | Session fails to stop |

## Supported Channels

| Channel | Platform | Setup |
|---------|----------|-------|
| **desktop** | macOS (osascript), Linux (notify-send), Windows (toast) | Works out of the box |
| **telegram** | Telegram Bot API | Need bot token + chat ID |
| **slack** | Slack Incoming Webhook | Need webhook URL |
| **teams** | Microsoft Teams Webhook | Need webhook URL |
| **lark** | Lark/Feishu Custom Bot | Need webhook URL |
| **webhook** | Any HTTP endpoint | Need URL (receives JSON POST) |

## Install

```bash
# Add the marketplace
claude plugin marketplace add dz1922/claude-notify

# Install the plugin
claude plugin install notify@claude-notify-marketplace
```

Or manually add to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "claude-notify-marketplace": {
      "source": {
        "source": "github",
        "repo": "dz1922/claude-notify"
      }
    }
  },
  "enabledPlugins": {
    "notify@claude-notify-marketplace": true
  }
}
```

## Usage

**Desktop notifications work immediately after install** — no configuration needed.

### Commands

| Command | Description |
|---------|-------------|
| `/notify:setup` | Show status, offer to add channels |
| `/notify:setup telegram` | Add Telegram |
| `/notify:setup slack` | Add Slack |
| `/notify:setup teams` | Add Microsoft Teams |
| `/notify:setup lark` | Add Lark/Feishu |
| `/notify:setup webhook` | Add custom webhook |
| `/notify:setup off telegram` | Remove Telegram (deletes credentials) |
| `/notify:setup off all` | Remove all channels (needs confirmation) |
| `/notify:status` | Show current configuration |

### Manual Configuration

Add to `~/.claude/settings.json` under `env`:

```json
{
  "env": {
    "NOTIFY_CHANNELS": "desktop,telegram",
    "NOTIFY_TELEGRAM_TOKEN": "123456:ABC-DEF...",
    "NOTIFY_TELEGRAM_CHAT": "987654321"
  }
}
```

### All Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NOTIFY_CHANNELS` | `desktop` | Comma-separated list of channels |
| `NOTIFY_TELEGRAM_TOKEN` | — | Telegram bot token from @BotFather |
| `NOTIFY_TELEGRAM_CHAT` | — | Telegram chat ID |
| `NOTIFY_SLACK_WEBHOOK` | — | Slack incoming webhook URL |
| `NOTIFY_TEAMS_WEBHOOK` | — | Microsoft Teams webhook URL |
| `NOTIFY_LARK_WEBHOOK` | — | Lark/Feishu custom bot webhook URL |
| `NOTIFY_WEBHOOK_URL` | — | Custom webhook URL (receives JSON POST) |
| `NOTIFY_SOUND` | `Glass` | macOS notification sound |
| `NOTIFY_QUIET_HOURS` | — | Suppress desktop notifications (e.g. `22:00-08:00`) |

### Available macOS Sounds

Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink

## Channel Setup Guides

### Desktop (default)

Works immediately on macOS, Linux, and Windows. No configuration needed.

- **macOS**: Uses `osascript` (native)
- **Linux**: Uses `notify-send` (install: `sudo apt install libnotify-bin`)
- **Windows**: Uses PowerShell toast notifications (Git Bash / MSYS2)

### Telegram

1. Message [@BotFather](https://t.me/BotFather) on Telegram, create a new bot
2. Copy the bot token
3. Message [@userinfobot](https://t.me/userinfobot) to find your chat ID
4. Run `/notify:setup telegram` and enter credentials

### Slack

1. Create an [Incoming Webhook](https://api.slack.com/messaging/webhooks) in your Slack workspace
2. Copy the webhook URL
3. Run `/notify:setup slack` and enter URL

### Microsoft Teams

1. Create an [Incoming Webhook](https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook) or Power Automate Workflow in your Teams channel
2. Copy the webhook URL
3. Run `/notify:setup teams` and enter URL

### Lark / Feishu

1. Open your Lark group, go to Settings > Bots > Add Bot > Custom Bot
2. Copy the webhook URL
3. Run `/notify:setup lark` and enter URL

### Custom Webhook

Receives a JSON POST with this payload:

```json
{
  "title": "[my-project] Agent Completed",
  "message": "Source: hostname:/path/to/project",
  "event": "SubagentStop",
  "tool": "",
  "session": "abc123"
}
```

Run `/notify:setup webhook` and enter URL.

## Troubleshooting

**Desktop notification not showing (macOS)**
- Check System Settings > Notifications > Script Editor is enabled
- Try: `osascript -e 'display notification "test" with title "test"'`

**Desktop notification not showing (Linux)**
- Install `notify-send`: `sudo apt install libnotify-bin`

**Telegram not working**
- Verify token: `curl https://api.telegram.org/bot<TOKEN>/getMe`
- Send a test message to the bot first, then check chat ID

**Notifications delayed or missing**
- Each channel has a 5-second curl timeout
- If a webhook is slow, it may be silently dropped

**`jq` not installed**
- Plugin works without jq (graceful degradation)
- Install for better JSON handling: `brew install jq` or `sudo apt install jq`

## Requirements

- macOS, Linux, or Windows (Git Bash / MSYS2)
- `curl` (for Telegram, Slack, Teams, Lark, webhook channels)
- `jq` (optional, improves JSON handling)

## License

MIT
