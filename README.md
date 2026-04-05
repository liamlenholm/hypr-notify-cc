# Hypr Notify CC

Desktop notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) on [Hyprland](https://hyprland.org/).

Get notified when Claude finishes a task or needs your attention — only when you're not already looking at it.

![Hyprland](https://img.shields.io/badge/Hyprland-blue) ![Mako](https://img.shields.io/badge/Mako-green) ![Claude Code](https://img.shields.io/badge/Claude%20Code-orange)

![screenshot](https://i.imgur.com/KsAlY4M.jpeg)

## Features

- Notifies on task completion
- Notifies when Claude needs permission or input
- Click notification to jump to the Claude session (focuses terminal + switches tmux session)
- Smart focus detection — no notification if you're already looking at the terminal
- Layered awareness: Hyprland window focus → tmux session (if available)
- Works with or without tmux/sesh
- Configurable terminal classes and behavior

## Requirements

- [Hyprland](https://hyprland.org/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- `notify-send` (libnotify)
- `jq`
- [Mako](https://github.com/emersion/mako) notification daemon
- A supported terminal: [Ghostty](https://ghostty.org/), [Alacritty](https://alacritty.org/), [Kitty](https://sw.kovidgoyal.net/kitty/), [foot](https://codeberg.org/dnkl/foot), or [WezTerm](https://wezfurlong.org/wezterm/) (configurable)

## Install

```bash
git clone https://github.com/liamlenholm/hypr-notify-cc.git
cd hypr-notify-cc
./install.sh
```

This will:
1. Copy the hook scripts to `~/.claude/hooks/`
2. Create a config file at `~/.config/hypr-notify-cc/config`
3. Add the required hooks to `~/.claude/settings.json`
4. Add a mako rule so clicking a notification switches to the Claude session

Restart Claude Code for the hooks to take effect.

## Uninstall

```bash
./uninstall.sh
```

## Configuration

Edit `~/.config/hypr-notify-cc/config`:

```bash
# Terminal window classes to detect focus (pipe-separated regex)
TERMINAL_CLASSES="com.mitchellh.ghostty|Alacritty|kitty|foot|wezterm"

# Seconds to suppress duplicate notifications after task completion
STOP_DEDUP_WINDOW=3

# Notification timeout in milliseconds (0 = never expire)
TIMEOUT=5000
```

## How it works

Hypr Notify CC hooks into two Claude Code events:

| Event | What happens |
|-------|-------------|
| `Stop` | Sends a "Task complete" notification |
| `Notification` | Sends alerts for permission requests, input waits, etc. |

### Focus detection

Notifications are suppressed when you're already looking at Claude:

1. **Hyprland** — checks if the active window is a terminal
2. **tmux** (optional) — checks if the tmux client is viewing the session running Claude

If you don't use tmux, it falls back to terminal focus only. If you use tmux with [sesh](https://github.com/joshmedeski/sesh) or similar session managers, it correctly detects when you've switched to a different session.

## License

MIT
