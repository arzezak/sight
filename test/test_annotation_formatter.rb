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

  def test_summary_single
    assert_equal "1 annotation on 1 file",
      Sight::AnnotationFormatter.summary([make_annotation("foo.rb", "ok")])
  end

  def test_summary_plural
    annotations = [
      make_annotation("foo.rb", "first"),
      make_annotation("foo.rb", "second"),
      make_annotation("bar.rb", "third")
    ]
    assert_equal "3 annotations on 2 files",
      Sight::AnnotationFormatter.summary(annotations)
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
