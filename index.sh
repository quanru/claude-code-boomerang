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

debug_log "Script started, CLAUDE_PROJECT_DIR: [$CLAUDE_PROJECT_DIR]"

# 检测是否在 VSCode 终端中执行
if [ "$TERM_PROGRAM" != "vscode" ]; then
  debug_log "SKIPPED: Not running in VSCode terminal (TERM_PROGRAM=$TERM_PROGRAM)"
  exit 0
fi

debug_log "Running in VSCode terminal, proceeding with notification"

# Read JSON from stdin
json=$(cat)
debug_log "JSON read completed"

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

# Parse message from JSON using osascript (JavaScript mode) - no jq dependency
msg=$(osascript -l JavaScript -e "
  var json = JSON.parse(\`$json\`);
  var hookType = json.hook_event_name || '';
  var message = '';

  if (hookType === 'Stop') {
    // Try to extract task information from JSON
    message = json.task_summary || json.message || 'Task completed';
  } else if (hookType === 'Notification') {
    message = json.message || 'Notification';
  } else {
    message = json.message || 'Task completed';
  }

  message;
" 2>/dev/null)

debug_log "Parsed message: $msg"

# Run alerter in background with nohup so it survives parent process termination
nohup bash -c "
  log_file=~/.claude/hooks/notify/debug.log
  project_dir=\"$CLAUDE_PROJECT_DIR\"
  debug_enabled=\"$CLAUDE_NOTIFY_DEBUG\"

  # Conditional logging function
  debug_log() {
    if [ \"\$debug_enabled\" = \"true\" ]; then
      echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] \$1\" >> \"\$log_file\"
    fi
  }

  # Show notification using alerter with project name in title
  click_result=\$(~/.claude/hooks/notify/alerter -group \"$project_name\" -title \"Claude Code - $project_name\" -message \"$msg\" -actions \"Open\" -closeLabel \"Dismiss\" -timeout 0 2>/dev/null)

  # Debug logging
  debug_log \"Click result: [\$click_result]\"
  debug_log \"CLAUDE_PROJECT_DIR: [\$project_dir]\"

  # Open VS Code if clicked
  if [ \"\$click_result\" = \"@CONTENTCLICKED\" ] || [ \"\$click_result\" = \"Open\" ] || [ \"\$click_result\" = \"@TIMEOUT\" ]; then
    debug_log \"Condition matched, attempting to open VS Code\"
    if [ -n \"\$project_dir\" ]; then
      debug_log \"Opening: vscode://file\$project_dir\"
      open \"vscode://file\$project_dir\"
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
