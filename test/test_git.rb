# frozen_string_literal: true

require "test_helper"

class TestGit < Minitest::Test
  def test_diff_returns_output
    Sight::Git.stub(:run_cmd, ["diff output", true]) do
      assert_equal "diff output", Sight::Git.diff
    end
  end

  def test_diff_raises_on_failure
    Sight::Git.stub(:run_cmd, ["", false]) do
      assert_raises(Sight::Error) { Sight::Git.diff }
    end
  end
end
