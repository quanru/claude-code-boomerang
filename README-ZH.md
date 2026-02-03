# Claude Code 回旋镖

简体中文 | [English](./README.md)

> 当 Claude Code 任务完成时接收桌面通知，点击即可跳转到 VS Code 窗口。

## 功能特性

- ✅ 常驻通知，不会自动消失（已在目标窗口时 5 秒后自动消失）
- ✅ 点击通知跳转到你的 IDE 工作区（支持 VS Code、Cursor、WebStorm、IntelliJ、PyCharm、GoLand）
- ✅ 智能窗口激活：优先激活已存在的窗口，支持父目录匹配
- ✅ 自动检测 IDE 类型
- ✅ 不同事件使用不同的提示音
- ✅ 每个项目只显示一个通知
- ✅ 零依赖（macOS 原生 + alerter）
- ✅ 支持多种 hook 类型：计划就绪、提问、任务完成、子任务完成

## 快速安装

### 插件安装

```bash
# 1. 添加市场
/plugin marketplace add quanru/claude-code-boomerang

# 2. 安装插件
/plugin install claude-code-boomerang

# 3. 重启 Claude Code
```

完成！插件会自动设置所有必要的 hooks。

## 支持的 IDE

插件会自动检测你的 IDE，点击通知时打开正确的工作区：

| IDE | 自动检测 | URL Scheme |
|-----|---------|------------|
| VS Code | ✅ | `vscode://file` |
| Cursor | ✅ | `cursor://file` |
| WebStorm | ✅ | `webstorm://open?file=` |
| IntelliJ IDEA | ✅ | `idea://open?file=` |
| PyCharm | ✅ | `pycharm://open?file=` |
| GoLand | ✅ | `goland://open?file=` |

检测基于 `__CFBundleIdentifier` 环境变量。

## 支持的 Hooks

插件监听 3 种 Claude Code hooks，每种使用不同的提示音：

| Hook | 触发时机 | 通知内容 | 提示音 |
|------|---------|----------|--------|
| **PreToolUse** | ExitPlanMode 之前 | 📋 Plan Ready | Hero |
| **PreToolUse** | AskUserQuestion 之前 | ❓ Question | Glass |
| **Notification** | 权限提示 | ❓ Notification | Glass |
| **Stop** | 主任务完成 | ✅ Task Completed | Ping |

## 配置（可选）

在 `~/.claude/settings.json` 中配置插件：

```json
{
  "env": {
    "CLAUDE_NOTIFY_DEBUG": "true",
    "CLAUDE_NOTIFY_SOUND": "on",
    "CLAUDE_NOTIFY_SOUND_PLAN": "Hero",
    "CLAUDE_NOTIFY_SOUND_QUESTION": "Glass",
    "CLAUDE_NOTIFY_SOUND_COMPLETE": "Ping"
  }
}
```

**可用选项**:
- `CLAUDE_NOTIFY_DEBUG`: 启用调试日志（`"true"` 或 `"false"`）
- `CLAUDE_NOTIFY_SOUND`: 控制通知音效（`"on"` 或 `"off"`，默认：`"on"`）
- `CLAUDE_NOTIFY_SOUND_PLAN`: Plan Ready 提示音（默认：`"Hero"`）
- `CLAUDE_NOTIFY_SOUND_QUESTION`: Question/Notification 提示音（默认：`"Glass"`）
- `CLAUDE_NOTIFY_SOUND_COMPLETE`: Task Completed 提示音（默认：`"Ping"`）

**可用声音**: Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink

## 卸载

```bash
/plugin uninstall claude-code-boomerang
```

## 了解更多

查看 **[GUIDE-ZH.md](./GUIDE-ZH.md)** 了解：
- 详细安装步骤
- 工作原理
- 调试技巧
- 故障排除
- 技术细节

English documentation see **[README.md](./README.md)**

## 许可证

MIT
