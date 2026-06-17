#!/usr/bin/env bash
# MouseDown1Status handler. Receives the clicked range tag and the client name.
# A tag of the form "cdN" maps (via the .map file written by dots.sh) back to a
# pane id; we then teleport the real client there. Non-"cd" ranges never reach
# here — the tmux binding routes those to the default `select-window -t =`.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

range="${1:-}"
client="${2:-}"

case "$range" in
  cd*) idx="${range#cd}" ;;
  *)   exit 0 ;;
esac

map="$(cd_state_dir)/.map"
[ -f "$map" ] || exit 0

pid="$(awk -v i="$idx" '$1 == i { print $2; exit }' "$map")"
[ -n "$pid" ] && cd_switch "$pid" "$client"
