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
glyph_active="$(cd_opt @claude_dots_glyph_active '◉')"
sep="$(cd_opt @claude_dots_separator ' ')"
gsep="$(cd_opt @claude_dots_group_separator '│')"
gsep_col="$(cd_opt @claude_dots_group_separator_color 'colour240')"
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

# Read all Claude panes, then group dots by session with a separator between
# groups. (cd_list_panes is sorted by pane id, so panes stay ordered within a
# session; sessions appear in first-seen order.)
declare -a R_pid=() R_sess=() R_active=() R_inwin=()
while IFS=$'\t' read -r pid sess _widx _wname _cmd _cwd active inwin; do
  [ -n "$pid" ] || continue
  R_pid+=("$pid"); R_sess+=("$sess"); R_active+=("$active"); R_inwin+=("$inwin")
done < <(cd_list_panes)

n=${#R_pid[@]}
map="$state_dir/.map"
: > "$map"
[ "$n" -eq 0 ] && exit 0

# Sessions in first-seen order.
declare -a sorder=(); declare -A seen=()
for ((k = 0; k < n; k++)); do
  s="${R_sess[k]}"
  [ -n "${seen[$s]:-}" ] || { seen[$s]=1; sorder+=("$s"); }
done

out=""
i=0
first=1
for s in "${sorder[@]}"; do
  [ "$first" -eq 0 ] && out+=" #[fg=${gsep_col}]${gsep}#[default] "
  first=0
  for ((k = 0; k < n; k++)); do
    [ "${R_sess[k]}" = "$s" ] || continue
    pid="${R_pid[k]}"
    state="$(cat "$state_dir/${pid#%}" 2>/dev/null)"
    case "$state" in
      working)   col="$c_work" ;;
      waiting)   col="$c_wait" ;;
      idle|done) col="$c_idle" ;;
      *)         col="$c_unk"  ;;   # detected pane, no hook event yet
    esac
    # Emphasis: the pane you're typing in gets a distinct glyph + bold; other
    # panes in that same on-screen window get an underline; rest plain.
    if [ "${R_active[k]}" = "1" ]; then
      g="$glyph_active"; emph="bold,"
    elif [ "${R_inwin[k]}" = "1" ]; then
      g="$glyph"; emph="underscore,"
    else
      g="$glyph"; emph=""
    fi
    printf '%s\t%s\n' "$i" "$pid" >> "$map"   # index -> pane id, used by click.sh
    out+="#[range=user|cd${i} ${emph}fg=${col}]${g}#[norange default]${sep}"
    i=$((i + 1))
  done
done

printf '%s' "$out"
