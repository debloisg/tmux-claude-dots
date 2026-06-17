# tmux-claude-dots

A live, glanceable view of every [Claude Code](https://docs.claude.com/en/docs/claude-code) session running in your tmux server — rendered as small colored dots in the status bar, one per session.

- 🟡 **working** · 🔴 **waiting for you** · 🟢 **idle / done**
- **Click a dot** to jump straight to that pane.
- **`prefix + G`** opens an `fzf` picker with rich rows + a live preview of each session, and switches on Enter.
- **No polling daemon.** State is pushed by Claude Code hooks, which nudge tmux to repaint instantly — so the bar updates the moment a session changes, with zero idle CPU and no flicker.

> Status: early. Works well; APIs/option names may still change before a tagged release.

![demo](docs/demo.gif)

---

## Requirements

| Need | Why | Minimum |
|------|-----|---------|
| **tmux** | clickable status ranges (`#{mouse_status_range}`) | **3.4+** |
| **fzf** | the `prefix + G` picker (dots/clicks work without it) | any recent |
| **jq** | optional — only to keep a session "working" while background tasks run | optional |
| **mouse** | `set -g mouse on` — required for click-to-switch | — |

A Nerd Font isn't required; the default glyph is a plain Unicode `●`.

---

## Install

### With [TPM](https://github.com/tmux-plugins/tpm)

```tmux
set -g @plugin 'YOUR_GH_USER/tmux-claude-dots'
```

Then `prefix + I` to fetch it.

### Manual

```sh
git clone https://github.com/YOUR_GH_USER/tmux-claude-dots ~/.tmux/plugins/tmux-claude-dots
```

```tmux
run-shell '~/.tmux/plugins/tmux-claude-dots/claude-dots.tmux'
```

Either way, make sure the mouse is on:

```tmux
set -g mouse on
```

---

## Claude Code hook setup (required)

The dots only light up once Claude Code reports state. Add these hooks to
`~/.claude/settings.json` (adjust the path to wherever the plugin lives):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "~/.tmux/plugins/tmux-claude-dots/hooks/claude-hook.sh UserPromptSubmit" } ] }
    ],
    "PreToolUse": [
      { "hooks": [ { "type": "command", "command": "~/.tmux/plugins/tmux-claude-dots/hooks/claude-hook.sh PreToolUse" } ] }
    ],
    "Notification": [
      { "hooks": [ { "type": "command", "command": "~/.tmux/plugins/tmux-claude-dots/hooks/claude-hook.sh Notification" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "~/.tmux/plugins/tmux-claude-dots/hooks/claude-hook.sh Stop" } ] }
    ],
    "SessionEnd": [
      { "hooks": [ { "type": "command", "command": "~/.tmux/plugins/tmux-claude-dots/hooks/claude-hook.sh SessionEnd" } ] }
    ]
  }
}
```

Hooks load at session start, so restart any running Claude Code session after adding them.

---

## How it works

```
Claude Code ──hook──▶ claude-hook.sh ──writes──▶ $TMPDIR/claude-dots/<pane>
                            │                              ▲
                            └── tmux refresh-client -S     │ read on redraw
                                        │                  │
                                        ▼                  │
                              tmux status-right ──#()──▶ dots.sh ──▶ ●●●
                                        │
                          MouseDown1Status ──▶ click.sh ──▶ switch-client
                                        │
                          prefix + G ──▶ picker.sh (fzf popup) ──▶ switch-client
```

- Each Claude session is keyed by its tmux **pane id** (`$TMUX_PANE`), so multiple sessions per window, worktrees, and splits all track independently.
- `dots.sh` reaps state files whose pane no longer exists, so crashed sessions clean themselves up.
- Switching always re-targets the **real client** (`switch-client -c`), which matters because the picker runs inside a `display-popup` (its own client).

---

## Configuration

All options are global tmux user options — set them **before** the plugin loads.

| Option | Default | Description |
|--------|---------|-------------|
| `@claude_dots_key` | `G` | `prefix + <key>` to open the picker |
| `@claude_dots_glyph` | `●` | the status-bar glyph |
| `@claude_dots_separator` | `' '` | string between dots |
| `@claude_dots_color_working` | `yellow` | busy |
| `@claude_dots_color_waiting` | `red` | waiting for input/permission |
| `@claude_dots_color_idle` | `green` | turn finished |
| `@claude_dots_color_unknown` | `colour240` | unknown / stale |
| `@claude_dots_auto_status` | `on` | auto-prepend the renderer to `status-right`; set `off` to place it yourself |
| `@claude_dots_popup_width` | `80%` | picker popup width |
| `@claude_dots_popup_height` | `70%` | picker popup height |
| `@claude_dots_dir` | `$TMPDIR/claude-dots` | state directory (also export `CLAUDE_DOTS_DIR` for the hook if you change this) |

### Placing the dots yourself

With `@claude_dots_auto_status off`, drop the renderer wherever you like — e.g. left of a Catppuccin session module:

```tmux
set -g @claude_dots_auto_status 'off'
set -g status-right "#(~/.tmux/plugins/tmux-claude-dots/scripts/dots.sh)#{E:@catppuccin_status_session}"
```

---

## Credits

State-machine and `fzf` UX ideas were informed by
[samleeney/tmux-agent-status](https://github.com/samleeney/tmux-agent-status).
This project trades that plugin's sidebar/daemon model for a minimal,
event-driven, status-bar-only approach.

## License

[MIT](LICENSE)
