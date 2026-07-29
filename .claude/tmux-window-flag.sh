# Tag the tmux window holding this Claude session with a state marker.
# Called from Claude Code hooks; rendered by window-status-format via @claude_state.
# Uses a window option rather than rename-window so automatic-rename keeps working.
[ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] || exit 0

case "$1" in
  run) GLYPH=◐ ;;  # working
  ask) GLYPH=▲ ;;  # blocked on you
  ok)  GLYPH=◌ ;;  # turn finished
  *)
    tmux set-option -w -t "$TMUX_PANE" -u @claude_state 2>/dev/null
    exit 0
    ;;
esac

tmux set-option -w -t "$TMUX_PANE" @claude_state "$GLYPH" 2>/dev/null
exit 0
