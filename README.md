# Claude Code Desktop Notifications for macOS

> Get desktop notifications when Claude Code tasks complete. Click to jump to your VS Code window.

## Features

- ✅ Persistent notifications that won't auto-dismiss
- ✅ Click to jump to VS Code workspace
- ✅ Only one notification per project
- ✅ Auto-skip when already in target window
- ✅ Automatic log rotation
- ✅ Zero dependencies (macOS native + alerter)

## Quick Install

### One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/quanru/claude-code-notify/main/install.sh | bash
```

### Manual Install

```bash
# Clone repository
git clone https://github.com/quanru/claude-code-notify ~/.claude/hooks/notify

# Run installer
~/.claude/hooks/notify/install.sh
```

That's it! Restart Claude Code and you're done.

## Configuration (Optional)

Enable debug logging by adding to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_NOTIFY_DEBUG": "true"
  }
}
```

## Uninstall

```bash
~/.claude/hooks/notify/uninstall.sh
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
