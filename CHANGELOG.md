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

[Unreleased]: https://github.com/YOUR_GH_USER/tmux-claude-dots
