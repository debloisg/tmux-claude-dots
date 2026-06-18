#!/usr/bin/env bash
# Shared helpers for tmux-claude-dots.
# Sourced by dots.sh, click.sh and picker.sh.

# cd_opt OPTION DEFAULT — read a global tmux user option, fall back to DEFAULT.
cd_opt() {
  local v
  v="$(tmux show-option -gqv "$1" 2>/dev/null)"
  if [ -n "$v" ]; then printf '%s' "$v"; else printf '%s' "$2"; fi
}

# cd_state_dir — directory where per-pane state files live. Must match the
# CLAUDE_DOTS_DIR used by hooks/claude-hook.sh.
cd_state_dir() {
  local d
  d="$(tmux show-option -gqv @claude_dots_dir 2>/dev/null)"
  [ -n "$d" ] || d="${TMPDIR:-/tmp}/claude-dots"
  printf '%s' "$d"
}

# cd_icon_ansi STATE — colored glyph for fzf rows (needs fzf --ansi).
cd_icon_ansi() {
  case "$1" in
    working) printf '\033[1;34m●\033[0m'    ;; # blue ●
    waiting) printf '\033[38;5;208m●\033[0m';; # orange ● (needs you)
    done)    printf '\033[1;32m●\033[0m'    ;; # green ● (finished)
    idle)    printf '\033[38;5;245m●\033[0m';; # gray ● (idle)
    *)       printf '\033[38;5;240m○\033[0m';; # gray ○ (unknown, hollow)
  esac
}

# cd_tab_pill NUMBER CURRENT — a rounded "tab number" pill for fzf rows, styled
# like the Catppuccin window tabs: dark digit (crust #11111b) on a colored pill
# (mauve #cba6f7 for the currently displayed window, overlay #9399b2 otherwise)
# with rounded Nerd Font powerline caps (U+E0B6 left, U+E0B4 right).
cd_tab_pill() {
  local num="$1" current="$2" rgb
  if [ "$current" = "1" ]; then rgb='203;166;247'; else rgb='147;153;178'; fi
  printf '\033[38;2;%sm\033[48;2;%sm\033[38;2;17;17;27m%s\033[0m\033[38;2;%sm\033[0m' \
    "$rgb" "$rgb" "$num" "$rgb"
}

# cd_match — name(s) of the agent command to detect, as an extended-regex
# anchored match against #{pane_current_command}. Override with
# @claude_dots_command (e.g. 'claude|node') if your sessions report differently.
cd_match() { cd_opt @claude_dots_command 'claude'; }

# cd_list_panes — emit a tab-separated record per *Claude pane*:
#   pane_id  session  window_index  window_name  command  cwd  active  inwin
# A pane counts as Claude if its current command matches cd_match OR it already
# has a state file (so a pane that backgrounded claude still shows).
#   active = 1  the focused pane of an attached session (what you're typing in)
#   inwin  = 1  any pane in the window currently displayed on an attached client
# Output is sorted by pane id for a stable left-to-right dot order.
cd_list_panes() {
  local tab=$'\t' state_dir re
  state_dir="$(cd_state_dir)"
  re="$(cd_match)"
  tmux list-panes -a -F \
    "#{pane_id}${tab}#{pane_current_command}${tab}#{session_name}${tab}#{window_index}${tab}#{window_name}${tab}#{pane_current_path}${tab}#{?#{&&:#{session_attached},#{&&:#{window_active},#{pane_active}}},1,0}${tab}#{?#{&&:#{session_attached},#{window_active}},1,0}" \
    2>/dev/null \
  | while IFS=$'\t' read -r pid cmd sess widx wname cwd active inwin; do
      [ -n "$pid" ] || continue
      if printf '%s' "$cmd" | grep -Eq "^(${re})$" || [ -f "$state_dir/${pid#%}" ]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$pid" "$sess" "$widx" "$wname" "$cmd" "$cwd" "$active" "$inwin"
      fi
    done \
  | sort -t"$tab" -k1,1
}

# cd_switch PANE_ID [CLIENT] — teleport CLIENT (or the current client) to the
# session/window/pane that owns PANE_ID. Passing the client is essential when
# called from inside a display-popup, which runs in its own popup client.
cd_switch() {
  local pid="$1" client="${2:-}" sess win
  sess="$(tmux display-message -t "$pid" -p '#{session_name}' 2>/dev/null)" || return 1
  [ -n "$sess" ] || return 1
  win="$(tmux display-message -t "$pid" -p '#{window_id}' 2>/dev/null)"
  if [ -n "$client" ]; then
    tmux switch-client -c "$client" -t "$sess"
  else
    tmux switch-client -t "$sess"
  fi
  [ -n "$win" ] && tmux select-window -t "$win"
  tmux select-pane -t "$pid"
}
