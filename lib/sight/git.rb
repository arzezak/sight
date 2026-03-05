# frozen_string_literal: true

require "fileutils"

module Sight
  module Git
    module_function

    def diff
      output, success = run_cmd(["git", "diff", "--no-color", "HEAD"])
      raise Error, "git diff failed" unless success
      output
    end

    def untracked_files
      output, success = run_cmd(["git", "ls-files", "--others", "--exclude-standard"])
      return [] unless success
      output.lines(chomp: true).reject(&:empty?)
    end

    def file_content(path)
      File.read(path, mode: "rb")
    end

    def repo_dir
      output, success = run_cmd(["git", "rev-parse", "--git-dir"])
      raise Error, "not a git repository" unless success
      output.strip
    end

    def save_pending_review(content)
      dir = File.join(repo_dir, "sight")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "pending-review"), content)
    end

    def clear_pending_review
      path = File.join(repo_dir, "sight", "pending-review")
      File.delete(path) if File.exist?(path)
    end

    def run_cmd(cmd, err: IO::NULL)
      output = IO.popen(cmd, err: err, &:read)
      [output, $?.success?]
    end
  end
end
