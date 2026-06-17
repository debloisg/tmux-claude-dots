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

# Reap state files for panes that no longer exist (crash without SessionEnd).
declare -A live=()
while IFS= read -r pid; do
  [ -n "$pid" ] && live["${pid#%}"]=1
done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)
for f in "$state_dir"/*; do
  [ -f "$f" ] || continue
  base="${f##*/}"
  [ "$base" = ".map" ] && continue
  [ -z "${live[$base]:-}" ] && rm -f "$f"
done

# One dot per live Claude pane (whether or not it has reported state yet).
map="$state_dir/.map"
: > "$map"
out=""
i=0
while IFS=$'\t' read -r pid _sess _widx _wname _cmd _cwd; do
  [ -n "$pid" ] || continue
  state="$(cat "$state_dir/${pid#%}" 2>/dev/null)"
  case "$state" in
    working)   col="$c_work" ;;
    waiting)   col="$c_wait" ;;
    idle|done) col="$c_idle" ;;
    *)         col="$c_unk"  ;;   # detected pane, no hook event yet
  esac
  # index -> pane id, consumed by click.sh on MouseDown1Status
  printf '%s\t%s\n' "$i" "$pid" >> "$map"
  out+="#[range=user|cd${i} fg=${col}]${glyph}#[norange default]${sep}"
  i=$((i + 1))
done < <(cd_list_panes)

printf '%s' "$out"
