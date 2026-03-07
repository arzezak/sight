# frozen_string_literal: true

require_relative "sight/annotation"
require_relative "sight/annotation_formatter"
require_relative "sight/app"
require_relative "sight/claude_hook_installer"
require_relative "sight/cli"
require_relative "sight/diff_parser"
require_relative "sight/display_line"
require_relative "sight/git"
require_relative "sight/version"

module Sight
  class Error < StandardError; end
end
