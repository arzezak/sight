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
        puts "Subcommands:"
        puts "  install-hook     Install Claude Code hook for annotations"
        puts "  uninstall-hook   Remove Claude Code hook"
        return
      end

      if argv.include?("--version") || argv.include?("-v")
        puts "sight #{VERSION}"
        return
      end

      if argv.include?("install-hook")
        HookInstaller.install
        return
      end

      if argv.include?("uninstall-hook")
        HookInstaller.uninstall
        return
      end

      if argv.include?("hook-run")
        run_hook
        return
      end

      Git.clear_pending_review

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
        formatted = AnnotationFormatter.format(app.annotations)
        puts formatted
        Git.save_pending_review(formatted)
      end
    end

    def run_hook
      git_dir = Git.repo_dir
    rescue Error
      nil
    else
      file = File.join(git_dir, "sight", "pending-review")
      return unless File.exist?(file)

      content = File.read(file)
      puts "The user has just finished reviewing your code changes in sight. Here are their annotations:"
      puts
      puts content
      File.delete(file)
    end
  end
end
