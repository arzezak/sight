# frozen_string_literal: true

module Sight
  module Git
    module_function

    def diff
      output, success = run_cmd(["git", "diff", "--no-color", "HEAD"])
      raise Error, "git diff failed" unless success
      output
    end

    def run_cmd(cmd, err: IO::NULL)
      output = IO.popen(cmd, err: err, &:read)
      [output, $?.success?]
    end
  end
end
