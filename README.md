# Claude Code Boomerang

[简体中文](./README-ZH.md) | English

> Get desktop notifications when Claude Code tasks complete. Click to jump to your VS Code window.

## Features

- ✅ Persistent notifications that won't auto-dismiss
- ✅ Click to jump to your IDE workspace (VS Code, Cursor, WebStorm, IntelliJ, PyCharm, GoLand)
- ✅ Auto-detect IDE from environment
- ✅ Different notification sounds for different events
- ✅ Only one notification per project
- ✅ Auto-skip when already in target window
- ✅ Zero dependencies (macOS native + alerter)
- ✅ Support multiple hook types: Plan Ready, Questions, Task Complete, Subagent Complete

## Quick Install

### Plugin Installation

```bash
# 1. Add marketplace
/plugin marketplace add quanru/claude-code-boomerang

# 2. Install plugin
/plugin install claude-code-boomerang

# 3. Restart Claude Code
```

That's it! The plugin will automatically set up all required hooks.

## Supported IDEs

The plugin automatically detects your IDE and opens the correct workspace when you click the notification:

| IDE | Auto-detected | URL Scheme |
|-----|--------------|------------|
| VS Code | ✅ | `vscode://file` |
| Cursor | ✅ | `cursor://file` |
| WebStorm | ✅ | `webstorm://open?file=` |
| IntelliJ IDEA | ✅ | `idea://open?file=` |
| PyCharm | ✅ | `pycharm://open?file=` |
| GoLand | ✅ | `goland://open?file=` |

Detection is based on the `__CFBundleIdentifier` environment variable.

## Supported Hooks

The plugin monitors 3 types of Claude Code hooks with different sounds:

| Hook | Trigger | Notification | Sound |
|------|---------|-------------|-------|
| **PreToolUse** | Before ExitPlanMode | 📋 Plan Ready | Hero |
| **PreToolUse** | Before AskUserQuestion | ❓ Question | Glass |
| **Notification** | Permission prompts | ❓ Notification | Glass |
| **Stop** | Main task completed | ✅ Task Completed | Ping |

## Configuration (Optional)

Configure the plugin in `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_NOTIFY_DEBUG": "true",
    "CLAUDE_NOTIFY_SOUND": "on"
  }
}
```

**Available options**:
- `CLAUDE_NOTIFY_DEBUG`: Enable debug logging (`"true"` or `"false"`)
- `CLAUDE_NOTIFY_SOUND`: Control notification sounds (`"on"` or `"off"`, default: `"on"`)

## Uninstall

```bash
/plugin uninstall claude-code-boomerang
```

## Learn More

See **[GUIDE.md](./GUIDE.md)** for:
- Detailed installation steps
- How it works
- Debugging tips
- Troubleshooting
- Technical details

中文文档请查看 **[README-ZH.md](./README-ZH.md)**

## License

MIT
