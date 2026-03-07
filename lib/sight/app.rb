# frozen_string_literal: true

require "curses"

module Sight
  class App
    attr_reader :files, :file_lines, :annotations
    attr_accessor :file_idx, :offset, :hunk_idx

    def initialize(files)
      @files = files
      @file_lines = files.map { build_file_lines(it) }
      @file_idx = 0
      @offset = 0
      @hunk_idx = 0
      @hunk_offsets_cache = {}
      @annotations = []
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
      Curses.init_pair(6, Curses::COLOR_MAGENTA, -1)
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
      file = files[file_idx]
      badge = "[#{file.status || :modified}]"
      path = file.path
      gap = width - path.length - badge.length
      win.setpos(0, 0)
      if gap >= 1
        win.attron(color_for(:header)) { win.addstr("#{path}#{" " * gap}") }
        win.attron(badge_color(file.status)) { win.addstr(badge) }
      else
        win.attron(color_for(:header)) { win.addstr(path[0, width]) }
      end
      win.setpos(1, 0)
      win.attron(Curses.color_pair(0) | Curses::A_BOLD) { win.addstr("\u2500" * width) }
    end

    def render_content(win, width)
      gutter = gutter_width
      dim = Curses.color_pair(0) | Curses::A_DIM
      content_width = width - gutter - 3

      selected_start = hunk_offsets[hunk_idx]
      selected_end = hunk_end_offset(hunk_idx)

      commented_lines = commented_hunk_lines

      scroll_height.times do |row|
        idx = offset + row
        break if idx >= lines.size
        line = lines[idx]
        win.setpos(row + 2, 0)
        active = idx >= selected_start && idx < selected_end
        gutter_str = format_gutter(line.type, line.lineno, gutter)
        commented = commented_lines.include?(idx)
        separator = commented ? "\u2503" : "\u2502"
        sep_attr = commented ? Curses.color_pair(4) : dim
        win.attron(dim) { win.addstr("#{gutter_str} ") }
        win.attron(sep_attr) { win.addstr(separator) }
        win.attron(dim) { win.addstr(" ") }
        attr = active ? color_for(line.type) : Curses.color_pair(5)
        win.attron(attr) { win.addstr(line.text[0, content_width]) }
      end
    end

    def render_status_bar(win, width)
      win.setpos(Curses.lines - 1, 0)
      win.attron(Curses.color_pair(4) | Curses::A_REVERSE) do
        percent = if lines.size <= scroll_height
          100
        else
          ((offset + scroll_height) * 100.0 / lines.size).ceil.clamp(0, 100)
        end
        commented = hunk_commented?(file_idx, hunk_idx) ? " [commented]" : ""
        status = " File #{file_idx + 1}/#{files.size} | Hunk #{hunk_idx + 1}/#{hunk_offsets.size}#{commented} | #{percent}% "
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
      when :header then Curses.color_pair(0) | Curses::A_BOLD
      else Curses.color_pair(0)
      end
    end

    def badge_color(status)
      case status
      when :added then Curses.color_pair(1) | Curses::A_BOLD
      when :deleted then Curses.color_pair(2) | Curses::A_BOLD
      when :untracked then Curses.color_pair(6) | Curses::A_BOLD
      else Curses.color_pair(4) | Curses::A_BOLD
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
      when 6 then scroll(scroll_height)
      when 2 then scroll(-scroll_height)
      when 4 then scroll(scroll_height / 2)
      when 21 then scroll(-scroll_height / 2)
      when "c" then annotate_hunk
      when "?" then show_help
      end
      true
    end

    HELP_KEYS = [
      ["j", "Next hunk"],
      ["k", "Previous hunk"],
      ["C-f", "Page down"],
      ["C-b", "Page up"],
      ["C-d", "Half page down"],
      ["C-u", "Half page up"],
      ["n", "Next file"],
      ["p", "Previous file"],
      ["q / Esc", "Quit"],
      ["c", "Comment on hunk"],
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

    def annotate_hunk
      hunk = files[file_idx].hunks[hunk_idx]
      return unless hunk
      comment = prompt_comment("Comment on hunk")
      return unless comment
      @annotations << Annotation.new(
        file_path: files[file_idx].path,
        type: :hunk,
        hunk: hunk,
        comment: comment
      )
    end

    def prompt_comment(title)
      win = Curses.stdscr
      width = (Curses.cols * 2 / 3).clamp(50, 80)
      height = 5
      top = (Curses.lines - height) / 2
      left = (Curses.cols - width) / 2

      draw_box(win, top, left, width, height, title, [""])
      win.setpos(top + 3, left + 3)
      win.refresh

      Curses.curs_set(1)
      text = ""
      field_width = width - 6
      redraw_field = -> {
        win.setpos(top + 3, left + 3)
        win.addstr(" " * field_width)
        visible = (text.length > field_width) ? text[-field_width..] : text
        win.setpos(top + 3, left + 3)
        win.addstr(visible)
      }
      loop do
        ch = Curses.getch
        case ch
        when 10, 13, Curses::KEY_ENTER
          break
        when 27
          text = nil
          break
        when Curses::KEY_BACKSPACE, 127, 8
          unless text.empty?
            text = text[0..-2]
            redraw_field.call
          end
        else
          text += ch.chr if ch.is_a?(Integer) && ch >= 32 && ch < 127
          text += ch if ch.is_a?(String) && ch.length == 1
          redraw_field.call
        end
      end
      Curses.curs_set(0)

      text&.strip&.empty? ? nil : text&.strip
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

    def hunk_end_offset(idx)
      (idx + 1 < hunk_offsets.size) ? hunk_offsets[idx + 1] : lines.size
    end

    def hunk_commented?(file_index, hunk_index)
      path = files[file_index].path
      hunk = files[file_index].hunks[hunk_index]
      annotations.any? { |a| a.file_path == path && a.hunk.equal?(hunk) }
    end

    def commented_hunk_lines
      hunk_offsets.each_with_index.each_with_object(Set.new) do |(offset, hunk_index), set|
        next unless hunk_commented?(file_idx, hunk_index)
        (offset...hunk_end_offset(hunk_index)).each { |i| set << i }
      end
    end

    def scroll(delta)
      max = [0, lines.size - scroll_height].max
      self.offset = (offset + delta).clamp(0, max)
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
