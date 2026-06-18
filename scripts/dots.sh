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
glyph_unknown="$(cd_opt @claude_dots_glyph_unknown '○')"
glyph_active="$(cd_opt @claude_dots_glyph_active '⬤')"
sep="$(cd_opt @claude_dots_separator ' ')"
gsep="$(cd_opt @claude_dots_group_separator '│')"
gsep_col="$(cd_opt @claude_dots_group_separator_color 'colour240')"
c_work="$(cd_opt @claude_dots_color_working 'blue')"
c_wait="$(cd_opt @claude_dots_color_waiting 'colour208')"
c_done="$(cd_opt @claude_dots_color_done 'green')"
c_idle="$(cd_opt @claude_dots_color_idle 'colour245')"
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
    # Unknown panes (no hook event yet) use a hollow circle; known states fill.
    case "$state" in
      working) col="$c_work"; base="$glyph" ;;
      waiting) col="$c_wait"; base="$glyph" ;;
      done)    col="$c_done"; base="$glyph" ;;
      idle)    col="$c_idle"; base="$glyph" ;;
      *)       col="$c_unk";  base="$glyph_unknown" ;;
    esac
    # Emphasis: the pane you're typing in gets a larger glyph + bold/underline;
    # other panes in that same on-screen window get an underline; rest plain.
    if [ "${R_active[k]}" = "1" ]; then
      g="$glyph_active"; emph="bold,underscore,"
    elif [ "${R_inwin[k]}" = "1" ]; then
      g="$base"; emph="underscore,"
    else
      g="$base"; emph=""
    fi
    printf '%s\t%s\n' "$i" "$pid" >> "$map"   # index -> pane id, used by click.sh
    # range and color in SEPARATE blocks so the fg always wins over the theme's
    # default status style (Catppuccin resets color if they share one #[...]).
    out+="#[range=user|cd${i}]#[${emph}fg=${col}]${g}#[default]#[norange]${sep}"
    i=$((i + 1))
  done
done

printf '%s' "$out"
