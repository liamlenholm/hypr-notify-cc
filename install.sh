#!/bin/bash
# Hypr Notify CC — Installer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.claude/hooks"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr-notify-cc"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_PATH="$INSTALL_DIR/hypr-notify-cc.sh"
OPEN_PATH="$INSTALL_DIR/hypr-notify-cc-open.sh"
MAKO_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/mako/config"

echo "Installing Hypr Notify CC..."

# Check dependencies
for cmd in jq notify-send hyprctl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not installed."
        exit 1
    fi
done

# Install script
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/hypr-notify-cc.sh" "$HOOK_PATH"
cp "$SCRIPT_DIR/hypr-notify-cc-open.sh" "$OPEN_PATH"
cp "$SCRIPT_DIR/icon.png" "$INSTALL_DIR/icon.png"
chmod +x "$HOOK_PATH" "$OPEN_PATH"
echo "  Installed scripts and icon to $INSTALL_DIR/"

# Install config
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/config" ]]; then
    cp "$SCRIPT_DIR/config.example" "$CONFIG_DIR/config"
    echo "  Created config at $CONFIG_DIR/config"
else
    echo "  Config already exists at $CONFIG_DIR/config, skipping"
fi

# Merge hooks into settings.json
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Build the three hook entries with the event name passed as arg
add_hook() {
    local event="$1"
    local entry
    entry=$(jq -n --arg cmd "$HOOK_PATH $event" '{hooks: [{type: "command", command: $cmd}]}')

    # Check if this hook already exists
    if jq -e --arg cmd "$HOOK_PATH $event" ".hooks.${event}[]? | select(.hooks[]?.command == \$cmd)" "$SETTINGS_FILE" &>/dev/null; then
        echo "  Hook for $event already exists, skipping"
        return
    fi

    # Add the hook (create array if it doesn't exist, append if it does)
    local tmp
    tmp=$(mktemp)
    jq --arg event "$event" --argjson entry "$entry" '
        .hooks //= {} |
        .hooks[$event] //= [] |
        .hooks[$event] += [$entry]
    ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    echo "  Added $event hook"
}

add_hook "Stop"
add_hook "Notification"

# Add mako click-to-switch rule
MAKO_RULE='[app-name="Claude Code"]
on-button-left=exec sh -c '"'"'$HOME/.claude/hooks/hypr-notify-cc-open.sh'"'"''

if [[ -f "$MAKO_CONFIG" ]]; then
    if grep -q '\[app-name="Claude Code"\]' "$MAKO_CONFIG" 2>/dev/null; then
        echo "  Mako rule already exists, skipping"
    else
        echo "" >> "$MAKO_CONFIG"
        echo "$MAKO_RULE" >> "$MAKO_CONFIG"
        echo "  Added mako click rule"
        makoctl reload 2>/dev/null || true
    fi
else
    echo "  Warning: mako config not found at $MAKO_CONFIG"
    echo "  Add this rule manually to your mako config:"
    echo "    $MAKO_RULE"
fi

echo ""
echo "Done! Restart Claude Code for hooks to take effect."
