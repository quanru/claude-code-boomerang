# Claude Code 通知系统 - 详细指南

本指南提供关于通知系统如何工作的深入信息、故障排除提示和高级配置选项。

## 目录

- [手动安装](#手动安装)
- [工作原理](#工作原理)
- [技术细节](#技术细节)
- [调试](#调试)
- [高级配置](#高级配置)
- [故障排除](#故障排除)
- [其他方案对比](#其他方案对比)
- [依赖说明](#依赖说明)

## 手动安装

如果您希望手动安装而不使用安装脚本:

### 1. 下载 alerter

[alerter](https://github.com/vjeantet/alerter) 是一个支持 Alert 类型通知的命令行工具。

```bash
curl -L https://github.com/vjeantet/alerter/releases/download/1.0.1/alerter_v1.0.1_darwin_amd64.zip -o /tmp/alerter.tar.gz \
  && mkdir -p ~/.claude/hooks/notify /tmp/alerter_extract \
  && tar -xzf /tmp/alerter.tar.gz -C /tmp/alerter_extract \
  && mv /tmp/alerter_extract/alerter ~/.claude/hooks/notify/ \
  && chmod +x ~/.claude/hooks/notify/alerter \
  && rm -rf /tmp/alerter_extract /tmp/alerter.tar.gz \
  && ~/.claude/hooks/notify/alerter -help
```

### 2. 创建通知脚本

创建 `~/.claude/hooks/notify/index.sh`:

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

### 3. 配置 Claude Code Hooks

编辑 `~/.claude/settings.json` 并添加:

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

### 4. 重启 Claude Code

重启 Claude Code 或使用 `/hooks` 命令重新加载配置。

## 工作原理

```
Claude Code 完成任务 / 需要注意
       ↓
触发 Stop / Notification Hook
       ↓
index.sh 使用 bundle identifier 检查是否当前在 VS Code 中
       ↓ (不在目标窗口)
alerter 使用 -group 参数确保每个项目只显示一个通知
       ↓
新通知自动替换旧通知（同一项目）
       ↓
使用 nohup 在后台启动 alerter（独立进程）
       ↓
父脚本立即返回,alerter 继续运行
       ↓
用户点击通知
       ↓
通过 vscode://file 协议打开项目根目录
```

## 技术细节

### 为什么使用 bundle identifier?

VS Code 在 macOS System Events 中可能被识别为 `Code` 或 `Electron`。使用 bundle identifier (`com.microsoft.VSCode`) 可以精确识别 VS Code，避免其他 Electron 应用的误报。

### Group ID 机制

每个项目使用其项目名称作为唯一的通知组 ID。当为同一项目触发新通知时，alerter 会自动关闭旧通知并显示新通知。这确保了:

- 同一项目不会出现重复通知
- 不同项目可以同时显示通知
- 无需手动管理进程（由 alerter 处理）

### 为什么使用 nohup?

Claude Code 可能会在任务完成后终止 hook 脚本的父进程。使用 `nohup` 允许 alerter 在独立的后台进程中运行，确保即使父进程被终止，通知仍然继续等待用户交互。

### 为什么使用 `$CLAUDE_PROJECT_DIR` 而不是 `cwd`?

hook JSON 中的 `cwd` 字段会随着用户在会话期间执行 `cd` 命令而动态变化。

`$CLAUDE_PROJECT_DIR` 环境变量由 Claude Code 在执行 hooks 时自动设置，**始终指向项目根目录**，确保通知正确跳转到项目根目录。

### 为什么选择 alerter?

macOS 有两种通知类型:

| 类型 | 行为 | 代码可控 |
|------|------|---------|
| Banner | 几秒后自动消失 | ❌ 由系统设置控制 |
| Alert | 持续显示直到用户操作 | ❌ 由系统设置控制 |

`terminal-notifier` 发送 Banner 类型通知，是否持续取决于系统设置。

`alerter` 直接发送 Alert 类型通知，**无需更改系统设置**，通知默认持续显示。

### 点击检测逻辑

`alerter` 根据用户操作返回不同的值:

| 用户操作 | 返回值 |
|---------|--------|
| 点击通知内容 | `@CONTENTCLICKED` |
| 点击 "Open" 按钮 | `Open`（按钮文本） |
| 点击 "Dismiss" 按钮 | `Dismiss`（按钮文本） |
| 关闭通知 | 空字符串 |

脚本检查返回值是否为 `@CONTENTCLICKED` 或 `Open`，如果是则跳转到 VS Code。

## 调试

### 启用调试模式

调试日志默认禁用以获得更好的性能。要启用它，请在 `~/.claude/settings.json` 中添加:

```json
{
  "env": {
    "CLAUDE_NOTIFY_DEBUG": "true"
  }
}
```

### 查看日志

```bash
tail -f ~/.claude/hooks/notify/debug.log
```

日志文件会在超过 400 行时自动轮转，只保留最近的 200 行。

### 记录哪些内容

当调试模式启用时，脚本会记录:
- 脚本启动时间和项目目录
- 当前应用程序和 bundle ID
- 窗口标题检查
- 解析的通知消息
- 点击结果和 VS Code 启动尝试

## 高级配置

### 自定义通知消息

您可以通过修改 `index.sh` 中的消息解析逻辑来自定义通知消息。当前实现尝试从 hook JSON 中提取 `task_summary` 或 `message` 字段。

### 多个 Hook 命令

您可以添加其他命令与通知 hook 一起运行。例如，运行 linters:

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

注意: 同一事件中的 hooks 默认并行运行。

### 项目特定配置

使用 matchers 为不同项目应用不同的通知行为:

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

## 故障排除

### 通知未显示

1. **检查 hooks 是否正确配置**:
   ```bash
   cat ~/.claude/settings.json | grep -A 10 "hooks"
   ```

2. **验证 index.sh 存在且可执行**:
   ```bash
   ls -la ~/.claude/hooks/notify/index.sh
   ```

3. **启用调试模式**并检查日志中的错误

4. **直接测试 alerter**:
   ```bash
   ~/.claude/hooks/notify/alerter -message "Test" -title "Test"
   ```

### 通知显示但点击无效

1. **验证 VS Code URL scheme 已注册**:
   ```bash
   open "vscode://file$HOME"
   ```
   这应该会打开 VS Code 到您的主目录。

2. **检查调试日志**以查看点击结果和 open 命令

### 同一项目出现多个通知

1. 确保您使用的是带有 `-group` 参数的最新版本 `index.sh`
2. 检查 `settings.json` 中是否有重复的 hook 配置

### 日志文件增长过大

日志文件在启用调试模式时应该自动轮转。如果没有:
1. 验证 `CLAUDE_NOTIFY_DEBUG` 设置为 `"true"`（字符串，不是布尔值）
2. 手动清理: `rm ~/.claude/hooks/notify/debug.log`

## 其他方案对比

在选定 `alerter + nohup + open` 之前，我们尝试了几种方案:

| 方案 | 持续显示 | 跳转 | 问题 |
|------|---------|------|------|
| terminal-notifier | ⚠️ 需要系统设置 | ✅ | 依赖系统设置 |
| terminal-notifier + `-sender` | ✅ | ❌ | 产生重复通知 |
| osascript `display notification` | ⚠️ 需要系统设置 | ❌ | 不支持点击回调 |
| osascript `display dialog` | ✅ | ✅ | 对话框而非通知 |
| VS Code 扩展 + node-notifier | ⚠️ | ⚠️ | 复杂且不稳定 |
| AppleScript + AXRaise | ✅ | ⚠️ | 跨虚拟桌面不稳定 |
| **alerter + nohup + open** | ✅ | ✅ | **推荐** |

## 依赖说明

### 必需

- **macOS** - 通知系统使用 macOS 特定的 API
- **alerter** - 命令行通知工具 ([GitHub](https://github.com/vjeantet/alerter))
- **VS Code** - 必须支持 `vscode://` 协议

### 系统要求

- macOS 10.10+ (支持通知中心)
- Python 3 (macOS 10.15+ 预装，安装脚本使用)
- Bash 3.2+ (macOS 默认 shell)

## 贡献

发现 bug 或有建议？请在 GitHub 上提交 issue。

## 许可证

MIT
