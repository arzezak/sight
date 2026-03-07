# frozen_string_literal: true

module Sight
  class Summary
    def initialize(annotations)
      @annotations = annotations
    end

    def to_s
      "#{pluralize_annotations} on #{pluralize_files}"
    end

    private

    attr_reader :annotations

    def pluralize_annotations
      "#{annotations.size} #{(annotations.size == 1) ? "annotation" : "annotations"}"
    end

    def pluralize_files
      "#{file_count} #{(file_count == 1) ? "file" : "files"}"
    end

    def file_count
      annotations.map(&:file_path).uniq.size
    end
  end
end
