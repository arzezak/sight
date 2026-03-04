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

  private

  def make_file
    hunk = Sight::Hunk.new(context: "def foo", lines: [
      Sight::DiffLine.new(type: :add, content: "+new", lineno: 1)
    ])
    Sight::DiffFile.new(path: "test.rb", hunks: [hunk])
  end
end
