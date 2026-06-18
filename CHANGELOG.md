# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project aims to
follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Status-line dots: one per live Claude Code pane, colored by state.
- Click a dot (`MouseDown1Status`) to switch to that pane.
- `prefix + G` fzf picker: a per-session tree, panes named by cwd, with a live
  pane preview, a state-color legend, Catppuccin-style window-number pills, and
  `ctrl-x` (kill) / `ctrl-r` (refresh) bindings.
- Active pane shown as a larger, bold, underlined glyph; other panes in the
  on-screen window are underlined.
- Dots grouped per session with a configurable separator.
- Event-driven refresh via `tmux refresh-client -S` from the Claude hook — no
  polling daemon.
- Configurable glyphs, colors, picker key, popup size, and command matcher.

### Changed
- Dots are ordered by session name (matching tmux's alphabetical session
  switcher), then by window index and on-screen pane position within a session
  (window 1's left pane, its right pane, window 2, ...), instead of pane launch
  order.
- A finished turn stays **green** until you switch into the pane, then greys to
  idle ("seen") — instead of dropping to gray as soon as Claude went idle.
- Separator spacing is uniform; the dot strip keeps an even gap from the next
  status-right module.

- New `background` state (cyan): a turn that ends while a background shell
  command is still running, distinct from busy (blue) and idle (gray).
  Configurable via `@claude_dots_color_background`.

### Fixed
- Auto mode now reserves extra `status-right-length` (configurable via
  `@claude_dots_reserve`) so the dots don't push the theme's right-hand modules
  off the screen. Idempotent — the original length is remembered.

[Unreleased]: https://github.com/YOUR_GH_USER/tmux-claude-dots
