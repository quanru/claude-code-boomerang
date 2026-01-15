# Claude Code 桌面通知 (macOS)

> 当 Claude Code 任务完成时接收桌面通知，点击即可跳转到 VS Code 窗口。

## 功能特性

- ✅ 常驻通知，不会自动消失
- ✅ 点击通知跳转到 VS Code 工作区
- ✅ 每个项目只显示一个通知
- ✅ 已在目标窗口时自动跳过
- ✅ 自动日志轮转
- ✅ 零依赖（macOS 原生 + alerter）

## 快速安装

### 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/quanru/claude-code-notify/main/install.sh | bash
```

### 手动安装

```bash
# 克隆仓库
git clone https://github.com/quanru/claude-code-notify ~/.claude/hooks/notify

# 运行安装脚本
~/.claude/hooks/notify/install.sh
```

完成！重启 Claude Code 即可使用。

## 配置（可选）

启用调试日志，在 `~/.claude/settings.json` 中添加：

```json
{
  "env": {
    "CLAUDE_NOTIFY_DEBUG": "true"
  }
}
```

## 卸载

```bash
~/.claude/hooks/notify/uninstall.sh
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
