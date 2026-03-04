# frozen_string_literal: true

module Sight
  module Git
    module_function

    def diff
      output, success = run_cmd(["git", "diff", "--no-color", "HEAD"])
      unless success
        output, success = run_cmd(["git", "diff", "--no-color", "--cached"], err: [:child, :out])
        raise Error, "git diff failed: #{output}" unless success
      end
      output
    end

    def run_cmd(cmd, err: IO::NULL)
      output = IO.popen(cmd, err: err, &:read)
      [output, $?.success?]
    end
  end
end
