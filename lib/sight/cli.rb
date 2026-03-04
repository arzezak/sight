# frozen_string_literal: true

module Sight
  module CLI
    module_function

    def run(argv)
      if argv.include?("--help") || argv.include?("-h")
        puts "Usage: sight"
        puts "Interactive git diff viewer (staged + unstaged)"
        puts
        puts "Keys: j/k/↑/↓ scroll, f/b page, d/u half-page, g/G top/bottom, n/p/→/← next/prev file, ? help, q quit"
        return
      end

      if argv.include?("--version") || argv.include?("-v")
        puts "sight #{VERSION}"
        return
      end

      raw = Git.diff
      if raw.empty?
        warn "No diff output."
        return
      end

      files = DiffParser.parse(raw)
      App.new(files).run
    end
  end
end
