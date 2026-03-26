# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "json"

class TestClaudeHookInstaller < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @settings_path = File.join(@tmpdir, "settings.json")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_install_creates_settings_from_scratch
    out, = capture_io { Sight::ClaudeHookInstaller.install(path: @settings_path) }

    assert_includes out, "Installed"
    settings = JSON.parse(File.read(@settings_path))
    hooks = settings.dig("hooks", "UserPromptSubmit")
    assert_equal 1, hooks.size
    assert_equal "sight hook-run", hooks[0].dig("hooks", 0, "command")
  end

  def test_install_preserves_existing_hooks
    existing = {
      "hooks" => {
        "Notification" => [{"matcher" => "*", "hooks" => [{"type" => "command", "command" => "notify-send"}]}],
        "UserPromptSubmit" => [{"matcher" => "*.rb", "hooks" => [{"type" => "command", "command" => "rubocop"}]}]
      }
    }
    File.write(@settings_path, JSON.generate(existing))

    capture_io { Sight::ClaudeHookInstaller.install(path: @settings_path) }

    settings = JSON.parse(File.read(@settings_path))
    assert_equal 1, settings["hooks"]["Notification"].size
    assert_equal 2, settings["hooks"]["UserPromptSubmit"].size
    assert_equal "rubocop", settings["hooks"]["UserPromptSubmit"][0].dig("hooks", 0, "command")
  end

  def test_install_is_idempotent
    capture_io { Sight::ClaudeHookInstaller.install(path: @settings_path) }
    out, = capture_io { Sight::ClaudeHookInstaller.install(path: @settings_path) }

    assert_includes out, "already installed"
    settings = JSON.parse(File.read(@settings_path))
    assert_equal 1, settings["hooks"]["UserPromptSubmit"].size
  end

  def test_uninstall_removes_sight_hook
    capture_io { Sight::ClaudeHookInstaller.install(path: @settings_path) }
    out, = capture_io { Sight::ClaudeHookInstaller.uninstall(path: @settings_path) }

    assert_includes out, "Uninstalled"
    settings = JSON.parse(File.read(@settings_path))
    assert_empty settings["hooks"]["UserPromptSubmit"]
  end

  def test_uninstall_preserves_other_hooks
    existing = {
      "hooks" => {
        "UserPromptSubmit" => [
          {"matcher" => "*.rb", "hooks" => [{"type" => "command", "command" => "rubocop"}]},
          {"matcher" => "*", "hooks" => [{"type" => "command", "command" => "sight hook-run"}]}
        ]
      }
    }
    File.write(@settings_path, JSON.generate(existing))

    capture_io { Sight::ClaudeHookInstaller.uninstall(path: @settings_path) }

    settings = JSON.parse(File.read(@settings_path))
    assert_equal 1, settings["hooks"]["UserPromptSubmit"].size
    assert_equal "rubocop", settings["hooks"]["UserPromptSubmit"][0].dig("hooks", 0, "command")
  end

  def test_uninstall_no_settings_file
    out, = capture_io { Sight::ClaudeHookInstaller.uninstall(path: @settings_path) }
    assert_includes out, "No settings file"
  end

  def test_uninstall_no_sight_hook
    File.write(@settings_path, JSON.generate({"hooks" => {"UserPromptSubmit" => []}}))
    out, = capture_io { Sight::ClaudeHookInstaller.uninstall(path: @settings_path) }
    assert_includes out, "No sight hook"
  end

  def test_settings_path_prefers_dot_claude
    dot_claude = File.join(@tmpdir, ".claude", "settings.json")
    FileUtils.mkdir_p(File.dirname(dot_claude))
    File.write(dot_claude, "{}")

    Dir.stub(:home, @tmpdir) do
      path = Sight::ClaudeHookInstaller.settings_path

      assert_equal dot_claude, path
    end
  end

  def test_settings_path_prefers_xdg_config_home
    xdg_path = File.join(@tmpdir, "xdg", "claude", "settings.json")
    FileUtils.mkdir_p(File.dirname(xdg_path))
    File.write(xdg_path, "{}")

    dot_claude = File.join(@tmpdir, ".claude", "settings.json")
    FileUtils.mkdir_p(File.dirname(dot_claude))
    File.write(dot_claude, "{}")

    Dir.stub(:home, @tmpdir) do
      ENV.stub(:[], -> { (it == "XDG_CONFIG_HOME") ? File.join(@tmpdir, "xdg") : nil }) do
        path = Sight::ClaudeHookInstaller.settings_path

        assert_equal xdg_path, path
      end
    end
  end

  def test_settings_path_falls_back_to_dot_config
    Dir.stub(:home, @tmpdir) do
      path = Sight::ClaudeHookInstaller.settings_path

      assert_equal File.join(@tmpdir, ".config", "claude", "settings.json"), path
    end
  end
end
