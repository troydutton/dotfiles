#!/bin/sh
# Translate Codex hook payloads into the shared tmux lifecycle states.
set -eu

payload=$(cat)
event=$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null) || exit 0
tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0

case "$event" in
    SessionStart)
        state=ok
        ;;
    SessionEnd)
        state=clear
        ;;
    UserPromptSubmit)
        state=run
        ;;
    PermissionRequest)
        state=ask
        ;;
    PreToolUse)
        case "$tool_name" in
            *request_user_input*|*AskUserQuestion*|*ask_user_question*)
                state=ask
                ;;
            *)
                state=run
                ;;
        esac
        ;;
    PostToolUse)
        state=run
        ;;
    Stop)
        state=ok
        ;;
    *)
        exit 0
        ;;
esac

exec "$HOME/.agents/tmux-state" "$state"
