# tmux-claude-dots

<img width="800" height="313" alt="claude-dots-explained" src="https://github.com/user-attachments/assets/aed8e1b6-7f7c-4f35-ab74-98a7a0fd2e63" />



A live, glanceable view of every [Claude Code](https://docs.claude.com/en/docs/claude-code) session running in your tmux server — rendered as small colored dots in the status bar, one per session.

- Dots, grouped by tmux sessions indicating state of claude code. 
    - 🔵 **working**
    - 🟠 **needs you** (permission/approval/question)
    - 🟢 **finished — your turn**
    - ⚪ **idle / seen**
    - ○ **unknown**
    - _ **underlined dots** means they are in the active tmux windows. The active claude sessiosn has a bigger dot.
- **Click a dot** to jump straight to that pane.
- **jump to a claude with alphanumerics**: you can activate the jump mode that transforms the dots into alphanumeric characters to jump to the right one.
- **`prefix + G`** opens an `fzf` picker with rich rows + a live preview of each session, and switches on Enter.
- **No polling daemon.** State is pushed by Claude Code hooks, which nudge tmux to repaint instantly — so the bar updates the moment a session changes, with zero idle CPU and no flicker.

> Status: early. Works well; APIs/option names may still change before a tagged release.

![demo](docs/demo.gif)

---

## Requirements

| Need | Why | Minimum |
|------|-----|---------|
| **tmux** | clickable status ranges (`#{mouse_status_range}`) | **3.4+** |
| **bash** | the scripts use associative arrays | **4.0+** (macOS: `brew install bash`) |
| **fzf** | the `prefix + G` picker (dots/clicks work without it) | any recent |
| **jq** | classify Notification (permission → red) and background tasks | recommended |
| **mouse** | `set -g mouse on` — required for click-to-switch | — |

The status-bar dots use a plain Unicode `●`/`○`, so no special font is needed.
A **Nerd Font** is only used for the rounded window-number pills in the picker;
without one the pill caps render as boxes (cosmetic only).

---

## Install

### With [TPM](https://github.com/tmux-plugins/tpm)

```tmux
set -g @plugin 'YOUR_GH_USER/tmux-claude-dots'
```

Then `prefix + I` to fetch it. Pin a release with `...tmux-claude-dots#v0.1.0`.

If you use a status-line theme (e.g. Catppuccin), list this plugin **after** it
so the dots aren't overwritten when the theme sets `status-right`.

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

## States

Each pane moves through five states. Hooks drive every transition except the
final "seen" step, which the renderer does when you switch into a finished pane.

```
   ○ unknown            no hook has fired yet for this pane
        │
        │  any event
        ▼
   ● working  (blue)    Claude is busy — running, thinking, using tools
        │
        ├──▶ ● background (cyan)   turn ended but a background shell command is
        │        │                 still running; clears on its next turn
        │        └──── next turn ──▶ working / done as usual
        │
        ├──▶ ● waiting  (orange)   Claude needs you: a permission / approval prompt
        │        │
        │        └──── you approve, a tool runs ───▶ back to ● working
        │
        └──▶ ● done     (green)    turn finished — your turn to read / reply
                 │
                 ├──── you switch into the pane (you've seen it) ──▶ ● idle (gray)
                 │
                 └──── you send the next prompt ───────────────────▶ ● working

   ● idle (gray)        seen — nothing to do; next prompt sends it back to working

   SessionEnd ──▶ the pane's state file is removed ──▶ its dot disappears
```

| Hook event | Condition | State | Dot |
|------------|-----------|-------|-----|
| `UserPromptSubmit` / `PreToolUse` | — | working | 🔵 |
| `Notification` | message looks like permission/approve/allow/confirm | waiting | 🟠 |
| `Notification` | anything else (idle, etc.) | done | 🟢 |
| `Stop` | a background shell command is still running | background | 🩵 |
| `Stop` | no background tasks | done | 🟢 |
| *(renderer)* | a finished pane (done) becomes the active pane | idle | ⚪ |
| `SessionEnd` | — | removed | – |

> A finished turn stays **green** until you actually switch into the pane —
> green means "a session wants your eyes", gray means "seen, nothing to do".
> Claude only goes **orange** when it's genuinely blocked on you (a permission
> or approval prompt); a turn that ends with a prose question fires `Stop`, so
> it shows green like any other finished turn.

---

## Configuration

All options are global tmux user options — set them **before** the plugin loads.

| Option | Default | Description |
|--------|---------|-------------|
| `@claude_dots_key` | `G` | `prefix + <key>` to open the picker |
| `@claude_dots_glyph` | `●` | filled glyph for known states |
| `@claude_dots_glyph_unknown` | `○` | hollow glyph for panes with no event yet |
| `@claude_dots_glyph_active` | `⬤` | (larger) glyph for the pane you're currently in; also bold + underlined |
| `@claude_dots_separator` | `' '` | string between dots within a session |
| `@claude_dots_group_separator` | `│` | separator drawn between session groups |
| `@claude_dots_group_separator_color` | `colour240` | color of the group separator |
| `@claude_dots_command` | `claude` | extended-regex of `pane_current_command`(s) treated as a Claude session |
| `@claude_dots_color_working` | `blue` | busy |
| `@claude_dots_color_background` | `cyan` | turn ended, a background shell command is still running |
| `@claude_dots_color_waiting` | `colour208` | blocked on you (permission) — orange |
| `@claude_dots_color_done` | `green` | turn just finished |
| `@claude_dots_color_idle` | `colour245` | idle / awaiting next prompt — gray |
| `@claude_dots_color_unknown` | `colour240` | no event yet — gray hollow ○ |
| `@claude_dots_auto_status` | `on` | auto-prepend the renderer to `status-right`; set `off` to place it yourself |
| `@claude_dots_reserve` | `60` | extra `status-right-length` reserved for the dots so modules to their right aren't truncated (auto mode only) |
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
