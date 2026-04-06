#!/bin/bash
# Hypr Notify CC — Desktop notifications for Claude Code on Hyprland
# https://github.com/liamlenholm/hypr-notify-cc

set -euo pipefail

EVENT="${1:-}"
DATA=$(cat)

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr-notify-cc"
CONFIG_FILE="$CONFIG_DIR/config"
TIMEDIR="/tmp/hypr-notify-cc"
mkdir -p "$TIMEDIR"

# Constants
APP_NAME="Claude Code"

# Defaults (configurable)
TERMINAL_CLASSES="com.mitchellh.ghostty|Alacritty|kitty|foot|wezterm"
STOP_DEDUP_WINDOW=3
TIMEOUT=5000

# Load user config
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Parse event data
session_id=$(echo "$DATA" | jq -r '.session_id // empty')
cwd=$(echo "$DATA" | jq -r '.cwd // empty')
project=$(basename "${cwd:-unknown}")

is_focused() {
    # Layer 1: Is a terminal focused in Hyprland?
    local active_class
    active_class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty') || return 1
    echo "$active_class" | grep -qE "$TERMINAL_CLASSES" || return 1

    # Layer 2: If tmux is available, check if this session is being viewed
    if [[ -n "${TMUX_PANE:-}" ]] && command -v tmux &>/dev/null; then
        local client_session pane_session
        client_session=$(tmux display-message -p '#{client_session}' 2>/dev/null) || return 1
        pane_session=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}' 2>/dev/null) || return 1
        [[ "$client_session" == "$pane_session" ]] || return 1
    fi

    return 0
}

ICON_PATH="${ICON_PATH:-$HOME/.claude/hooks/icon.png}"
SOUND_PATH="${SOUND_PATH:-$HOME/.claude/hooks/notify.mp3}"
SOUND_ENABLED="${SOUND_ENABLED:-true}"
SOUND_VOLUME="${SOUND_VOLUME:-50}"

send() {
    local urgency="$1" title="$2" body="$3"

    # Store tmux session name so the click handler can switch to it
    if [[ -n "${TMUX_PANE:-}" ]] && command -v tmux &>/dev/null; then
        local pane_session
        pane_session=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}' 2>/dev/null || true)
        if [[ -n "$pane_session" ]]; then
            echo "$pane_session" > "$TIMEDIR/last_session"
        fi
    fi

    local icon_args=()
    [[ -f "$ICON_PATH" ]] && icon_args=(-i "$ICON_PATH")

    notify-send -a "$APP_NAME" -u "$urgency" -r 19790 -t "$TIMEOUT" "${icon_args[@]}" "$title" "$body"

    if [[ "$SOUND_ENABLED" == "true" && -f "$SOUND_PATH" ]]; then
        mpv --no-video --really-quiet --volume="$SOUND_VOLUME" "$SOUND_PATH" &>/dev/null &
    fi
}

# Skip worktree subagent events
if echo "$cwd" | grep -q '\.claude/worktrees/'; then
    exit 0
fi

# Skip notifications if we're looking at this Claude session
if is_focused; then
    exit 0
fi

case "$EVENT" in
    Stop)
        last_msg=$(echo "$DATA" | jq -r '.last_assistant_message // empty')
        last_msg_lower=$(echo "$last_msg" | tr '[:upper:]' '[:lower:]')

        # Detect intermediate progress updates (subagents still running)
        if echo "$last_msg_lower" | grep -qE "waiting on [0-9]+ more|waiting for (results|remaining)|launched .* in parallel|agents? still running|agent left running"; then
            exit 0
        fi

        send normal "$project" "Task complete"
        echo "$(date +%s)" > "$TIMEDIR/${session_id}.stop"
        ;;

    Notification)
        # Suppress if Stop just fired for this session
        stop_file="$TIMEDIR/${session_id}.stop"
        if [[ -f "$stop_file" ]]; then
            stop_time=$(cat "$stop_file")
            now=$(date +%s)
            if ((now - stop_time < STOP_DEDUP_WINDOW)); then
                rm -f "$stop_file"
                exit 0
            fi
            rm -f "$stop_file"
        fi

        message=$(echo "$DATA" | jq -r '.message // empty')
        msg_lower=$(echo "$message" | tr '[:upper:]' '[:lower:]')

        if echo "$msg_lower" | grep -q "permission"; then
            send critical "$project" "Permission required"
        elif echo "$msg_lower" | grep -qE "approval|choose an option"; then
            send critical "$project" "Action required"
        elif echo "$msg_lower" | grep -q "waiting for"; then
            send normal "$project" "Waiting for input"
        else
            send normal "$project" "$message"
        fi
        ;;
esac
