# Changelog

## [0.3.0] - 2026-03-04

### Added

- Comment on hunks with `c` — annotations are printed to stdout on quit as markdown

### Changed

- Removed initial-commit diff fallback from `Git.diff`

## [0.2.0] - 2026-03-04

### Changed

- Navigation is now hunk-based: `j`/`k` jump between hunks
- Active hunk is highlighted; inactive hunks are dimmed
- Removed line-scrolling keys (`f`/`b`/`d`/`u`/`g`/`G`) and arrow keys

## [0.1.0] - 2026-03-04

### Added

- Interactive curses-based TUI for browsing git diffs
- Color-coded add/delete/context lines with line-number gutter
- Vim-style keybindings for scrolling and navigation
- Per-file navigation with `n`/`p` keys
- Help overlay with `?`
- Fallback to `--cached` diff for initial commits
- CLI with `--help` and `--version` flags
