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

emit_rows() {
  local tab=$'\t'
  local pid sess widx wname cmd cwd key st icon
  while IFS=$'\t' read -r pid sess widx wname cmd cwd; do
    key="${pid#%}"
    [ -f "$state_dir/$key" ] || continue          # only Claude panes
    read -r st < "$state_dir/$key" 2>/dev/null || st=""
    icon="$(cd_icon_ansi "$st")"
    # Field 1 (hidden) = pane id target. Display starts at field 2.
    printf '%s\t%b  \033[1m%s\033[0m \033[90m▸\033[0m %s \033[90m▸\033[0m %s  \033[90m%s\033[0m\n' \
      "$pid" "$icon" "$sess" "$wname" "$cmd" "${cwd/#$HOME/\~}"
  done < <(tmux list-panes -a -F \
    "#{pane_id}${tab}#{session_name}${tab}#{window_index}${tab}#{window_name}${tab}#{pane_current_command}${tab}#{pane_current_path}" 2>/dev/null)
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

sel="$(printf '%s\n' "$rows" | fzf \
  --ansi \
  --delimiter=$'\t' \
  --with-nth=2.. \
  --no-sort \
  --layout=reverse \
  --info=hidden \
  --no-separator \
  --prompt='claude ❯ ' \
  --header='enter: switch   ctrl-x: kill pane   ctrl-r: refresh' \
  --header-first \
  --preview 'tmux capture-pane -ep -S -200 -t {1}' \
  --preview-window 'right:55%:wrap' \
  --bind "ctrl-x:execute-silent(tmux kill-pane -t {1})+reload($reload)" \
  --bind "ctrl-r:reload($reload)")" || exit 0

pid="${sel%%$'\t'*}"
[ -n "$pid" ] && cd_switch "$pid" "$client"
