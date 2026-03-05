# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "json"

class TestCursorHookInstaller < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @hooks_path = File.join(@tmpdir, "hooks.json")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_install_creates_hooks_from_scratch
    out, = capture_io { Sight::CursorHookInstaller.install(path: @hooks_path) }

    assert_includes out, "Installed"
    config = JSON.parse(File.read(@hooks_path))
    assert_equal 1, config["version"]
    hooks = config.dig("hooks", "beforeSubmitPrompt")
    assert_equal 1, hooks.size
    assert_equal "sight cursor-hook-run", hooks[0]["command"]
  end

  def test_install_preserves_existing_hooks
    existing = {
      "version" => 1,
      "hooks" => {
        "afterFileEdit" => [{"command" => "./format.sh"}],
        "beforeSubmitPrompt" => [{"command" => "./audit.sh"}]
      }
    }
    File.write(@hooks_path, JSON.generate(existing))

    capture_io { Sight::CursorHookInstaller.install(path: @hooks_path) }

    config = JSON.parse(File.read(@hooks_path))
    assert_equal 1, config["hooks"]["afterFileEdit"].size
    assert_equal 2, config["hooks"]["beforeSubmitPrompt"].size
    assert_equal "./audit.sh", config["hooks"]["beforeSubmitPrompt"][0]["command"]
  end

  def test_install_is_idempotent
    capture_io { Sight::CursorHookInstaller.install(path: @hooks_path) }
    out, = capture_io { Sight::CursorHookInstaller.install(path: @hooks_path) }

    assert_includes out, "already installed"
    config = JSON.parse(File.read(@hooks_path))
    assert_equal 1, config["hooks"]["beforeSubmitPrompt"].size
  end

  def test_uninstall_removes_sight_hook
    capture_io { Sight::CursorHookInstaller.install(path: @hooks_path) }
    out, = capture_io { Sight::CursorHookInstaller.uninstall(path: @hooks_path) }

    assert_includes out, "Uninstalled"
    config = JSON.parse(File.read(@hooks_path))
    assert_empty config["hooks"]["beforeSubmitPrompt"]
  end

  def test_uninstall_preserves_other_hooks
    existing = {
      "version" => 1,
      "hooks" => {
        "beforeSubmitPrompt" => [
          {"command" => "./audit.sh"},
          {"command" => "sight cursor-hook-run"}
        ]
      }
    }
    File.write(@hooks_path, JSON.generate(existing))

    capture_io { Sight::CursorHookInstaller.uninstall(path: @hooks_path) }

    config = JSON.parse(File.read(@hooks_path))
    assert_equal 1, config["hooks"]["beforeSubmitPrompt"].size
    assert_equal "./audit.sh", config["hooks"]["beforeSubmitPrompt"][0]["command"]
  end

  def test_uninstall_no_hooks_file
    out, = capture_io { Sight::CursorHookInstaller.uninstall(path: @hooks_path) }
    assert_includes out, "No hooks file"
  end

  def test_uninstall_no_sight_hook
    File.write(@hooks_path, JSON.generate({"version" => 1, "hooks" => {"beforeSubmitPrompt" => []}}))
    out, = capture_io { Sight::CursorHookInstaller.uninstall(path: @hooks_path) }
    assert_includes out, "No sight hook"
  end
end
