# frozen_string_literal: true

require "json"
require "fileutils"

module Sight
  module ClaudeHookInstaller
    HOOK_COMMAND = "sight hook-run"

    module_function

    def settings_path
      candidates = [
        (File.join(ENV["XDG_CONFIG_HOME"], "claude", "settings.json") if ENV["XDG_CONFIG_HOME"]),
        File.join(Dir.home, ".claude", "settings.json"),
        File.join(Dir.home, ".config", "claude", "settings.json")
      ].compact

      candidates.find { File.exist?(it) } || candidates.last
    end

    def install(path: settings_path)
      settings = if File.exist?(path)
        JSON.parse(File.read(path))
      else
        {}
      end

      hooks = settings["hooks"] ||= {}
      prompt_hooks = hooks["UserPromptSubmit"] ||= []

      if prompt_hooks.any? { |h| hook_is_sight?(h) }
        puts "sight hook already installed"
        return
      end

      prompt_hooks << {
        "matcher" => "*",
        "hooks" => [{"type" => "command", "command" => HOOK_COMMAND}]
      }

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(settings) + "\n")
      puts "Installed sight hook into #{path}"
    end

    def uninstall(path: settings_path)
      unless File.exist?(path)
        puts "No settings file found"
        return
      end

      settings = JSON.parse(File.read(path))
      prompt_hooks = settings.dig("hooks", "UserPromptSubmit")

      unless prompt_hooks&.any? { |h| hook_is_sight?(h) }
        puts "No sight hook found"
        return
      end

      prompt_hooks.reject! { |h| hook_is_sight?(h) }
      File.write(path, JSON.pretty_generate(settings) + "\n")
      puts "Uninstalled sight hook"
    end

    def hook_is_sight?(entry)
      Array(entry["hooks"]).any? { |h| h["command"]&.include?("sight") }
    end
  end
end
