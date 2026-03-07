# frozen_string_literal: true

module Sight
  class AnnotationFormatter
    def initialize(annotations)
      @annotations = annotations
    end

    def format
      return "" if @annotations.empty?

      grouped = @annotations.group_by(&:file_path)
      grouped.map { |path, file_annotations| format_file(path, file_annotations) }.join("\n")
    end

    def summary
      file_count = @annotations.map(&:file_path).uniq.size
      "#{@annotations.size} #{(@annotations.size == 1) ? "annotation" : "annotations"} on #{file_count} #{(file_count == 1) ? "file" : "files"}"
    end

    private

    def format_file(path, annotations)
      out = "## File: #{path}\n\n"
      annotations.each do |annotation|
        context = annotation.hunk.context ? " #{annotation.hunk.context}" : ""
        out << "Hunk (@@#{context}):\n"
        out << "```diff\n"
        annotation.hunk.lines.each do |line|
          next unless %i[add del].include?(line.type)
          out << "#{line.content}\n"
        end
        out << "```\n"
        out << "> #{annotation.comment}\n\n"
      end
      out
    end
  end
end
