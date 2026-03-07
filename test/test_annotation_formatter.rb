# frozen_string_literal: true

require "test_helper"

class TestAnnotationFormatter < Minitest::Test
  def test_empty
    assert_equal "", Sight::AnnotationFormatter.format([])
  end

  def test_hunk_annotation
    out = Sight::AnnotationFormatter.format([
      make_annotation("foo.rb", "looks good")
    ])

    assert_includes out, "## File: foo.rb"
    assert_includes out, "```diff"
    assert_includes out, "> looks good"
  end

  def test_only_changed_lines
    out = Sight::AnnotationFormatter.format([
      make_annotation("bar.rb", "ok", lines: [
        Sight::DiffLine.new(type: :ctx, content: " unchanged", lineno: 1),
        Sight::DiffLine.new(type: :del, content: "-old", lineno: nil),
        Sight::DiffLine.new(type: :add, content: "+new", lineno: 2)
      ])
    ])

    assert_includes out, "-old"
    assert_includes out, "+new"
    refute_includes out, " unchanged"
  end

  def test_multiple_annotations_same_file
    out = Sight::AnnotationFormatter.format([
      make_annotation("foo.rb", "first"),
      make_annotation("foo.rb", "second")
    ])

    assert_equal 1, out.scan("## File: foo.rb").size
    assert_includes out, "> first"
    assert_includes out, "> second"
  end

  def test_multiple_files
    out = Sight::AnnotationFormatter.format([
      make_annotation("foo.rb", "comment1"),
      make_annotation("bar.rb", "comment2")
    ])

    assert_includes out, "## File: foo.rb"
    assert_includes out, "## File: bar.rb"
  end

  private

  def make_annotation(file_path, comment, lines: [
    Sight::DiffLine.new(type: :del, content: "-old", lineno: nil),
    Sight::DiffLine.new(type: :add, content: "+new", lineno: 1)
  ])
    Sight::Annotation.new(
      file_path:,
      type: :hunk,
      hunk: Sight::Hunk.new(context: "def example", lines:),
      comment:
    )
  end
end
