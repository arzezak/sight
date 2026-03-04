# frozen_string_literal: true

require "test_helper"

class TestAnnotationFormatter < Minitest::Test
  def test_empty
    assert_equal "", Sight::AnnotationFormatter.format([])
  end

  def test_hunk_annotation
    ann = make_annotation("foo.rb", "looks good")
    out = Sight::AnnotationFormatter.format([ann])

    assert_includes out, "## File: foo.rb"
    assert_includes out, "```diff"
    assert_includes out, "> looks good"
  end

  def test_only_changed_lines
    hunk = Sight::Hunk.new(context: "def foo", lines: [
      Sight::DiffLine.new(type: :ctx, content: " unchanged", lineno: 1),
      Sight::DiffLine.new(type: :del, content: "-old", lineno: nil),
      Sight::DiffLine.new(type: :add, content: "+new", lineno: 2)
    ])
    ann = Sight::Annotation.new(file_path: "bar.rb", type: :hunk, hunk: hunk, comment: "ok")
    out = Sight::AnnotationFormatter.format([ann])

    assert_includes out, "-old"
    assert_includes out, "+new"
    refute_includes out, " unchanged"
  end

  def test_multiple_annotations_same_file
    a1 = make_annotation("foo.rb", "first")
    a2 = make_annotation("foo.rb", "second")
    out = Sight::AnnotationFormatter.format([a1, a2])

    assert_equal 1, out.scan("## File: foo.rb").size
    assert_includes out, "> first"
    assert_includes out, "> second"
  end

  def test_multiple_files
    a1 = make_annotation("foo.rb", "comment1")
    a2 = make_annotation("bar.rb", "comment2")
    out = Sight::AnnotationFormatter.format([a1, a2])

    assert_includes out, "## File: foo.rb"
    assert_includes out, "## File: bar.rb"
  end

  private

  def make_annotation(path, comment)
    hunk = Sight::Hunk.new(context: "def example", lines: [
      Sight::DiffLine.new(type: :del, content: "-old", lineno: nil),
      Sight::DiffLine.new(type: :add, content: "+new", lineno: 1)
    ])
    Sight::Annotation.new(file_path: path, type: :hunk, hunk: hunk, comment: comment)
  end
end
