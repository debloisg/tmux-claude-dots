#!/usr/bin/env bash
# tmux-claude-dots — entry point (TPM runs this on load).
# Binds the picker key + the clickable status dots, and (optionally) injects the
# dot renderer into status-right.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$DIR/scripts"

opt() {
  local v
  v="$(tmux show-option -gqv "$1" 2>/dev/null)"
  if [ -n "$v" ]; then printf '%s' "$v"; else printf '%s' "$2"; fi
}

key="$(opt @claude_dots_key 'G')"
auto="$(opt @claude_dots_auto_status 'on')"
popup_w="$(opt @claude_dots_popup_width '80%')"
popup_h="$(opt @claude_dots_popup_height '70%')"

# Picker popup (prefix + <key>).
tmux bind-key "$key" display-popup -E -w "$popup_w" -h "$popup_h" \
  "$SCRIPTS/picker.sh '#{client_name}'"

# Clickable dots: a click on one of our "cd*" ranges teleports there; any other
# status click falls back to the default window selection so we don't hijack it.
tmux bind-key -n MouseDown1Status if-shell -F '#{m:cd*,#{mouse_status_range}}' \
  "run-shell \"$SCRIPTS/click.sh '#{mouse_status_range}' '#{client_name}'\"" \
  "select-window -t ="

# Inject the renderer at the head of status-right unless disabled. Idempotent.
if [ "$auto" = "on" ]; then
  cur="$(tmux show-option -gqv status-right)"
  case "$cur" in
    *"$SCRIPTS/dots.sh"*) : ;;
    *) tmux set-option -g status-right "#($SCRIPTS/dots.sh)$cur" ;;
  esac
fi
