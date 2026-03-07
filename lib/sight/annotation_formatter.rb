# frozen_string_literal: true

module Sight
  class AnnotationFormatter
    def initialize(annotations)
      @annotations = annotations
    end

    def format
      return "" if annotations.empty?

      annotations.group_by(&:file_path).map do |path, file_annotations|
        format_file(path, file_annotations)
      end.join("\n")
    end

    private

    attr_reader :annotations

    def format_file(path, file_annotations)
      out = "## File: #{path}\n\n"

      file_annotations.each do |file_annotation|
        context = file_annotation.hunk.context ? " #{file_annotation.hunk.context}" : ""
        out << "Hunk (@@#{context}):\n"
        out << "```diff\n"
        file_annotation.hunk.lines.each do |line|
          next unless %i[add del].include?(line.type)
          out << "#{line.content}\n"
        end
        out << "```\n"
        out << "> #{file_annotation.comment}\n\n"
      end

      out
    end
  end
end
