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
| `?` | Toggle help |
| `q` / `Esc` | Quit |

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
