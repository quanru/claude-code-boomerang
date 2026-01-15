#!/bin/bash
# Claude Code Notification Hooks - Installation Script

set -e

SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_PATH="$HOME/.claude/hooks/notify/index.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Installing Claude Code Notification Hooks..."

# Check if index.sh exists
if [ ! -f "$HOOK_PATH" ]; then
  echo "❌ Error: index.sh not found at $HOOK_PATH"
  echo "Please ensure you've cloned the repo to ~/.claude/hooks/notify"
  exit 1
fi

# Check if alerter exists
if [ ! -f "$SCRIPT_DIR/alerter" ]; then
  echo "❌ Error: alerter binary not found"
  echo "This repository should include the alerter binary"
  exit 1
fi

# Make sure scripts are executable
chmod +x "$HOOK_PATH"
chmod +x "$SCRIPT_DIR/alerter"

# Backup settings.json if it exists
if [ -f "$SETTINGS_FILE" ]; then
  BACKUP_FILE="${SETTINGS_FILE}.backup.$(date +%s)"
  cp "$SETTINGS_FILE" "$BACKUP_FILE"
  echo "✅ Backup created: $BACKUP_FILE"
fi

# Use Python to merge configuration
python3 <<'PYTHON'
import json
import os
import sys

settings_file = os.path.expanduser("~/.claude/settings.json")

# Read existing configuration
if os.path.exists(settings_file):
    try:
        with open(settings_file, 'r') as f:
            settings = json.load(f)
    except json.JSONDecodeError:
        print("❌ Error: Invalid JSON in settings.json")
        sys.exit(1)
else:
    settings = {}

# Ensure hooks field exists
if 'hooks' not in settings:
    settings['hooks'] = {}

# Configuration to add
hook_command = "~/.claude/hooks/notify/index.sh"

# Add Stop and Notification hooks
for hook_type in ['Stop', 'Notification']:
    if hook_type not in settings['hooks']:
        settings['hooks'][hook_type] = []

    hook_config = {
        "matcher": "*",
        "hooks": [{
            "type": "command",
            "command": hook_command
        }]
    }

    # Check if already exists
    exists = False
    for h in settings['hooks'][hook_type]:
        if 'hooks' in h and len(h['hooks']) > 0:
            if h['hooks'][0].get('command') == hook_command:
                exists = True
                break

    if not exists:
        settings['hooks'][hook_type].append(hook_config)
        print(f"✅ Added {hook_type} hook")
    else:
        print(f"ℹ️  {hook_type} hook already configured")

# Write back configuration
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print("✅ Settings updated successfully!")
PYTHON

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (if running)"
echo "  2. Run any task to test the notification"
echo ""
echo "Optional: Enable debug mode by adding to ~/.claude/settings.json:"
echo '  "env": { "CLAUDE_NOTIFY_DEBUG": "true" }'
echo ""
echo "For more information, see GUIDE.md"
