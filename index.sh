#!/bin/bash
# Claude Code notification helper script
# Uses $CLAUDE_PROJECT_DIR environment variable (set by Claude Code hooks)

# Hook type from first argument
hook_type="$1"

# Detect IDE CLI command name from bundle identifier
detect_ide_cli() {
  local bundle_id="$__CFBundleIdentifier"

  if [ -z "$bundle_id" ]; then
    echo "code"  # fallback
    return
  fi

  # Enable case-insensitive matching
  shopt -s nocasematch

  case "$bundle_id" in
    *vscode*)        echo "code" ;;
    *todesktop*)     echo "cursor" ;;
    *windsurf*)      echo "windsurf" ;;
    *)               echo "code" ;;  # fallback
  esac

  # Restore default case sensitivity
  shopt -u nocasematch
}

ide_cli=$(detect_ide_cli)

# Use plugin root if available, otherwise fall back to default path
if [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
  log_file="${CLAUDE_PLUGIN_ROOT}/debug.log"
else
  log_file=~/.claude/hooks/notify/debug.log
fi

# Debug log for IDE detection
debug_log() {
  if [ "$CLAUDE_NOTIFY_DEBUG" = "true" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$log_file"
  fi
}

debug_log "Detected IDE CLI: $ide_cli (bundle: $__CFBundleIdentifier)"

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

debug_log "Script started, hook_type: [$hook_type], CLAUDE_PROJECT_DIR: [$CLAUDE_PROJECT_DIR]"

# Deduplication: use mkdir as atomic lock to prevent concurrent notifications
lock_path="${CLAUDE_PLUGIN_ROOT:-~/.claude/hooks/notify}/.notify_lock_dir"
# Clean up stale lock (older than 3 seconds)
if [ -d "$lock_path" ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$lock_path" 2>/dev/null || echo 0) ))
  if [ "$lock_age" -gt 3 ]; then
    rmdir "$lock_path" 2>/dev/null
  fi
fi
# Atomic lock: mkdir only succeeds for one process
if ! mkdir "$lock_path" 2>/dev/null; then
  debug_log "SKIPPED: Dedup - another notification in progress"
  exit 0
fi
# Auto-release lock after 2 seconds
(sleep 2 && rmdir "$lock_path" 2>/dev/null) &

# 检测是否在 VSCode 终端中执行
if [ "$TERM_PROGRAM" != "vscode" ]; then
  debug_log "SKIPPED: Not running in VSCode terminal (TERM_PROGRAM=$TERM_PROGRAM)"
  exit 0
fi

debug_log "Running in VSCode terminal, proceeding with notification"

# Read JSON from stdin
json=$(cat)
debug_log "JSON read completed"

# Parse tool_name from JSON if available (for PreToolUse hook)
tool_name=$(echo "$json" | osascript -l JavaScript -e "
  var json = JSON.parse(\`$json\`);
  json.tool_name || '';
" 2>/dev/null)
debug_log "tool_name: $tool_name"

# Get project name from CLAUDE_PROJECT_DIR
project_name=$(basename "$CLAUDE_PROJECT_DIR")
debug_log "project_name: $project_name"

# Check if the IDE is the current foreground app (auto-dismiss notification if so)
front_bundle=$(osascript -e '
tell application "System Events"
  return bundle identifier of (first application process whose frontmost is true)
end tell
' 2>/dev/null)
debug_log "front_bundle: $front_bundle, ide_bundle: $__CFBundleIdentifier"

in_target_window="false"
if [ "$front_bundle" = "$__CFBundleIdentifier" ]; then
  debug_log "IDE is in foreground, will show auto-dismiss notification"
  in_target_window="true"
fi

# Generate message and sound based on hook type
# Sounds can be customized via environment variables
case "$hook_type" in
  PreToolUse)
    if [ "$tool_name" = "ExitPlanMode" ]; then
      msg="📋 Plan Ready"
      sound="${CLAUDE_NOTIFY_SOUND_PLAN:-Hero}"
    elif [ "$tool_name" = "AskUserQuestion" ]; then
      msg="❓ Question"
      sound="${CLAUDE_NOTIFY_SOUND_QUESTION:-Glass}"
    else
      msg="⚡ Interactive Tool"
      sound="${CLAUDE_NOTIFY_SOUND_QUESTION:-Glass}"
    fi
    ;;
  Notification)
    msg="❓ Notification"
    sound="${CLAUDE_NOTIFY_SOUND_QUESTION:-Glass}"
    ;;
  Stop)
    msg="✅ Task Completed"
    sound="${CLAUDE_NOTIFY_SOUND_COMPLETE:-Ping}"
    ;;
  *)
    msg="🔔 Task Update"
    sound="${CLAUDE_NOTIFY_SOUND_DEFAULT:-default}"
    ;;
esac

debug_log "Generated message: $msg, sound: $sound"

# Run alerter in background with nohup so it survives parent process termination
nohup bash -c "
  plugin_root=\"${CLAUDE_PLUGIN_ROOT:-~/.claude/hooks/notify}\"
  log_file=\"\${plugin_root}/debug.log\"
  project_dir=\"$CLAUDE_PROJECT_DIR\"
  debug_enabled=\"$CLAUDE_NOTIFY_DEBUG\"
  ide_cli=\"$ide_cli\"
  sound=\"$sound\"
  in_target_window=\"$in_target_window\"

  # Conditional logging function
  debug_log() {
    if [ \"\$debug_enabled\" = \"true\" ]; then
      echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] \$1\" >> \"\$log_file\"
    fi
  }

  debug_log \"Running alerter with sound: \$sound\"

  # Play sound with delay so notification popup appears first
  if [ \"${CLAUDE_NOTIFY_SOUND:-on}\" != \"off\" ] && [ -n \"\$sound\" ]; then
    sound_file=\"/System/Library/Sounds/\${sound}.aiff\"
    if [ -f \"\$sound_file\" ]; then
      (sleep 0.3 && afplay \"\$sound_file\") &
    fi
  fi

  # Show notification using alerter with project name in title
  # If already in target window, auto-dismiss after 5 seconds; otherwise persist
  if [ \"\$in_target_window\" = \"true\" ]; then
    notify_timeout=5
  else
    notify_timeout=0
  fi
  click_result=\$(\"\${plugin_root}/alerter\" -group \"$project_name\" -title \"Claude Code - $project_name\" -message \"$msg\" -actions \"Open\" -closeLabel \"Dismiss\" -timeout \$notify_timeout -contentImage \"\${plugin_root}/icon.png\" 2>/dev/null)

  # Debug logging
  debug_log \"Click result: [\$click_result]\"
  debug_log \"CLAUDE_PROJECT_DIR: [\$project_dir]\"

  # Open IDE if clicked
  if [ \"\$click_result\" = \"@CONTENTCLICKED\" ] || [ \"\$click_result\" = \"Open\" ]; then
    debug_log \"Condition matched, attempting to open IDE\"
    if [ -n \"\$project_dir\" ]; then
      debug_log \"Activating with: \$ide_cli \$project_dir\"
      \"\$ide_cli\" \"\$project_dir\"
    else
      debug_log \"ERROR: CLAUDE_PROJECT_DIR is empty\"
    fi
  else
    debug_log \"No action: click_result did not match\"
  fi
  debug_log \"---\"
" > /dev/null 2>&1 &

debug_log "Notification spawned in background"
