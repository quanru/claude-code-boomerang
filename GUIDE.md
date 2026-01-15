# Claude Code Notification System - Detailed Guide

This guide provides in-depth information about how the notification system works, troubleshooting tips, and advanced configuration options.

## Table of Contents

- [Manual Installation](#manual-installation)
- [How It Works](#how-it-works)
- [Technical Details](#technical-details)
- [Debugging](#debugging)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)
- [Alternative Approaches](#alternative-approaches)
- [Dependencies](#dependencies)

## Manual Installation

If you prefer to install manually without using the install script:

### 1. Download alerter

[alerter](https://github.com/vjeantet/alerter) is a command-line tool that supports Alert-type notifications.

```bash
curl -L https://github.com/vjeantet/alerter/releases/download/1.0.1/alerter_v1.0.1_darwin_amd64.zip -o /tmp/alerter.tar.gz \
  && mkdir -p ~/.claude/hooks/notify /tmp/alerter_extract \
  && tar -xzf /tmp/alerter.tar.gz -C /tmp/alerter_extract \
  && mv /tmp/alerter_extract/alerter ~/.claude/hooks/notify/ \
  && chmod +x ~/.claude/hooks/notify/alerter \
  && rm -rf /tmp/alerter_extract /tmp/alerter.tar.gz \
  && ~/.claude/hooks/notify/alerter -help
```

### 2. Create notification script

Create `~/.claude/hooks/notify/index.sh`:

```bash
cat > ~/.claude/hooks/notify/index.sh << 'EOF'
#!/bin/bash
# Claude Code notification helper script
# Uses $CLAUDE_PROJECT_DIR environment variable (set by Claude Code hooks)

log_file=~/.claude/hooks/notify/debug.log

# Log rotation function
log_rotate() {
  local max_lines=200
  if [ -f "$log_file" ] && [ "$CLAUDE_NOTIFY_DEBUG" = "true" ]; then
    local line_count=$(wc -l < "$log_file" 2>/dev/null || echo 0)
    if [ "$line_count" -gt $((max_lines * 2)) ]; then
      tail -n $max_lines "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"
    fi
  fi
}

# Debug logging function
debug_log() {
  if [ "$CLAUDE_NOTIFY_DEBUG" = "true" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$log_file"
  fi
}

# Execute log rotation
log_rotate

# Read JSON from stdin
json=$(cat)

# Get project name from CLAUDE_PROJECT_DIR
project_name=$(basename "$CLAUDE_PROJECT_DIR")

# Check if current window is already the target VS Code window
front_app_info=$(osascript -e '
tell application "System Events"
  set frontApp to first application process whose frontmost is true
  set appName to name of frontApp
  set bundleId to bundle identifier of frontApp
  return appName & "|" & bundleId
end tell
' 2>/dev/null)
current_app="${front_app_info%%|*}"
bundle_id="${front_app_info##*|}"

if [ "$bundle_id" = "com.microsoft.VSCode" ]; then
  window_title=$(osascript -e "tell application \"System Events\" to get name of first window of application process \"$current_app\"" 2>/dev/null)
  if [[ "$window_title" == *"$project_name"* ]]; then
    exit 0
  fi
fi

# Parse message from JSON
msg=$(osascript -l JavaScript -e "
  var json = JSON.parse(\`$json\`);
  var hookType = json.hook_event_name || '';
  var message = '';

  if (hookType === 'Stop') {
    message = json.task_summary || json.message || 'Task completed';
  } else if (hookType === 'Notification') {
    message = json.message || 'Notification';
  } else {
    message = json.message || 'Task completed';
  }

  message;
" 2>/dev/null)

# Run alerter in background with nohup
nohup bash -c "
  log_file=~/.claude/hooks/notify/debug.log
  project_dir=\"$CLAUDE_PROJECT_DIR\"
  debug_enabled=\"$CLAUDE_NOTIFY_DEBUG\"

  debug_log() {
    if [ \"\$debug_enabled\" = \"true\" ]; then
      echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] \$1\" >> \"\$log_file\"
    fi
  }

  click_result=\$(~/.claude/hooks/notify/alerter -group \"$project_name\" -title \"Claude Code - $project_name\" -message \"$msg\" -actions \"Open\" -closeLabel \"Dismiss\" -timeout 0 2>/dev/null)

  if [ \"\$click_result\" = \"@CONTENTCLICKED\" ] || [ \"\$click_result\" = \"Open\" ] || [ \"\$click_result\" = \"@TIMEOUT\" ]; then
    if [ -n \"\$project_dir\" ]; then
      open \"vscode://file\$project_dir\"
    fi
  fi
" > /dev/null 2>&1 &
EOF

chmod +x ~/.claude/hooks/notify/index.sh
```

### 3. Configure Claude Code Hooks

Edit `~/.claude/settings.json` and add:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/notify/index.sh"
        }]
      }
    ],
    "Notification": [
      {
        "matcher": "*",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/notify/index.sh"
        }]
      }
    ]
  }
}
```

### 4. Restart Claude Code

Restart Claude Code or use the `/hooks` command to reload the configuration.

## How It Works

```
Claude Code completes task / needs attention
       ↓
Triggers Stop / Notification Hook
       ↓
index.sh checks if currently in VS Code using bundle identifier
       ↓ (not in target window)
alerter uses -group parameter to ensure only one notification per project
       ↓
New notification automatically replaces old one (same project)
       ↓
Launches alerter in background using nohup (independent process)
       ↓
Parent script returns immediately, alerter continues running
       ↓
User clicks notification
       ↓
Opens project root directory via vscode://file protocol
```

## Technical Details

### Why use bundle identifier?

VS Code may be identified as `Code` or `Electron` in macOS System Events. Using bundle identifier (`com.microsoft.VSCode`) allows precise VS Code detection, avoiding false positives from other Electron apps.

### Group ID Mechanism

Each project uses its project name as a unique notification group ID. When a new notification is triggered for the same project, alerter automatically dismisses the old notification and displays the new one. This ensures:

- No duplicate notifications for the same project
- Different projects can have notifications simultaneously
- No manual process management needed (handled by alerter)

### Why use nohup?

Claude Code may terminate the hook script's parent process after task completion. Using `nohup` allows alerter to run in an independent background process, ensuring the notification continues waiting for user interaction even if the parent process is terminated.

### Why use `$CLAUDE_PROJECT_DIR` instead of `cwd`?

The `cwd` field in hook JSON changes dynamically as users execute `cd` commands during the session.

The `$CLAUDE_PROJECT_DIR` environment variable is automatically set by Claude Code when executing hooks and **always points to the project root directory**, ensuring notifications correctly jump to the project root.

### Why choose alerter?

macOS has two notification types:

| Type | Behavior | Controllable by Code |
|------|----------|---------------------|
| Banner | Auto-dismisses after a few seconds | ❌ Controlled by system settings |
| Alert | Persists until user action | ❌ Controlled by system settings |

`terminal-notifier` sends Banner-type notifications, which may or may not persist depending on system settings.

`alerter` sends Alert-type notifications directly, **requiring no system setting changes**, with notifications persisting by default.

### Click Detection Logic

`alerter` returns different values depending on user action:

| User Action | Return Value |
|------------|--------------|
| Click notification content | `@CONTENTCLICKED` |
| Click "Open" button | `Open` (button text) |
| Click "Dismiss" button | `Dismiss` (button text) |
| Close notification | Empty string |

The script checks if the return value is `@CONTENTCLICKED` or `Open`, and jumps to VS Code if so.

## Debugging

### Enable Debug Mode

Debug logging is disabled by default for better performance. To enable it, add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_NOTIFY_DEBUG": "true"
  }
}
```

### View Logs

```bash
tail -f ~/.claude/hooks/notify/debug.log
```

The log file automatically rotates when it exceeds 400 lines, keeping only the most recent 200 lines.

### What Gets Logged

When debug mode is enabled, the script logs:
- Script start time and project directory
- Current application and bundle ID
- Window title checks
- Parsed notification message
- Click results and VS Code launch attempts

## Advanced Configuration

### Custom Notification Messages

You can customize the notification messages by modifying the message parsing logic in `index.sh`. The current implementation tries to extract `task_summary` or `message` fields from the hook JSON.

### Multiple Hook Commands

You can add other commands to run alongside the notification hook. For example, running linters:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "cd \"$CLAUDE_PROJECT_DIR\" && npm run lint"
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/notify/index.sh"
          }
        ]
      }
    ]
  }
}
```

Note: Hooks in the same event run in parallel by default.

### Project-Specific Configuration

Use matchers to apply different notification behaviors for different projects:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "my-important-project",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/notify/index.sh"
        }]
      },
      {
        "matcher": "*",
        "hooks": [{ /* other projects */ }]
      }
    ]
  }
}
```

## Troubleshooting

### Notifications not appearing

1. **Check if hooks are configured correctly**:
   ```bash
   cat ~/.claude/settings.json | grep -A 10 "hooks"
   ```

2. **Verify index.sh exists and is executable**:
   ```bash
   ls -la ~/.claude/hooks/notify/index.sh
   ```

3. **Enable debug mode** and check logs for errors

4. **Test alerter directly**:
   ```bash
   ~/.claude/hooks/notify/alerter -message "Test" -title "Test"
   ```

### Notifications appear but clicking doesn't work

1. **Verify VS Code URL scheme is registered**:
   ```bash
   open "vscode://file$HOME"
   ```
   This should open VS Code to your home directory.

2. **Check debug logs** for the click result and open command

### Multiple notifications for the same project

1. Ensure you're using the latest version of `index.sh` with the `-group` parameter
2. Check if you have duplicate hook configurations in `settings.json`

### Log file growing too large

The log file should automatically rotate when debug mode is enabled. If it's not:
1. Verify `CLAUDE_NOTIFY_DEBUG` is set to `"true"` (string, not boolean)
2. Manually clean up: `rm ~/.claude/hooks/notify/debug.log`

## Alternative Approaches

We tried several approaches before settling on `alerter + nohup + open`:

| Approach | Persistent | Jump | Issues |
|----------|-----------|------|--------|
| terminal-notifier | ⚠️ Requires system settings | ✅ | Depends on system settings |
| terminal-notifier + `-sender` | ✅ | ❌ | Produces duplicate notifications |
| osascript `display notification` | ⚠️ Requires system settings | ❌ | No click callback support |
| osascript `display dialog` | ✅ | ✅ | Dialog not notification |
| VS Code extension + node-notifier | ⚠️ | ⚠️ | Complex and unstable |
| AppleScript + AXRaise | ✅ | ⚠️ | Unstable across virtual desktops |
| **alerter + nohup + open** | ✅ | ✅ | **Recommended** |

## Dependencies

### Required
- **macOS** - The notification system uses macOS-specific APIs
- **alerter** - Command-line notification tool ([GitHub](https://github.com/vjeantet/alerter))
- **VS Code** - Must support `vscode://` protocol

### System Requirements
- macOS 10.10+ (for Notification Center support)
- Python 3 (pre-installed on macOS 10.15+, used by install script)
- Bash 3.2+ (macOS default shell)

## Contributing

Found a bug or have a suggestion? Please open an issue on GitHub.

## License

MIT
