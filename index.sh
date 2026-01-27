#!/bin/bash
# Claude Code notification helper script
# Uses $CLAUDE_PROJECT_DIR environment variable (set by Claude Code hooks)

# Hook type from first argument
hook_type="$1"

# Detect IDE and get URL scheme
detect_ide_scheme() {
  local bundle_id="$__CFBundleIdentifier"

  if [ -z "$bundle_id" ]; then
    echo "vscode://file"  # fallback
    return
  fi

  # Enable case-insensitive matching
  shopt -s nocasematch

  # Match bundle identifier patterns
  case "$bundle_id" in
    *vscode*)
      echo "vscode://file"
      ;;
    *todesktop*)
      echo "cursor://file"
      ;;
    *intellij*)
      echo "idea://open?file="
      ;;
    *webstorm*)
      echo "webstorm://open?file="
      ;;
    *pycharm*)
      echo "pycharm://open?file="
      ;;
    *goland*)
      echo "goland://open?file="
      ;;
    *)
      echo "vscode://file"  # fallback to vscode
      ;;
  esac

  # Restore default case sensitivity
  shopt -u nocasematch
}

ide_scheme=$(detect_ide_scheme)

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

debug_log "Detected IDE scheme: $ide_scheme (bundle: $__CFBundleIdentifier)"

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

# Check if current window is already the target VS Code window
# Use bundle identifier for precise detection (VS Code = com.microsoft.VSCode)
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
debug_log "current_app: $current_app, bundle_id: $bundle_id"

if [ "$bundle_id" = "com.microsoft.VSCode" ]; then
  window_title=$(osascript -e "tell application \"System Events\" to get name of first window of application process \"$current_app\"" 2>/dev/null)
  debug_log "window_title: $window_title"
  # If window title contains project name, skip notification
  if [[ "$window_title" == *"$project_name"* ]]; then
    debug_log "SKIPPED: Already in target window ($project_name)"
    exit 0
  fi
fi

# Generate message and sound based on hook type
case "$hook_type" in
  PreToolUse)
    if [ "$tool_name" = "ExitPlanMode" ]; then
      msg="📋 Plan Ready"
      sound="Hero"
    elif [ "$tool_name" = "AskUserQuestion" ]; then
      msg="❓ Question"
      sound="Glass"
    else
      msg="⚡ Interactive Tool"
      sound="Glass"
    fi
    ;;
  Notification)
    msg="❓ Notification"
    sound="Glass"
    ;;
  Stop)
    msg="✅ Task Completed"
    sound="Ping"
    ;;
  SubagentStop)
    msg="✅ Subagent Completed"
    sound="Basso"
    ;;
  *)
    msg="🔔 Task Update"
    sound="default"
    ;;
esac

debug_log "Generated message: $msg, sound: $sound"

# Run alerter in background with nohup so it survives parent process termination
nohup bash -c "
  plugin_root=\"${CLAUDE_PLUGIN_ROOT:-~/.claude/hooks/notify}\"
  log_file=\"\${plugin_root}/debug.log\"
  project_dir=\"$CLAUDE_PROJECT_DIR\"
  debug_enabled=\"$CLAUDE_NOTIFY_DEBUG\"
  ide_scheme=\"$ide_scheme\"
  sound=\"$sound\"

  # Conditional logging function
  debug_log() {
    if [ \"\$debug_enabled\" = \"true\" ]; then
      echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] \$1\" >> \"\$log_file\"
    fi
  }

  debug_log \"Running alerter with sound: \$sound\"

  # Play sound via afplay (non-blocking)
  if [ \"${CLAUDE_NOTIFY_SOUND:-on}\" != \"off\" ] && [ -n \"\$sound\" ]; then
    sound_file=\"/System/Library/Sounds/\${sound}.aiff\"
    if [ -f \"\$sound_file\" ]; then
      afplay \"\$sound_file\" &
    fi
  fi

  # Show notification using alerter with project name in title
  click_result=\$(\"\${plugin_root}/alerter\" -group \"$project_name\" -title \"Claude Code - $project_name\" -message \"$msg\" -actions \"Open\" -closeLabel \"Dismiss\" -timeout 0 2>/dev/null)

  # Debug logging
  debug_log \"Click result: [\$click_result]\"
  debug_log \"CLAUDE_PROJECT_DIR: [\$project_dir]\"

  # Open IDE if clicked
  if [ \"\$click_result\" = \"@CONTENTCLICKED\" ] || [ \"\$click_result\" = \"Open\" ] || [ \"\$click_result\" = \"@TIMEOUT\" ]; then
    debug_log \"Condition matched, attempting to open IDE\"
    if [ -n \"\$project_dir\" ]; then
      # Build IDE URL (JetBrains uses ?file=, others use direct path)
      if [[ \"\$ide_scheme\" == *\"?file=\"* ]]; then
        ide_url=\"\${ide_scheme}\${project_dir}\"
      else
        ide_url=\"\${ide_scheme}\${project_dir}\"
      fi
      debug_log \"Opening: \$ide_url\"
      open \"\$ide_url\"
      debug_log \"open command completed\"
    else
      debug_log \"ERROR: CLAUDE_PROJECT_DIR is empty\"
    fi
  else
    debug_log \"No action: click_result did not match\"
  fi
  debug_log \"---\"
" > /dev/null 2>&1 &

debug_log "Notification spawned in background"
