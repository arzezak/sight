# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class TestCLI < Minitest::Test
  def test_help_flag
    output, = capture_io { Sight::CLI.run(["--help"]) }

    assert_includes output, "Usage: sight"
    assert_includes output, "hunks"
  end

  def test_help_short_flag
    output, = capture_io { Sight::CLI.run(["-h"]) }

    assert_includes output, "Usage: sight"
  end

  def test_version_flag
    output, = capture_io { Sight::CLI.run(["--version"]) }

    assert_includes output, Sight::VERSION
  end

  def test_version_short_flag
    output, = capture_io { Sight::CLI.run(["-v"]) }

    assert_includes output, Sight::VERSION
  end

  def test_help_includes_subcommands
    output, = capture_io { Sight::CLI.run(["--help"]) }

    assert_includes output, "install-hook"
    assert_includes output, "uninstall-hook"
  end

  def test_install_hook_claude
    called = false
    Sight::ClaudeHookInstaller.stub(:install, -> { called = true }) do
      Sight::CLI.run(["install-hook", "claude"])
    end

    assert called
  end

  def test_uninstall_hook_claude
    called = false

    Sight::ClaudeHookInstaller.stub(:uninstall, -> { called = true }) do
      Sight::CLI.run(["uninstall-hook", "claude"])
    end

    assert called
  end

  def test_install_hook_unknown_agent
    _, error = capture_io { Sight::CLI.run(["install-hook", "vim"]) }

    assert_includes error, "Unknown agent"
  end

  def test_hook_run_with_pending_review
    Dir.mktmpdir do |dir|
      sight_dir = File.join(dir, "sight")
      FileUtils.mkdir_p(sight_dir)
      File.write(File.join(sight_dir, "pending-review"), "annotation content")

      Sight::Git.stub(:repo_dir, dir) do
        output, = capture_io { Sight::CLI.run(["hook-run"]) }

        assert_includes output, "annotations"
        assert_includes output, "annotation content"
        refute File.exist?(File.join(sight_dir, "pending-review"))
      end
    end
  end

  def test_hook_run_withoutput_pending_review
    Dir.mktmpdir do |dir|
      Sight::Git.stub(:repo_dir, dir) do
        output, = capture_io { Sight::CLI.run(["hook-run"]) }

        assert_empty output
      end
    end
  end

  def test_hook_run_not_in_git_repo
    Sight::Git.stub(:repo_dir, -> { raise Sight::Error, "not a git repository" }) do
      output, = capture_io { Sight::CLI.run(["hook-run"]) }

      assert_empty output
    end
  end

  def test_no_changes
    Sight::Git.stub(:diff, "") do
      Sight::Git.stub(:untracked_files, []) do
        Sight::Git.stub(:clear_pending_review, nil) do
          _, err = capture_io { Sight::CLI.run([]) }

          assert_includes err, "No changes"
        end
      end
    end
  end

  def test_launches_app_with_parsed_diff
    received_files = nil

    Sight::Git.stub(:diff, sample_diff) do
      Sight::Git.stub(:untracked_files, []) do
        Sight::Git.stub(:clear_pending_review, nil) do
          mock_app = Minitest::Mock.new
          mock_app.expect(:run, nil)
          mock_app.expect(:annotations, [])

          Sight::App.stub(:new, ->(files) {
            received_files = files
            mock_app
          }) do
            Sight::CLI.run([])
          end

          assert_equal 1, received_files.size
          mock_app.verify
        end
      end
    end
  end

  def test_annotations_outputput_on_quit
    annotation = Sight::Annotation.new(
      file_path: "foo.rb",
      type: :hunk,
      hunk: Sight::Hunk.new(context: "def foo", lines: [
        Sight::DiffLine.new(type: :add, content: "+new", lineno: 1)
      ]),
      comment: "fix this"
    )
    saved_content = nil

    Sight::Git.stub(:diff, sample_diff) do
      Sight::Git.stub(:untracked_files, []) do
        Sight::Git.stub(:clear_pending_review, nil) do
          Sight::Git.stub(
            :save_pending_review, ->(content) { saved_content = content }
          ) do
            mock_app = Minitest::Mock.new
            mock_app.expect(:run, nil)
            mock_app.expect(:annotations, [annotation])
            mock_app.expect(:annotations, [annotation])
            mock_app.expect(:annotations, [annotation])

            Sight::App.stub(:new, ->(_files) { mock_app }) do
              output, = capture_io { Sight::CLI.run([]) }

              assert_includes output, "1 annotation on 1 file"
            end

            assert_includes saved_content, "## File: foo.rb"
            mock_app.verify
          end
        end
      end
    end
  end

  def test_untracked_files_appended
    received_files = nil

    Sight::Git.stub(:diff, sample_diff) do
      Sight::Git.stub(:untracked_files, ["new.rb"]) do
        Sight::Git.stub(:file_content, "hello\n") do
          Sight::Git.stub(:clear_pending_review, nil) do
            mock_app = Minitest::Mock.new
            mock_app.expect(:run, nil)
            mock_app.expect(:annotations, [])

            Sight::App.stub(:new, ->(files) {
              received_files = files
              mock_app
            }) do
              Sight::CLI.run([])
            end

            assert_equal 2, received_files.size
            assert_equal :untracked, received_files[1].status
            assert_equal "new.rb", received_files[1].path
            mock_app.verify
          end
        end
      end
    end
  end

  private

  def sample_diff
    <<~DIFF
      diff --git a/foo.rb b/foo.rb
      --- a/foo.rb
      +++ b/foo.rb
      @@ -1 +1 @@
      -old
      +new
    DIFF
  end
end
