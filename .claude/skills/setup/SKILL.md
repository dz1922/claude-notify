---
name: setup
description: "Add or remove notification channels (telegram, slack, teams, lark, webhook)"
user-invocable: true
args:
  - name: action
    description: "Channel to add (telegram/slack/teams/lark/webhook), or 'off <channel|all>' to remove"
    required: false
---

# Notification Center Setup

## Default Behavior

**Desktop notifications are enabled out of the box.** No configuration needed.

## Commands

```
/notify:setup                    # Show status, offer to add channels
/notify:setup telegram           # Add Telegram
/notify:setup slack              # Add Slack
/notify:setup teams              # Add Teams
/notify:setup lark               # Add Lark/Feishu
/notify:setup webhook            # Add custom webhook
/notify:setup off telegram       # Remove Telegram (deletes credentials)
/notify:setup off all            # Remove all channels (needs confirmation)
```

## Flow: No argument

Show current status, then gently offer options:

> Desktop notifications are active (default).
>
> You can also receive notifications on other channels:
> - **telegram** — Telegram bot messages
> - **slack** — Slack incoming webhook
> - **teams** — Microsoft Teams webhook
> - **lark** — Lark/Feishu custom bot
> - **webhook** — Custom HTTP endpoint
>
> Want to add any?

Do NOT force the user to pick. Desktop is already working.

## Flow: Add channel

Guide the user through configuring that specific channel:

**telegram:**
1. Ask for bot token (from @BotFather)
2. Ask for chat ID (from @userinfobot)

**slack:**
1. Ask for incoming webhook URL

**teams:**
1. Ask for incoming webhook URL (supports both legacy and Power Automate workflows)

**lark:**
1. Ask for custom bot webhook URL

**webhook:**
1. Ask for webhook URL

### Write configuration

Add the channel to existing `NOTIFY_CHANNELS` (don't replace) and set credentials in `~/.claude/settings.json` under `env`:

```json
{
  "env": {
    "NOTIFY_CHANNELS": "desktop,telegram",
    "NOTIFY_TELEGRAM_TOKEN": "bot-token-here",
    "NOTIFY_TELEGRAM_CHAT": "chat-id-here"
  }
}
```

**IMPORTANT:** Read the existing settings.json first and MERGE — never replace existing env vars.

### Test the notification

After configuring a new channel, test it:
```bash
echo '{"cwd":"'$PWD'"}' | CLAUDE_HOOK_EVENT=TaskCompleted NOTIFY_CHANNELS=<new-channel> <credentials> ${CLAUDE_PLUGIN_ROOT}/hooks/notify.sh
```

Ask the user to confirm they received the notification. If not, help troubleshoot.

## Flow: off <channel>

Remove a specific channel. Read `~/.claude/settings.json`, then:

1. **Reject bare `off`** (no channel specified) — respond: "Please specify a channel: `/notify:setup off telegram` or `/notify:setup off all`"
2. Remove the channel from `NOTIFY_CHANNELS` value
3. Delete the channel's credential env vars:
   - desktop: no credentials to delete, just remove from NOTIFY_CHANNELS
   - telegram: delete `NOTIFY_TELEGRAM_TOKEN`, `NOTIFY_TELEGRAM_CHAT`
   - slack: delete `NOTIFY_SLACK_WEBHOOK`
   - teams: delete `NOTIFY_TEAMS_WEBHOOK`
   - lark: delete `NOTIFY_LARK_WEBHOOK`
   - webhook: delete `NOTIFY_WEBHOOK_URL`
4. If no channels remain, set `NOTIFY_CHANNELS` to `""` (empty string = all muted)

## Flow: off all

Mute ALL notifications and remove credentials. **Ask for confirmation first.**

1. Ask: "This will mute all notifications and remove all credentials. Continue? (yes/no)"
2. If confirmed: set `NOTIFY_CHANNELS` to `""` and delete all NOTIFY_* credential variables
3. All notifications are now silent. Use `/notify:setup desktop` to re-enable.

## Optional Settings

- **NOTIFY_SOUND** — macOS notification sound (default: Glass). Options: Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
- **NOTIFY_QUIET_HOURS** — Suppress desktop notifications during these hours (e.g. "22:00-08:00")
