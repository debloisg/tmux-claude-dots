#!/usr/bin/env bash
# fzf picker over all live Claude Code panes. Each row shows session ▸ window ▸
# command ▸ cwd with a colored state dot, previews the live pane, and on Enter
# teleports the client there. Meant to be launched in a tmux display-popup.
#
#   picker.sh <client_name>     interactive picker (Enter switches)
#   picker.sh --rows            print rows only (used by fzf reload binds)
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

state_dir="$(cd_state_dir)"

# State priority for the aggregate icon on a session line (most urgent wins).
cd_prio() {
  case "$1" in waiting) echo 4 ;; working) echo 3 ;; done) echo 2 ;; idle) echo 1 ;; *) echo 0 ;; esac
}

# Tree: each session is a parent line; its Claude panes nest underneath, named
# by their working directory. Field 1 (hidden, before the tab) is the pane id
# target; a session line targets its first pane.
emit_rows() {
  local pid sess cwd active st
  local -a R_pid=() R_sess=() R_cwd=() R_state=() R_active=()
  while IFS=$'\t' read -r pid sess _widx _wname _cmd cwd active _inwin; do
    [ -n "$pid" ] || continue
    st="$(cat "$state_dir/${pid#%}" 2>/dev/null)"
    R_pid+=("$pid"); R_sess+=("$sess"); R_cwd+=("$cwd"); R_state+=("$st"); R_active+=("$active")
  done < <(cd_list_panes)

  local n=${#R_pid[@]}
  [ "$n" -eq 0 ] && return 0

  # Unique sessions, first-seen order.
  local -a sorder=(); local -A seen=(); local i s
  for ((i = 0; i < n; i++)); do
    s="${R_sess[i]}"
    [ -n "${seen[$s]:-}" ] || { seen[$s]=1; sorder+=("$s"); }
  done

  local j p agg aggp sicon picon label mark c last m
  for s in "${sorder[@]}"; do
    local -a idx=()
    for ((i = 0; i < n; i++)); do [ "${R_sess[i]}" = "$s" ] && idx+=("$i"); done

    # Aggregate (most urgent) state for the session line.
    agg=""; aggp=-1
    for j in "${idx[@]}"; do
      p=$(cd_prio "${R_state[j]}")
      [ "$p" -gt "$aggp" ] && { aggp=$p; agg="${R_state[j]}"; }
    done
    sicon="$(cd_icon_ansi "$agg")"
    printf '%s\t%b \033[1m%s\033[0m \033[90m(%d)\033[0m\n' \
      "${R_pid[${idx[0]}]}" "$sicon" "$s" "${#idx[@]}"

    # Pane children, named by cwd.
    last=$(( ${#idx[@]} - 1 )); m=0
    for j in "${idx[@]}"; do
      if [ "$m" -eq "$last" ]; then c="└─"; else c="├─"; fi
      picon="$(cd_icon_ansi "${R_state[j]}")"
      # Name the instance by the current dir and its parent only.
      full="${R_cwd[j]}"
      base="${full##*/}"
      parent="${full%/*}"; parent="${parent##*/}"
      if [ -n "$base" ]; then label="${parent:+$parent/}$base"; else label="$full"; fi
      mark=""; [ "${R_active[j]}" = "1" ] && mark=$'  \033[1;36m←\033[0m'
      printf '%s\t  \033[90m%s\033[0m %b %s%b\n' "${R_pid[j]}" "$c" "$picon" "$label" "$mark"
      m=$(( m + 1 ))
    done
  done
}

# Row-only mode for fzf reload() bindings.
if [ "${1:-}" = "--rows" ]; then
  emit_rows
  exit 0
fi

client="${1:-}"

if ! command -v fzf >/dev/null 2>&1; then
  tmux display-message "claude-dots: fzf is not installed"
  exit 0
fi

rows="$(emit_rows)"
if [ -z "$rows" ]; then
  tmux display-message "claude-dots: no Claude Code sessions"
  exit 0
fi

reload="bash $DIR/picker.sh --rows"

# Legend of state colors + key hints, shown above the list.
legend="$(printf '%b working  %b finished  %b needs you  %b idle  %b unknown' \
  "$(cd_icon_ansi working)" "$(cd_icon_ansi done)" "$(cd_icon_ansi waiting)" \
  "$(cd_icon_ansi idle)" "$(cd_icon_ansi unknown)")"
keys=$'\033[90menter: switch   ctrl-x: kill   ctrl-r: refresh\033[0m'

sel="$(printf '%s\n' "$rows" | fzf \
  --ansi \
  --delimiter=$'\t' \
  --with-nth=2.. \
  --no-sort \
  --layout=reverse \
  --info=hidden \
  --no-separator \
  --prompt='claude ❯ ' \
  --header="${legend}"$'\n'"${keys}" \
  --header-first \
  --preview 'tmux capture-pane -ep -S -200 -t {1}' \
  --preview-window 'right:55%:wrap' \
  --bind "ctrl-x:execute-silent(tmux kill-pane -t {1})+reload($reload)" \
  --bind "ctrl-r:reload($reload)")" || exit 0

pid="${sel%%$'\t'*}"
[ -n "$pid" ] && cd_switch "$pid" "$client"
