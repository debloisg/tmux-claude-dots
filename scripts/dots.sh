#!/usr/bin/env bash
# Render one clickable colored glyph per live Claude Code pane.
# Invoked from the tmux status line via #(...). Stateless: it reads per-pane
# state files written by hooks/claude-hook.sh. No background daemon — hooks
# call `tmux refresh-client -S` to repaint the bar the instant state changes.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

state_dir="$(cd_state_dir)"
[ -d "$state_dir" ] || exit 0

glyph="$(cd_opt @claude_dots_glyph '●')"
sep="$(cd_opt @claude_dots_separator ' ')"
c_work="$(cd_opt @claude_dots_color_working 'yellow')"
c_wait="$(cd_opt @claude_dots_color_waiting 'red')"
c_idle="$(cd_opt @claude_dots_color_idle 'green')"
c_unk="$(cd_opt  @claude_dots_color_unknown 'colour240')"

# Map of live panes: key (pane id without leading %) -> full pane id.
declare -A live=()
while IFS= read -r pid; do
  [ -n "$pid" ] && live["${pid#%}"]="$pid"
done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)

map="$state_dir/.map"
: > "$map"

out=""
i=0
for f in "$state_dir"/*; do
  [ -f "$f" ] || continue          # no matches -> the literal glob, skipped
  base="${f##*/}"
  # Reap state files whose pane is gone (covers crashes that skip SessionEnd).
  if [ -z "${live[$base]:-}" ]; then rm -f "$f"; continue; fi
  state="$(cat "$f" 2>/dev/null)"
  case "$state" in
    working)   col="$c_work" ;;
    waiting)   col="$c_wait" ;;
    idle|done) col="$c_idle" ;;
    *)         col="$c_unk"  ;;
  esac
  # index -> pane id, consumed by click.sh on MouseDown1Status
  printf '%s\t%s\n' "$i" "${live[$base]}" >> "$map"
  out+="#[range=user|cd${i} fg=${col}]${glyph}#[norange default]${sep}"
  i=$((i + 1))
done

printf '%s' "$out"
