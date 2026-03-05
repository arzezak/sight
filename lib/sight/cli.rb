# frozen_string_literal: true

module Sight
  module CLI
    module_function

    def run(argv)
      if argv.include?("--help") || argv.include?("-h")
        puts "Usage: sight"
        puts "Interactive git diff viewer (staged + unstaged)"
        puts
        puts "Keys: j/k hunks, n/p files, c comment, ? help, q quit"
        puts
        puts "Annotations are printed to stdout on quit."
        return
      end

      if argv.include?("--version") || argv.include?("-v")
        puts "sight #{VERSION}"
        return
      end

      raw = Git.diff
      files = DiffParser.parse(raw)

      Git.untracked_files.each do |path|
        content = Git.file_content(path)
        next unless content.valid_encoding? && !content.include?("\x00")
        files << DiffParser.build_untracked(path, content)
      end

      if files.empty?
        warn "No changes"
        return
      end

      app = App.new(files)
      app.run

      unless app.annotations.empty?
        puts AnnotationFormatter.format(app.annotations)
      end
    end
  end
end
