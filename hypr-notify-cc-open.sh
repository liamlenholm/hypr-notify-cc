#!/bin/bash
# Hypr Notify CC — Click handler
# Switches to the tmux session that sent the notification and focuses the terminal.

set -euo pipefail

TIMEDIR="/tmp/hypr-notify-cc"
SESSION_FILE="$TIMEDIR/last_session"

# Dismiss the notification
makoctl dismiss 2>/dev/null || true

# Focus the terminal window
hyprctl dispatch focuswindow "class:com.mitchellh.ghostty" 2>/dev/null \
    || hyprctl dispatch focuswindow "class:Alacritty" 2>/dev/null \
    || hyprctl dispatch focuswindow "class:kitty" 2>/dev/null \
    || true

# Switch to the tmux session and window
# We need to target the client explicitly since mako runs outside tmux
if [[ -f "$SESSION_FILE" ]] && command -v tmux &>/dev/null; then
    target=$(cat "$SESSION_FILE")
    client=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -1)
    if [[ -n "$client" ]]; then
        tmux switch-client -c "$client" -t "$target" 2>/dev/null || true
    fi
fi
