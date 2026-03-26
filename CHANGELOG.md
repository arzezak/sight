# Changelog

## [0.6.0] - 2026-03-26

### Changed

- Show annotation summary instead of full dump on quit
- Extracted `Summary` class from `AnnotationFormatter`
- Converted `AnnotationFormatter` from module to class

## [0.5.0] - 2026-03-07

### Removed

- Cursor hook support (use Cursor rules instead)

### Changed

- Refactored CLI dispatch to use case statement with extracted `open` and `print_help` methods
- DRYed up install/uninstall hook agent lookup
- Use `Set` for commented hunk lines lookup
- Extracted `hunk_end_offset` to deduplicate boundary logic
- Use `<<` for string building in `AnnotationFormatter`
- Simplified prompt comment width clamping

## [0.4.0] - 2026-03-06

### Added

- Untracked file support with file status badges (new, modified, deleted)
- Color-coded status badges in file header
- Ctrl-f/b/d/u scroll navigation
- Scroll percentage indicator replacing line counter
- Hook system for AI agent integration (`sight install-hook <agent>`)
  - Claude Code hook via `UserPromptSubmit`
  - Cursor hook via `beforeSubmitPrompt`
- Highlighted commented hunks in gutter and status bar

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
