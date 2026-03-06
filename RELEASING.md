# Releasing

1. Update `lib/sight/version.rb` and `CHANGELOG.md`
2. Run `bundle install` to update `Gemfile.lock`
3. Run `bundle exec rake` to verify tests and lint pass
4. Commit: `git commit -am "Release vX.Y.Z"`
5. Run `bundle exec rake release` — tags, builds, and pushes to RubyGems
