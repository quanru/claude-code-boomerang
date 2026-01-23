#!/bin/bash
# Claude Code Notification Hooks - Installation Script

set -e

SETTINGS_FILE="$HOME/.claude/settings.json"
INSTALL_DIR="$HOME/.claude/hooks/notify"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/quanru/claude-code-boomerang.git"

echo "🚀 Installing Claude Code Notification Hooks..."

# Determine source directory
# Priority: 1. Already installed directory  2. Script directory  3. Auto clone
if [ -f "$INSTALL_DIR/index.sh" ] && [ -f "$INSTALL_DIR/alerter" ]; then
  SOURCE_DIR="$INSTALL_DIR"
  echo "✅ Found existing installation at $INSTALL_DIR"
elif [ -f "$SCRIPT_DIR/index.sh" ] && [ -f "$SCRIPT_DIR/alerter" ]; then
  SOURCE_DIR="$SCRIPT_DIR"
  echo "✅ Found source files at $SCRIPT_DIR"
else
  echo "📦 Required files not found, cloning repository..."

  # Check if git is available
  if ! command -v git &> /dev/null; then
    echo "❌ Error: git is not installed"
    echo "Please install git first: brew install git"
    exit 1
  fi

  # Remove existing directory if it exists but incomplete
  if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  Removing incomplete installation..."
    rm -rf "$INSTALL_DIR"
  fi

  # Clone the repository
  if git clone "$REPO_URL" "$INSTALL_DIR"; then
    echo "✅ Repository cloned successfully"
    SOURCE_DIR="$INSTALL_DIR"
  else
    echo "❌ Error: Failed to clone repository"
    echo "Please try manual installation:"
    echo "  git clone $REPO_URL ~/.claude/hooks/notify"
    echo "  ~/.claude/hooks/notify/install.sh"
    exit 1
  fi
fi

# If source is not the install directory, copy files
if [ "$SOURCE_DIR" != "$INSTALL_DIR" ]; then
  echo "📦 Copying files to $INSTALL_DIR..."
  mkdir -p "$INSTALL_DIR"
  cp -r "$SOURCE_DIR"/* "$INSTALL_DIR/"
  echo "✅ Files copied successfully"
fi

# Make sure scripts are executable
chmod +x "$INSTALL_DIR/index.sh"
chmod +x "$INSTALL_DIR/alerter"

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
