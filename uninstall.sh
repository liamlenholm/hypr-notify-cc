#!/bin/bash
# Hypr Notify CC — Uninstaller
set -euo pipefail

HOOK_PATH="$HOME/.claude/hooks/hypr-notify-cc.sh"
OPEN_PATH="$HOME/.claude/hooks/hypr-notify-cc-open.sh"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr-notify-cc"
SETTINGS_FILE="$HOME/.claude/settings.json"
MAKO_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/mako/config"

echo "Uninstalling Hypr Notify CC..."

# Remove hooks from settings.json
if [[ -f "$SETTINGS_FILE" ]]; then
    remove_hook() {
        local event="$1"
        local tmp
        tmp=$(mktemp)
        jq --arg event "$event" --arg path "$HOOK_PATH" '
            if .hooks[$event] then
                .hooks[$event] |= map(select(.hooks | all(.command | startswith($path) | not)))
                | if .hooks[$event] == [] then del(.hooks[$event]) else . end
            else . end
        ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    }

    remove_hook "UserPromptSubmit"
    remove_hook "Stop"
    remove_hook "Notification"
    echo "  Removed hooks from settings.json"
fi

# Remove scripts
for f in "$HOOK_PATH" "$OPEN_PATH" "$HOME/.claude/hooks/icon.png" "$HOME/.claude/hooks/notify.mp3"; do
    if [[ -f "$f" ]]; then
        rm "$f"
        echo "  Removed $f"
    fi
done

# Remove mako rule
if [[ -f "$MAKO_CONFIG" ]] && grep -q '\[app-name="Claude Code"\]' "$MAKO_CONFIG" 2>/dev/null; then
    tmp=$(mktemp)
    sed '/\[app-name="Claude Code"\]/,/^$/d' "$MAKO_CONFIG" > "$tmp" && mv "$tmp" "$MAKO_CONFIG"
    makoctl reload 2>/dev/null || true
    echo "  Removed mako click rule"
fi

# Remove temp files
rm -rf /tmp/hypr-notify-cc

# Ask about config
if [[ -d "$CONFIG_DIR" ]]; then
    read -rp "  Remove config at $CONFIG_DIR? [y/N] " answer
    if [[ "${answer,,}" == "y" ]]; then
        rm -rf "$CONFIG_DIR"
        echo "  Removed config"
    else
        echo "  Kept config"
    fi
fi

echo ""
echo "Done! Restart Claude Code for changes to take effect."
