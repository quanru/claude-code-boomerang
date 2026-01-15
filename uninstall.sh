#!/bin/bash
# Claude Code Notification Hooks - Uninstallation Script

set -e

SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_COMMAND="~/.claude/hooks/notify/index.sh"

echo "🗑️  Uninstalling Claude Code Notification Hooks..."

# Check if settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "ℹ️  No settings.json found, nothing to uninstall"
  exit 0
fi

# Backup settings.json
BACKUP_FILE="${SETTINGS_FILE}.backup.$(date +%s)"
cp "$SETTINGS_FILE" "$BACKUP_FILE"
echo "✅ Backup created: $BACKUP_FILE"

# Use Python to remove configuration
python3 <<'PYTHON'
import json
import os

settings_file = os.path.expanduser("~/.claude/settings.json")
hook_command = "~/.claude/hooks/notify/index.sh"

# Read existing configuration
with open(settings_file, 'r') as f:
    settings = json.load(f)

if 'hooks' not in settings:
    print("ℹ️  No hooks configuration found")
    exit(0)

# Remove hooks for Stop and Notification
removed_count = 0
for hook_type in ['Stop', 'Notification']:
    if hook_type in settings['hooks']:
        original_count = len(settings['hooks'][hook_type])

        # Filter out our hook
        settings['hooks'][hook_type] = [
            h for h in settings['hooks'][hook_type]
            if not (
                'hooks' in h and
                len(h['hooks']) > 0 and
                h['hooks'][0].get('command') == hook_command
            )
        ]

        new_count = len(settings['hooks'][hook_type])
        if new_count < original_count:
            removed_count += (original_count - new_count)
            print(f"✅ Removed {hook_type} hook")

if removed_count == 0:
    print("ℹ️  Notification hooks not found in configuration")
else:
    # Write back configuration
    with open(settings_file, 'w') as f:
        json.dump(settings, f, indent=2)

    print(f"✅ Removed {removed_count} hook(s) from settings.json")
PYTHON

echo ""
echo "✅ Uninstallation complete!"
echo ""
echo "The notification hook has been removed from your settings."
echo "To completely remove, you can delete: ~/.claude/hooks/notify"
echo ""
echo "Restart Claude Code for changes to take effect."
