# frozen_string_literal: true

module Sight
  module CLI
    module_function

    def run(argv)
      return print_help if argv.include?("--help") || argv.include?("-h")
      return puts("sight #{VERSION}") if argv.include?("--version") || argv.include?("-v")

      case argv[0]
      when "install-hook" then install_hook(argv[1])
      when "uninstall-hook" then uninstall_hook(argv[1])
      when "hook-run" then run_hook
      else open
      end
    end

    def print_help
      puts "Usage: sight"
      puts "Interactive git diff viewer (staged + unstaged)"
      puts
      puts "Keys: j/k hunks, n/p files, c comment, ? help, q quit"
      puts
      puts "Subcommands:"
      puts "  install-hook <agent>    Install hook (claude)"
      puts "  uninstall-hook <agent>  Remove hook (claude)"
    end

    def open
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
        Git.save_pending_review(formatted)
        puts AnnotationFormatter.summary(app.annotations)
      end
    end

    AGENTS = {
      "claude" => ClaudeHookInstaller
    }.freeze

    def install_hook(agent)
      resolve_installer(agent)&.install
    end

    def uninstall_hook(agent)
      resolve_installer(agent)&.uninstall
    end

    def resolve_installer(agent)
      AGENTS.fetch(agent) { warn "Unknown agent: #{agent.inspect}. Use: claude" }
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
