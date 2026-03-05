# frozen_string_literal: true

require "json"
require "fileutils"

module Sight
  module CursorHookInstaller
    HOOK_COMMAND = "sight cursor-hook-run"

    module_function

    def hooks_path
      File.join(Dir.home, ".cursor", "hooks.json")
    end

    def install(path: hooks_path)
      config = if File.exist?(path)
        JSON.parse(File.read(path))
      else
        {"version" => 1, "hooks" => {}}
      end

      config["version"] ||= 1
      hooks = config["hooks"] ||= {}
      prompt_hooks = hooks["beforeSubmitPrompt"] ||= []

      if prompt_hooks.any? { |h| hook_is_sight?(h) }
        puts "sight hook already installed"
        return
      end

      prompt_hooks << {"command" => HOOK_COMMAND}

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(config) + "\n")
      puts "Installed sight hook into #{path}"
    end

    def uninstall(path: hooks_path)
      unless File.exist?(path)
        puts "No hooks file found"
        return
      end

      config = JSON.parse(File.read(path))
      prompt_hooks = config.dig("hooks", "beforeSubmitPrompt")

      unless prompt_hooks&.any? { |h| hook_is_sight?(h) }
        puts "No sight hook found"
        return
      end

      prompt_hooks.reject! { |h| hook_is_sight?(h) }
      File.write(path, JSON.pretty_generate(config) + "\n")
      puts "Uninstalled sight hook"
    end

    def hook_is_sight?(entry)
      entry["command"]&.include?("sight")
    end
  end
end
