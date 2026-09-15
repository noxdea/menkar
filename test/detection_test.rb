# frozen_string_literal: true

require "tempfile"
require_relative "test_helper"

class DetectionTest < Minitest::Test
  BOMS = {
    Encoding::UTF_8 => "\xEF\xBB\xBF".b,
    Encoding::UTF_16LE => "\xFF\xFE".b,
    Encoding::UTF_16BE => "\xFE\xFF".b,
    Encoding::UTF_32LE => "\xFF\xFE\x00\x00".b,
    Encoding::UTF_32BE => "\x00\x00\xFE\xFF".b
  }.freeze

  def test_bom_wins_and_longest_bom_is_matched_first
    BOMS.each do |encoding, bom|
      bytes = bom + "alpha\r\nbeta\r\n".encode(encoding).b
      result = Menkar.detect(bytes, hint: "EUC-JP")
      assert_equal encoding, result.encoding
      assert_equal bom, result.bom
      assert_equal 1.0, result.confidence
      assert_equal :crlf, result.newline
      refute result.binary
    end
  end

  def test_nul_distribution_distinguishes_bomless_utf16_and_utf32
    [Encoding::UTF_16LE, Encoding::UTF_16BE, Encoding::UTF_32LE, Encoding::UTF_32BE].each do |encoding|
      result = Menkar.detect("plain text\nsecond line\n".encode(encoding).b)
      assert_equal encoding, result.encoding
      refute result.binary
    end
  end

  def test_binary_detection_does_not_reject_unicode_boms
    assert Menkar.binary?("\x00\x01\x02\x03".b * 20)
    assert Menkar.detect("\x00\x01\x02\x03".b * 20).binary
    refute Menkar.binary?("\xFF\xFEa\x00".b)
  end

  def test_arbitrary_bytes_are_safely_classified
    random = Random.new(12_345)
    256.times do
      bytes = random.bytes(random.rand(0..512))
      result = Menkar.detect(bytes)
      assert_includes [true, false], result.binary
      assert_operator result.confidence, :>=, 0.0
      assert_operator result.confidence, :<=, 1.0
    end
  end

  def test_utf8_ascii_hint_newlines_and_indentation
    text = "root\n    one\n        two\n"
    result = Menkar.detect(text)
    assert_equal Encoding::UTF_8, result.encoding
    assert_equal 0.5, result.confidence
    assert_equal :lf, result.newline
    assert_equal [:space, 4], [result.indent.style, result.indent.width]

    hinted = Menkar.detect(text, hint: {encoding: "Shift_JIS"})
    assert_equal Encoding::Windows_31J, hinted.encoding
  end

  def test_mixed_newlines_tabs_and_short_text
    result = Menkar.detect("x\r\n\tone\ry\n")
    assert_equal :mixed, result.newline
    assert_equal [:tab, nil], [result.indent.style, result.indent.width]
    refute Menkar.detect("one line\n").binary
  end

  def test_detect_file_is_bounded
    Tempfile.create("menkar") do |file|
      file.binmode
      file.write("a" * 100_000)
      file.flush
      assert_equal Encoding::UTF_8, Menkar.detect_file(file.path, sample: 4096).encoding
    end
  end

  def test_invalid_inputs_are_rejected
    assert_raises(Menkar::Error) { Menkar.detect(nil) }
    assert_raises(Menkar::Error) { Menkar.detect("x", sample: 3) }
    assert_raises(Menkar::Error) { Menkar.detect("x", sample: Menkar::MAX_SAMPLE + 1) }
    assert_raises(Menkar::Error) { Menkar.detect("x", hint: "not-an-encoding") }
    assert_raises(Menkar::Error) { Menkar.detect("x", hint: "US-ASCII") }
    assert_raises(Menkar::Error) { Menkar.detect_file("bad\0path") }
  end

  def test_value_objects_are_immutable_on_all_supported_rubies
    detection = Menkar.detect("text")
    assert_predicate detection, :frozen?
    refute_respond_to detection, :encoding=
    assert_same detection, detection.with
  end
end
