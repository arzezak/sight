# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class TestCLI < Minitest::Test
  def test_help_flag
    out, = capture_io { Sight::CLI.run(["--help"]) }
    assert_includes out, "Usage: sight"
    assert_includes out, "hunks"
  end

  def test_help_short_flag
    out, = capture_io { Sight::CLI.run(["-h"]) }
    assert_includes out, "Usage: sight"
  end

  def test_version_flag
    out, = capture_io { Sight::CLI.run(["--version"]) }
    assert_includes out, Sight::VERSION
  end

  def test_version_short_flag
    out, = capture_io { Sight::CLI.run(["-v"]) }
    assert_includes out, Sight::VERSION
  end

  def test_no_changes
    Sight::Git.stub(:diff, "") do
      Sight::Git.stub(:untracked_files, []) do
        _, err = capture_io { Sight::CLI.run([]) }
        assert_includes err, "No changes"
      end
    end
  end

  def test_launches_app_with_parsed_diff
    received_files = nil

    Sight::Git.stub(:diff, sample_diff) do
      Sight::Git.stub(:untracked_files, []) do
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

  def test_annotations_output_on_quit
    hunk = Sight::Hunk.new(context: "def foo", lines: [
      Sight::DiffLine.new(type: :add, content: "+new", lineno: 1)
    ])
    ann = Sight::Annotation.new(
      file_path: "foo.rb", type: :hunk, hunk: hunk, comment: "fix this"
    )

    Sight::Git.stub(:diff, sample_diff) do
      Sight::Git.stub(:untracked_files, []) do
        mock_app = Minitest::Mock.new
        mock_app.expect(:run, nil)
        mock_app.expect(:annotations, [ann])
        mock_app.expect(:annotations, [ann])

        Sight::App.stub(:new, ->(_files) { mock_app }) do
          out, = capture_io { Sight::CLI.run([]) }
          assert_includes out, "## File: foo.rb"
          assert_includes out, "> fix this"
        end

        mock_app.verify
      end
    end
  end

  def test_untracked_files_appended
    received_files = nil

    Sight::Git.stub(:diff, sample_diff) do
      Sight::Git.stub(:untracked_files, ["new.rb"]) do
        Sight::Git.stub(:file_content, "hello\n") do
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
