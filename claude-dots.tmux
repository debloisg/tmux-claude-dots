#!/usr/bin/env bash
# tmux-claude-dots — TPM entry point (run once per config load).
# Keep this thin: register the key binding, the clickable-dot mouse binding,
# and (optionally) the status-line renderer. All real work lives in scripts/.
set -u

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$CURRENT_DIR/scripts"
# shellcheck source=scripts/lib.sh
. "$SCRIPTS/lib.sh"

main() {
  local key auto popup_w popup_h cur frag
  key="$(cd_opt @claude_dots_key 'G')"
  auto="$(cd_opt @claude_dots_auto_status 'on')"
  popup_w="$(cd_opt @claude_dots_popup_width '80%')"
  popup_h="$(cd_opt @claude_dots_popup_height '70%')"

  # Picker popup on prefix + <key>. Re-binding is idempotent (bind-key replaces).
  tmux bind-key "$key" display-popup -E -w "$popup_w" -h "$popup_h" \
    "$SCRIPTS/picker.sh '#{client_name}'"

  # Clickable dots: a click on one of our "cd*" ranges teleports there; any
  # other status click falls back to the default window selection so we don't
  # hijack normal clicks on the window list.
  tmux bind-key -n MouseDown1Status if-shell -F '#{m:cd*,#{mouse_status_range}}' \
    "run-shell \"$SCRIPTS/click.sh '#{mouse_status_range}' '#{client_name}'\"" \
    "select-window -t ="

  # Prepend the renderer to status-right unless disabled. Guarded so reloads
  # don't stack duplicates; we never touch status-interval (a user preference).
  if [ "$auto" = "on" ]; then
    frag="#($SCRIPTS/dots.sh)"
    cur="$(tmux show-option -gqv status-right)"
    case "$cur" in
      *"$frag"*) : ;;
      *) tmux set-option -g status-right "$frag$cur" ;;
    esac

    # status-right has a character budget (status-right-length). Our dots eat
    # into it, so the modules to our right (e.g. a theme's session capsule) get
    # truncated off the edge if the budget is tight. Reserve extra room once.
    # Idempotent: remember the original length in a user option and only ever
    # extend from that base, so reloads don't keep growing it.
    local reserve base
    reserve="$(cd_opt @claude_dots_reserve '60')"
    base="$(tmux show-option -gqv @claude_dots_srl_base)"
    if [ -z "$base" ]; then
      base="$(tmux show-option -gqv status-right-length)"
      [ -n "$base" ] || base=40
      tmux set-option -g @claude_dots_srl_base "$base"
      tmux set-option -g status-right-length "$((base + reserve))"
    fi
  fi
}

main
