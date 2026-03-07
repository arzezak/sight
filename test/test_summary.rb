# frozen_string_literal: true

require "test_helper"

class TestSummary < Minitest::Test
  def test_single
    summary = Sight::Summary.new(
      [make_annotation("foo.rb", "ok")]
    )

    assert_equal "1 annotation on 1 file", summary.to_s
  end

  def test_plural
    summary = Sight::Summary.new([
      make_annotation("foo.rb", "first"),
      make_annotation("foo.rb", "second"),
      make_annotation("bar.rb", "third")
    ])

    assert_equal "3 annotations on 2 files", summary.to_s
  end

  private

  def make_annotation(file_path, comment)
    Sight::Annotation.new(
      file_path:,
      type: :hunk,
      hunk: Sight::Hunk.new(context: "def example", lines: [
        Sight::DiffLine.new(type: :add, content: "+new", lineno: 1)
      ]),
      comment:
    )
  end
end
