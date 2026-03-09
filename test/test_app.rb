# frozen_string_literal: true

require "test_helper"

class TestApp < Minitest::Test
  def test_annotations_initially_empty
    app = Sight::App.new([make_file])
    assert_empty app.annotations
  end

  def test_hunk_idx_starts_at_zero
    app = Sight::App.new([make_file])
    assert_equal 0, app.hunk_idx
  end

  def test_flat_view_no_separator_for_first_file
    app = Sight::App.new([make_file])
    refute_equal :file_separator, app.lines[0].type
  end

  def test_flat_view_strips_prefix
    app = Sight::App.new([make_file])
    line = app.lines[0]
    assert_equal :add, line.type
    assert_equal "new", line.text
    assert_equal 1, line.lineno
  end

  def test_flat_view_keeps_meta_content
    meta = Sight::DiffLine.new(type: :meta, content: "@@ -1,3 +1,5 @@", lineno: nil)
    hunk = Sight::Hunk.new(context: "", lines: [meta])
    file = Sight::DiffFile.new(path: "m.rb", hunks: [hunk])
    app = Sight::App.new([file])
    assert_equal "@@ -1,3 +1,5 @@", app.lines[0].text
  end

  def test_flat_view_multiple_hunks
    app = Sight::App.new([make_multi_hunk_file])
    # 1 line (h1) + 2 lines (h2) = 3
    assert_equal 3, app.lines.size
  end

  def test_flat_view_multiple_files
    app = Sight::App.new([make_file, make_multi_hunk_file])
    # 1 line + separator + 1 line + 2 lines = 5
    assert_equal 5, app.lines.size
  end

  def test_flat_view_separator_between_files
    app = Sight::App.new([make_file, make_multi_hunk_file])
    assert_equal :file_separator, app.lines[1].type
  end

  def test_hunk_offsets
    app = Sight::App.new([make_multi_hunk_file])
    offsets = app.send(:hunk_offsets)
    assert_equal [0, 1], offsets
  end

  def test_hunk_offsets_span_files
    app = Sight::App.new([make_file, make_multi_hunk_file])
    offsets = app.send(:hunk_offsets)
    # hunk@0, separator(1), hunk@2, hunk@3
    assert_equal [0, 2, 3], offsets
  end

  def test_hunk_end_offset_middle
    app = Sight::App.new([make_multi_hunk_file])
    assert_equal 1, app.send(:hunk_end_offset, 0)
  end

  def test_hunk_end_offset_last
    app = Sight::App.new([make_multi_hunk_file])
    assert_equal 3, app.send(:hunk_end_offset, 1)
  end

  def test_jump_hunk_forward
    app = Sight::App.new([make_multi_hunk_file])
    stub_scroll_height(app, 100) do
      app.send(:jump_hunk, 1)
      assert_equal 1, app.hunk_idx
    end
  end

  def test_jump_hunk_clamps_at_end
    app = Sight::App.new([make_multi_hunk_file])
    stub_scroll_height(app, 100) do
      app.send(:jump_hunk, 10)
      assert_equal 1, app.hunk_idx
    end
  end

  def test_jump_hunk_clamps_at_start
    app = Sight::App.new([make_multi_hunk_file])
    stub_scroll_height(app, 100) do
      app.send(:jump_hunk, -5)
      assert_equal 0, app.hunk_idx
    end
  end

  def test_jump_hunk_sets_offset
    app = Sight::App.new([make_multi_hunk_file])
    stub_scroll_height(app, 100) do
      app.send(:jump_hunk, 1)
      assert_equal 0, app.offset
    end
  end

  def test_jump_hunk_across_files
    app = Sight::App.new([make_file, make_file])
    stub_scroll_height(app, 100) do
      app.send(:jump_hunk, 1)
      assert_equal 1, app.hunk_idx
    end
  end

  def test_scroll_syncs_hunk_idx
    app = Sight::App.new([make_file, make_multi_hunk_file])
    stub_scroll_height(app, 2) do
      # hunks at offsets [0, 2, 3]; scroll past separator
      app.send(:scroll, 2)
      assert_equal 1, app.hunk_idx
    end
  end

  def test_scroll_forward
    app = Sight::App.new([make_long_file(20)])
    stub_scroll_height(app, 10) do
      app.send(:scroll, 5)
      assert_equal 5, app.offset
    end
  end

  def test_scroll_clamps_at_bottom
    app = Sight::App.new([make_long_file(20)])
    stub_scroll_height(app, 10) do
      app.send(:scroll, 100)
      assert_equal 10, app.offset
    end
  end

  def test_scroll_clamps_at_top
    app = Sight::App.new([make_long_file(20)])
    stub_scroll_height(app, 10) do
      app.offset = 5
      app.send(:scroll, -100)
      assert_equal 0, app.offset
    end
  end

  def test_format_gutter_with_lineno
    app = Sight::App.new([make_file])
    assert_equal "  5", app.send(:format_gutter, :add, 5, 3)
  end

  def test_format_gutter_del_without_lineno
    app = Sight::App.new([make_file])
    assert_equal "  ~", app.send(:format_gutter, :del, nil, 3)
  end

  def test_hunk_commented_false_when_no_annotations
    app = Sight::App.new([make_multi_hunk_file])
    refute app.send(:hunk_commented?, 0)
  end

  def test_hunk_commented_true_when_annotated
    file = make_multi_hunk_file
    app = Sight::App.new([file])
    app.annotations << Sight::Annotation.new(
      file_path: file.path, type: :hunk, hunk: file.hunks[1], comment: "fix this"
    )
    refute app.send(:hunk_commented?, 0)
    assert app.send(:hunk_commented?, 1)
  end

  def test_commented_hunk_lines_empty
    app = Sight::App.new([make_multi_hunk_file])
    assert_empty app.send(:commented_hunk_lines)
  end

  def test_commented_hunk_lines_with_annotation
    file = make_multi_hunk_file
    app = Sight::App.new([file])
    app.annotations << Sight::Annotation.new(
      file_path: file.path, type: :hunk, hunk: file.hunks[1], comment: "fix"
    )
    result = app.send(:commented_hunk_lines)
    assert_instance_of Set, result
    assert_equal Set[1, 2], result
  end

  def test_format_gutter_other_without_lineno
    app = Sight::App.new([make_file])
    assert_equal "   ", app.send(:format_gutter, :ctx, nil, 3)
  end

  private

  def make_file
    hunk = Sight::Hunk.new(context: "def foo", lines: [
      Sight::DiffLine.new(type: :add, content: "+new", lineno: 1)
    ])
    Sight::DiffFile.new(path: "test.rb", hunks: [hunk])
  end

  def make_multi_hunk_file
    h1 = Sight::Hunk.new(context: "def foo", lines: [
      Sight::DiffLine.new(type: :add, content: "+a", lineno: 1)
    ])
    h2 = Sight::Hunk.new(context: "def bar", lines: [
      Sight::DiffLine.new(type: :del, content: "-b", lineno: nil, old_lineno: 10),
      Sight::DiffLine.new(type: :add, content: "+c", lineno: 10)
    ])
    Sight::DiffFile.new(path: "multi.rb", hunks: [h1, h2])
  end

  def make_long_file(n)
    lines = n.times.map { |i|
      Sight::DiffLine.new(type: :add, content: "+line#{i}", lineno: i + 1)
    }
    hunk = Sight::Hunk.new(context: "long", lines: lines)
    Sight::DiffFile.new(path: "long.rb", hunks: [hunk])
  end

  def stub_scroll_height(app, height)
    app.define_singleton_method(:scroll_height) { height }
    yield
  end
end
