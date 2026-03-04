# frozen_string_literal: true

require "test_helper"

class TestGit < Minitest::Test
  def test_diff_returns_output_when_head_succeeds
    stub_run_cmd(["diff output", true]) do
      assert_equal "diff output", Sight::Git.diff
    end
  end

  def test_diff_falls_back_to_cached_when_head_fails
    calls = [["", false], ["cached output", true]]
    stub_run_cmd_sequence(calls) do
      assert_equal "cached output", Sight::Git.diff
    end
  end

  def test_diff_raises_when_both_fail
    calls = [["", false], ["error msg", false]]
    stub_run_cmd_sequence(calls) do
      assert_raises(Sight::Error) { Sight::Git.diff }
    end
  end

  private

  def stub_run_cmd(result, &block)
    Sight::Git.stub(:run_cmd, result, &block)
  end

  def stub_run_cmd_sequence(results)
    call_idx = 0
    fake = lambda { |*_args, **_opts|
      r = results[call_idx]
      call_idx += 1
      r
    }
    Sight::Git.stub(:run_cmd, fake) do
      yield
    end
  end
end
