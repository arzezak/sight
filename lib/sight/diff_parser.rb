# frozen_string_literal: true

module Sight
  DiffLine = Struct.new(:type, :content, :lineno, :old_lineno, keyword_init: true)
  Hunk = Struct.new(:context, :lines, keyword_init: true)
  DiffFile = Struct.new(:path, :hunks, keyword_init: true)

  module DiffParser
    module_function

    def parse(raw)
      files = []
      current_file = nil
      current_hunk = nil
      new_lineno = nil
      old_lineno = nil

      raw.each_line(chomp: true) do |line|
        if line.start_with?("diff --git ")
          current_hunk = nil
          path = line.split(" b/", 2).last
          current_file = DiffFile.new(path: path, hunks: [])
          files << current_file
        elsif current_file.nil?
          next
        elsif line.start_with?("@@ ")
          context, new_start, old_start = parse_hunk_header(line)
          new_lineno = new_start
          old_lineno = old_start
          current_hunk = Hunk.new(context: context, lines: [])
          current_file.hunks << current_hunk
        elsif current_hunk
          type = case line[0]
          when "+" then :add
          when "-" then :del
          when "\\" then :meta
          else :ctx
          end
          ln_old = (type == :add || type == :meta) ? nil : old_lineno
          ln_new = (type == :del || type == :meta) ? nil : new_lineno
          old_lineno += 1 if ln_old
          new_lineno += 1 if ln_new
          current_hunk.lines << DiffLine.new(type: type, content: line, lineno: ln_new, old_lineno: ln_old)
        end
        # skip other header lines (index, ---, +++)
      end

      files
    end

    def parse_hunk_header(line)
      match = line.match(/@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@(.*)/)
      return [nil, 1, 1] unless match
      context = match[3].strip
      old_start = match[1].to_i
      new_start = match[2].to_i
      [context.empty? ? nil : context, new_start, old_start]
    end
  end
end
