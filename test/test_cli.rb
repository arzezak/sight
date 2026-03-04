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

  def test_empty_diff
    Sight::Git.stub(:diff, "") do
      _, err = capture_io { Sight::CLI.run([]) }
      assert_includes err, "No diff output"
    end
  end

  def test_launches_app_with_parsed_diff
    received_files = nil

    Sight::Git.stub(:diff, sample_diff) do
      mock_app = Minitest::Mock.new
      mock_app.expect(:run, nil)

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
