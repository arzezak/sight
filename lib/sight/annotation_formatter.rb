# frozen_string_literal: true

module Sight
  module AnnotationFormatter
    module_function

    def format(annotations)
      return "" if annotations.empty?

      grouped = annotations.group_by(&:file_path)
      grouped.map { |path, file_annotations| format_file(path, file_annotations) }.join("\n")
    end

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
