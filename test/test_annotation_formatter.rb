# frozen_string_literal: true

require "test_helper"

class TestAnnotationFormatter < Minitest::Test
  def test_empty
    assert_equal "", Sight::AnnotationFormatter.new([]).format
  end

  def test_hunk_annotation
    formatter = Sight::AnnotationFormatter.new(
      [make_annotation("foo.rb", "looks good")]
    )

    assert_includes formatter.format, "## File: foo.rb"
    assert_includes formatter.format, "```diff"
    assert_includes formatter.format, "> looks good"
  end

  def test_only_changed_lines
    formatter = Sight::AnnotationFormatter.new([
      make_annotation("bar.rb", "ok", lines: [
        Sight::DiffLine.new(type: :ctx, content: " unchanged", lineno: 1),
        Sight::DiffLine.new(type: :del, content: "-old", lineno: nil),
        Sight::DiffLine.new(type: :add, content: "+new", lineno: 2)
      ])
    ])

    assert_includes formatter.format, "-old"
    assert_includes formatter.format, "+new"
    refute_includes formatter.format, " unchanged"
  end

  def test_multiple_annotations_same_file
    formatter = Sight::AnnotationFormatter.new([
      make_annotation("foo.rb", "first"),
      make_annotation("foo.rb", "second")
    ])

    assert_equal 1, formatter.format.scan("## File: foo.rb").size
    assert_includes formatter.format, "> first"
    assert_includes formatter.format, "> second"
  end

  def test_multiple_files
    formatter = Sight::AnnotationFormatter.new([
      make_annotation("foo.rb", "comment1"),
      make_annotation("bar.rb", "comment2")
    ])

    assert_includes formatter.format, "## File: foo.rb"
    assert_includes formatter.format, "## File: bar.rb"
  end

  def test_summary_single
    formatter = Sight::AnnotationFormatter.new(
      [make_annotation("foo.rb", "ok")]
    )

    assert_equal "1 annotation on 1 file", formatter.summary
  end

  def test_summary_plural
    formatter = Sight::AnnotationFormatter.new([
      make_annotation("foo.rb", "first"),
      make_annotation("foo.rb", "second"),
      make_annotation("bar.rb", "third")
    ])

    assert_equal "3 annotations on 2 files", formatter.summary
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
