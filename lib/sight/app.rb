# frozen_string_literal: true

require "curses"

module Sight
  class App
    attr_reader :files, :file_lines
    attr_accessor :file_idx, :offset, :hunk_idx

    def initialize(files)
      @files = files
      @file_lines = files.map { build_file_lines(it) }
      @file_idx = 0
      @offset = 0
      @hunk_idx = 0
      @hunk_offsets_cache = {}
    end

    def run
      init_curses

      loop do
        render

        break unless handle_input
      end
    ensure
      Curses.close_screen
    end

    private

    def build_file_lines(file)
      file.hunks.flat_map do |hunk|
        hunk.lines.map do |diff_line|
          text = (diff_line.type == :meta) ? diff_line.content : diff_line.content[1..]
          DisplayLine.new(type: diff_line.type, text: text, lineno: diff_line.lineno)
        end
      end
    end

    def init_curses
      Curses.init_screen
      Curses.start_color
      Curses.use_default_colors
      Curses.cbreak
      Curses.noecho
      Curses.curs_set(0)
      Curses.stdscr.keypad(true)
      Curses.init_pair(1, Curses::COLOR_GREEN, -1)
      Curses.init_pair(2, Curses::COLOR_RED, -1)
      Curses.init_pair(3, Curses::COLOR_CYAN, -1)
      Curses.init_pair(4, Curses::COLOR_YELLOW, -1)
      Curses.init_pair(5, 240, -1)
    end

    def lines
      file_lines[file_idx]
    end

    def render
      win = Curses.stdscr
      win.clear
      width = Curses.cols
      render_header(win, width)
      render_content(win, width)
      render_status_bar(win, width)
      win.refresh
    end

    def render_header(win, width)
      path = files[file_idx].path
      win.setpos(0, 0)
      win.attron(color_for(:header)) { win.addstr(path[0, width]) }
      win.setpos(1, 0)
      win.attron(color_for(:header)) { win.addstr("\u2500" * width) }
    end

    def render_content(win, width)
      gutter = gutter_width
      dim = Curses.color_pair(0) | Curses::A_DIM
      content_width = width - gutter - 3

      selected_start = hunk_offsets[hunk_idx]
      selected_end = if hunk_idx + 1 < hunk_offsets.size
                       hunk_offsets[hunk_idx + 1]
                     else
                       lines.size
                     end

      scroll_height.times do |row|
        idx = offset + row
        break if idx >= lines.size
        line = lines[idx]
        win.setpos(row + 2, 0)
        active = idx >= selected_start && idx < selected_end
        win.attron(dim) { win.addstr("#{format_gutter(line.type, line.lineno, gutter)} \u2502 ") }
        attr = active ? color_for(line.type) : Curses.color_pair(5)
        win.attron(attr) { win.addstr(line.text[0, content_width]) }
      end
    end

    def render_status_bar(win, width)
      win.setpos(Curses.lines - 1, 0)
      win.attron(Curses.color_pair(4) | Curses::A_REVERSE) do
        status = " File #{file_idx + 1}/#{files.size} | Hunk #{hunk_idx + 1}/#{hunk_offsets.size} | Line #{offset + 1}/#{lines.size} "
        win.addstr(status.ljust(width))
      end
    end

    def format_gutter(type, lineno, width)
      if lineno
        lineno.to_s.rjust(width)
      elsif type == :del
        "~".rjust(width)
      else
        " " * width
      end
    end

    def color_for(type)
      case type
      when :add then Curses.color_pair(1)
      when :del then Curses.color_pair(2)
      when :header then Curses.color_pair(4) | Curses::A_BOLD
      else Curses.color_pair(0)
      end
    end

    def scroll_height
      Curses.lines - 3
    end

    def gutter_width
      @gutter_width ||= begin
        max = file_lines.flat_map { |file| file.filter_map { |line| line.lineno } }.max || 1
        max.to_s.length
      end
    end

    def handle_input
      key = Curses.getch
      case key
      when "q", 27 then return false
      when "j" then jump_hunk(1)
      when "k" then jump_hunk(-1)
      when "n" then jump_file(1)
      when "p" then jump_file(-1)
      when "?" then show_help
      end
      true
    end

    HELP_KEYS = [
      ["j", "Next hunk"],
      ["k", "Previous hunk"],
      ["n", "Next file"],
      ["p", "Previous file"],
      ["q / Esc", "Quit"],
      ["?", "Toggle this help"]
    ].freeze

    KEY_W = HELP_KEYS.map { |k, _| k.length }.max
    HELP_LINES = HELP_KEYS.map { |k, desc| "#{k.ljust(KEY_W)}   #{desc}" }.freeze
    HELP_WIDTH = HELP_LINES.map(&:length).max + 6
    HELP_HEIGHT = HELP_LINES.size + 4

    def show_help
      win = Curses.stdscr
      top = (Curses.lines - HELP_HEIGHT) / 2
      left = (Curses.cols - HELP_WIDTH) / 2
      draw_box(win, top, left, HELP_WIDTH, HELP_HEIGHT, "Keybindings", HELP_LINES)
      win.refresh
      Curses.getch
    end

    def draw_box(win, top, left, width, height, title, content_lines)
      win.attron(Curses.color_pair(0)) do
        win.setpos(top, left)
        win.addstr("┌#{"─" * (width - 2)}┐")

        win.setpos(top + 1, left)
        pad = width - 2 - title.length
        win.addstr("│#{" " * (pad / 2)}#{title}#{" " * (pad - pad / 2)}│")

        win.setpos(top + 2, left)
        win.addstr("├#{"─" * (width - 2)}┤")

        content_lines.each_with_index do |line, i|
          win.setpos(top + 3 + i, left)
          win.addstr("│  #{line.ljust(width - 5)} │")
        end

        win.setpos(top + height - 1, left)
        win.addstr("└#{"─" * (width - 2)}┘")
      end
    end

    def hunk_offsets
      @hunk_offsets_cache[file_idx] ||= begin
        offsets = []
        line_idx = 0
        files[file_idx].hunks.each do |hunk|
          offsets << line_idx
          line_idx += hunk.lines.size
        end
        offsets
      end
    end

    def jump_hunk(delta)
      return if hunk_offsets.empty?
      self.hunk_idx = (hunk_idx + delta).clamp(0, hunk_offsets.size - 1)
      target = hunk_offsets[hunk_idx]
      margin = [2, scroll_height / 4].min
      max = [0, lines.size - scroll_height].max
      self.offset = [target - margin, 0].max.clamp(0, max)
    end

    def jump_file(direction)
      new_idx = (file_idx + direction).clamp(0, files.size - 1)
      return if new_idx == file_idx
      self.file_idx = new_idx
      self.offset = 0
      self.hunk_idx = 0
    end
  end
end
