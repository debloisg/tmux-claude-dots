#!/usr/bin/env bash
# Claude Code hook for tmux-claude-dots.
# Records the calling pane's agent state to a file keyed by $TMUX_PANE, then
# nudges tmux to repaint the status line immediately (event-driven, no poll).
#
# Wire it up in ~/.claude/settings.json — one entry per event, passing the
# event name as the argument, e.g.:
#   "command": "~/.../tmux-claude-dots/hooks/claude-hook.sh UserPromptSubmit"
#
# States: working (busy) · waiting (needs you) · idle (turn finished).
set -u

event="${1:-}"
pane="${TMUX_PANE:-}"
[ -z "$pane" ] && exit 0   # only meaningful inside tmux

dir="${CLAUDE_DOTS_DIR:-${TMPDIR:-/tmp}/claude-dots}"
mkdir -p "$dir" 2>/dev/null
f="$dir/${pane#%}"

case "$event" in
  UserPromptSubmit|PreToolUse)
    printf 'working' > "$f"
    ;;
  Notification)
    printf 'waiting' > "$f"
    ;;
  Stop)
    # A turn that ends with background tasks still running isn't really idle.
    if command -v jq >/dev/null 2>&1; then
      n="$(jq '((.background_tasks // []) | length)' 2>/dev/null)"
      case "${n:-0}" in
        ''|0) printf 'idle'    > "$f" ;;
        *)    printf 'working' > "$f" ;;
      esac
    else
      printf 'idle' > "$f"
    fi
    ;;
  SessionEnd)
    rm -f "$f"
    ;;
  *)
    : ;;
esac

# Repaint every client's status line right now.
tmux refresh-client -S 2>/dev/null
exit 0
