# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- `bundle exec rake test` — run all tests
- `ruby -Ilib:test test/test_cli.rb` — run a single test file
- `ruby -Ilib:test test/test_cli.rb -n test_help_flag` — run a single test method
- `bundle exec standardrb` — lint
- `bundle exec standardrb --fix` — lint and auto-fix
- `bundle exec rake` — run tests + lint (default task)

## Architecture

TUI for closing the loop on AI-generated code changes — browse diffs, jump between hunks, and annotate them. Entry point: `exe/sight` → `CLI.run` → `App.new(files).run`.

**Data flow**: `Git.diff` (raw string) → `DiffParser.parse` (returns `DiffFile[]`) → `App` (curses TUI).
Untracked files are added via `Git.untracked_files` → `DiffParser.build_untracked`.

**Key structs** (all in `diff_parser.rb`): `DiffFile(path, hunks, status)`, `Hunk(context, lines)`, `DiffLine(type, content, lineno, old_lineno)`.
`DisplayLine(type, text, lineno)` is the render-side equivalent in `display_line.rb`.
`Annotation(file_path, type, hunk, comment)` in `annotation.rb` stores per-hunk comments; `AnnotationFormatter` serializes them for output.

**App** renders per-file views with hunk-based navigation (j/k). Active hunk is highlighted; inactive hunks render in dark gray (color pair 5, color 240).

**Hook system**: `HookInstaller` manages a Claude Code `UserPromptSubmit` hook in `~/.config/claude/settings.json`.
The hook runs `sight hook-run`, which reads `.git/sight/pending-review`, prints annotations to stdout (injected as context), and deletes the file.
CLI subcommands: `install-hook`, `uninstall-hook`, `hook-run` (hidden).
`CursorHookInstaller` manages a Cursor `beforeSubmitPrompt` hook in `~/.cursor/hooks.json`.
The hook runs `sight cursor-hook-run`, which reads the same pending-review file but returns JSON `{ "user_message": "..." }` as Cursor expects.
CLI subcommands: `install-cursor-hook`, `uninstall-cursor-hook`, `cursor-hook-run` (hidden).

## Conventions

- Ruby >= 3.2, uses `frozen_string_literal` in all files
- Linter: StandardRB (ruby_version: 3.4 in `.standard.yml`)
- Tests: Minitest with stubs/mocks, no test framework beyond minitest
- Single runtime dependency: `curses ~1.4`
