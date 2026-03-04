# frozen_string_literal: true

require "test_helper"

class TestDiffParser < Minitest::Test
  SAMPLE_DIFF = <<~DIFF
    diff --git a/file1.rb b/file1.rb
    index abc1234..def5678 100644
    --- a/file1.rb
    +++ b/file1.rb
    @@ -1,3 +1,4 @@
     unchanged
    -old line
    +new line
    +added line
    diff --git a/file2.rb b/file2.rb
    new file mode 100644
    --- /dev/null
    +++ b/file2.rb
    @@ -0,0 +1,2 @@
    +first
    +second
  DIFF

  def setup
    @files = Sight::DiffParser.parse(SAMPLE_DIFF)
  end

  def test_parses_correct_number_of_files
    assert_equal 2, @files.size
  end

  def test_file_path
    assert_equal "file1.rb", @files[0].path
    assert_equal "file2.rb", @files[1].path
  end

  def test_hunk_count
    assert_equal 1, @files[0].hunks.size
    assert_equal 1, @files[1].hunks.size
  end

  def test_hunk_context_nil_when_absent
    assert_nil @files[0].hunks[0].context
  end

  def test_line_types
    lines = @files[0].hunks[0].lines
    assert_equal :ctx, lines[0].type
    assert_equal :del, lines[1].type
    assert_equal :add, lines[2].type
    assert_equal :add, lines[3].type
  end

  def test_line_content
    lines = @files[0].hunks[0].lines
    assert_equal " unchanged", lines[0].content
    assert_equal "-old line", lines[1].content
    assert_equal "+new line", lines[2].content
  end

  def test_new_file
    f = @files[1]
    assert_equal "file2.rb", f.path
    assert_equal 2, f.hunks[0].lines.size
    assert(f.hunks[0].lines.all? { |l| l.type == :add })
  end

  def test_empty_input
    assert_equal [], Sight::DiffParser.parse("")
  end
end
