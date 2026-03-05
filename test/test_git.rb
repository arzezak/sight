# frozen_string_literal: true

require "test_helper"
require "tmpdir"

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

  def test_untracked_files
    Sight::Git.stub(:run_cmd, ["foo.rb\nbar.rb\n", true]) do
      assert_equal ["foo.rb", "bar.rb"], Sight::Git.untracked_files
    end
  end

  def test_untracked_files_on_failure
    Sight::Git.stub(:run_cmd, ["", false]) do
      assert_equal [], Sight::Git.untracked_files
    end
  end

  def test_repo_dir
    Sight::Git.stub(:run_cmd, ["/tmp/repo/.git\n", true]) do
      assert_equal "/tmp/repo/.git", Sight::Git.repo_dir
    end
  end

  def test_repo_dir_raises_on_failure
    Sight::Git.stub(:run_cmd, ["", false]) do
      assert_raises(Sight::Error) { Sight::Git.repo_dir }
    end
  end

  def test_save_pending_review
    Dir.mktmpdir do |dir|
      git_dir = File.join(dir, ".git")
      Dir.mkdir(git_dir)

      Sight::Git.stub(:repo_dir, git_dir) do
        Sight::Git.save_pending_review("review content")

        path = File.join(git_dir, "sight", "pending-review")
        assert File.exist?(path)
        assert_equal "review content", File.read(path)
      end
    end
  end

  def test_clear_pending_review
    Dir.mktmpdir do |dir|
      git_dir = File.join(dir, ".git")
      sight_dir = File.join(git_dir, "sight")
      FileUtils.mkdir_p(sight_dir)
      path = File.join(sight_dir, "pending-review")
      File.write(path, "old review")

      Sight::Git.stub(:repo_dir, git_dir) do
        Sight::Git.clear_pending_review
        refute File.exist?(path)
      end
    end
  end

  def test_clear_pending_review_no_file
    Dir.mktmpdir do |dir|
      git_dir = File.join(dir, ".git")
      Dir.mkdir(git_dir)

      Sight::Git.stub(:repo_dir, git_dir) do
        Sight::Git.clear_pending_review # should not raise
      end
    end
  end
end
