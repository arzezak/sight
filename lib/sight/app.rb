# frozen_string_literal: true

require "curses"

module Sight
  class App
    attr_reader :files, :lines, :annotations
    attr_accessor :offset, :hunk_idx

    def initialize(files)
      @files = files
      @offset = 0
      @hunk_idx = 0
      @annotations = []
      build_flat_view
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

    def build_flat_view
      @lines = []
      @hunk_offsets = []
      @hunk_entries = []

      @files.each_with_index do |file, file_idx|
        if file_idx > 0
          @lines << DisplayLine.new(type: :file_separator, text: nil, lineno: nil)
        end

        file.hunks.each do |hunk|
          @hunk_offsets << @lines.size
          @hunk_entries << [file, hunk]

          hunk.lines.each do |diff_line|
            text = (diff_line.type == :meta) ? diff_line.content : diff_line.content[1..]
            @lines << DisplayLine.new(type: diff_line.type, text: text, lineno: diff_line.lineno)
          end
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
      file, hunk = current_hunk_entry
      return unless file
      badge = " [#{file.status || :modified}]"
      left = "\u2500\u2500 #{file.path} "
      left += "\u2500\u2500 #{hunk.context} " if hunk.context && !hunk.context.empty?
      fill_len = [width - left.length - badge.length, 0].max
      win.setpos(0, 0)
      win.attron(color_for(:file_header)) { win.addstr("#{left}#{"\u2500" * fill_len}"[0, width - badge.length]) }
      win.attron(badge_color(file.status)) { win.addstr(badge) }
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
        win.setpos(row + 1, 0)

        if line.type == :file_separator
          win.attron(color_for(:file_header)) { win.addstr("\u2500" * width) }
          next
        end

        active = idx >= selected_start && idx < selected_end
        gutter_str = format_gutter(line.type, line.lineno, gutter)
        commented = commented_lines.include?(idx)
        separator = commented ? "\u2503" : "\u2502"
        sep_attr = commented ? Curses.color_pair(4) : color_for(:file_header)
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
        commented = hunk_commented?(hunk_idx) ? " [commented]" : ""
        status = " Hunk #{hunk_idx + 1}/#{hunk_offsets.size}#{commented} | #{percent}% "
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
      when :file_header then Curses.color_pair(3) | Curses::A_BOLD
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
      Curses.lines - 2
    end

    def gutter_width
      @gutter_width ||= begin
        max = @lines.filter_map(&:lineno).max || 1
        max.to_s.length
      end
    end

    def handle_input
      key = Curses.getch
      case key
      when "q", 27 then return false
      when "j" then scroll(1)
      when "k" then scroll(-1)
      when 6 then scroll(scroll_height)
      when 2 then scroll(-scroll_height)
      when 4 then scroll(scroll_height / 2)
      when 21 then scroll(-scroll_height / 2)
      when "n", 14 then jump_hunk(1)
      when "p", 16 then jump_hunk(-1)
      when "c" then annotate_hunk
      when "?" then show_help
      end
      true
    end

    HELP_KEYS = [
      ["j", "Scroll down"],
      ["k", "Scroll up"],
      ["C-f", "Page down"],
      ["C-b", "Page up"],
      ["C-d", "Half page down"],
      ["C-u", "Half page up"],
      ["n / C-n", "Next hunk"],
      ["p / C-p", "Previous hunk"],
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
        win.addstr("\u250C#{"\u2500" * (width - 2)}\u2510")

        win.setpos(top + 1, left)
        pad = width - 2 - title.length
        win.addstr("\u2502#{" " * (pad / 2)}#{title}#{" " * (pad - pad / 2)}\u2502")

        win.setpos(top + 2, left)
        win.addstr("\u251C#{"\u2500" * (width - 2)}\u2524")

        content_lines.each_with_index do |line, i|
          win.setpos(top + 3 + i, left)
          win.addstr("\u2502  #{line.ljust(width - 5)} \u2502")
        end

        win.setpos(top + height - 1, left)
        win.addstr("\u2514#{"\u2500" * (width - 2)}\u2518")
      end
    end

    def annotate_hunk
      file, hunk = current_hunk_entry
      return unless hunk
      comment = prompt_comment("Comment on hunk")
      return unless comment
      @annotations << Annotation.new(
        file_path: file.path,
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

    def current_hunk_entry
      @hunk_entries[hunk_idx] || [nil, nil]
    end

    attr_reader :hunk_offsets

    def hunk_end_offset(idx)
      (idx + 1 < hunk_offsets.size) ? hunk_offsets[idx + 1] : lines.size
    end

    def hunk_commented?(hunk_index)
      file, hunk = @hunk_entries[hunk_index]
      return false unless file
      annotations.any? { |a| a.file_path == file.path && a.hunk.equal?(hunk) }
    end

    def commented_hunk_lines
      hunk_offsets.each_with_index.each_with_object(Set.new) do |(offset, hunk_index), set|
        next unless hunk_commented?(hunk_index)
        (offset...hunk_end_offset(hunk_index)).each { |i| set << i }
      end
    end

    def scroll(delta)
      max = [0, lines.size - scroll_height].max
      self.offset = (offset + delta).clamp(0, max)
      sync_hunk_to_offset
    end

    def sync_hunk_to_offset
      return if hunk_offsets.empty?
      self.hunk_idx = hunk_offsets.rindex { |o| o <= offset } || 0
    end

    def jump_hunk(delta)
      return if hunk_offsets.empty?
      self.hunk_idx = (hunk_idx + delta).clamp(0, hunk_offsets.size - 1)
      target = hunk_offsets[hunk_idx]
      margin = [2, scroll_height / 4].min
      max = [0, lines.size - scroll_height].max
      self.offset = [target - margin, 0].max.clamp(0, max)
    end
  end
end
