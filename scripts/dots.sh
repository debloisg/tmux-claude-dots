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
while IFS= read -r pid || [ -n "$pid" ]; do
  [ -n "$pid" ] && live["${pid#%}"]=1
done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)
for f in "$state_dir"/*; do
  [ -f "$f" ] || continue
  base="${f##*/}"
  [ "$base" = ".map" ] && continue
  [ -z "${live[$base]:-}" ] && rm -f "$f"
done

# Read all Claude panes, then group dots by session with a separator between
# groups. (cd_list_panes is sorted by session name, so sessions appear in the
# same alphabetical order as tmux's session switcher.)
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

# Spacing is uniform: dots within a group are joined by $sep, and groups by
# $sep + bar + $sep, so every gap is exactly one separator wide. No trailing
# separator is appended.
out=""
i=0
gfirst=1
for s in "${sorder[@]}"; do
  [ "$gfirst" -eq 0 ] && out+="${sep}#[fg=${gsep_col}]${gsep}#[default]${sep}"
  gfirst=0
  dfirst=1
  for ((k = 0; k < n; k++)); do
    [ "${R_sess[k]}" = "$s" ] || continue
    [ "$dfirst" -eq 0 ] && out+="$sep"
    dfirst=0
    pid="${R_pid[k]}"
    state="$(cd_read "$state_dir/${pid#%}")"
    # Acknowledge: a finished (green) session you've now switched into has been
    # seen, so drop it to idle (gray). This fires the moment the pane is the
    # active one — switching panes/windows repaints the bar — and persists, so
    # it greys out once and stays grey until its next turn.
    if [ "${R_active[k]}" = "1" ] && [ "$state" = "done" ]; then
      state="idle"
      printf 'idle' > "$state_dir/${pid#%}"
    fi
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
    out+="#[range=user|cd${i}]#[${emph}fg=${col}]${g}#[default]#[norange]"
    i=$((i + 1))
  done
done

# Trailing separator so the last dot keeps an even gap from whatever module
# follows in status-right (e.g. a theme's session capsule).
printf '%s%s' "$out" "$sep"
