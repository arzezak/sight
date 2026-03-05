# Sight

TUI for closing the loop on AI-generated code changes.

## Installation

```bash
gem install sight
```

## Usage

Stage some changes (or have unstaged changes), then run:

```bash
sight
```

### Keybindings

| Key | Action |
|-----|--------|
| `j` | Next hunk |
| `k` | Previous hunk |
| `n` | Next file |
| `p` | Previous file |
| `Ctrl-F` / `Ctrl-B` | Scroll full page down / up |
| `Ctrl-D` / `Ctrl-U` | Scroll half page down / up |
| `?` | Toggle help |
| `c` | Comment on hunk |
| `q` / `Esc` | Quit |

### Agent Integration

Install a hook so annotations are automatically fed as context in your next message:

```bash
sight install-hook claude   # Claude Code (~/.config/claude/settings.json)
sight install-hook cursor   # Cursor (~/.cursor/hooks.json)
```

When you quit sight after annotating, the next message you send will include your annotations.

To remove:

```bash
sight uninstall-hook claude
sight uninstall-hook cursor
```

## Development

```bash
bin/setup
rake test
bundle exec standardrb
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/arzezak/sight. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/arzezak/sight/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Sight project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/arzezak/sight/blob/main/CODE_OF_CONDUCT.md).
