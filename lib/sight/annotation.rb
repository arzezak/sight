# frozen_string_literal: true

module Sight
  Annotation = Struct.new(:file_path, :type, :hunk, :comment, keyword_init: true)
end
