# Shared agent UI

This directory is the tracked source of truth for the Claude and Codex status
lines and their shared tmux lifecycle marker.

- `statusline.json` defines semantic status-line segments, their order, the
  Codex fields each segment maps to, Claude's visual settings, and the shared
  tmux state glyphs.
- Claude reads `statusline.json` on every status-line render, so changes to
  ordering, icons, separators, bar width, and name length take effect
  automatically.
- Codex only supports an ordered list of native status-line fields.
  `sync-agent-ui` expands the semantic segments through `codex.fields` and
  writes the result to `tui.status_line` in `~/.codex/config.toml`.
- `tmux-state` writes the shared lifecycle marker to the owning tmux window.
- `codex-tmux-hook.sh` translates Codex lifecycle hook payloads into those
  shared states.

After editing `statusline.json`, run this to update Codex:

```sh
sync-agent-ui
```

Use `sync-agent-ui --check` to verify that Codex is already in sync without
changing its configuration.

The sync is semantic rather than visual: Claude supports a custom renderer, so
it can show icons and bars; Codex controls the rendering of its native fields.
