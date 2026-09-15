# frozen_string_literal: true

require_relative "test_helper"

class TranscodingTest < Minitest::Test
  def test_decode_and_encode_restore_encoding_bom_and_newlines
    [
      [Encoding::UTF_8, "\xEF\xBB\xBF".b],
      [Encoding::UTF_16LE, "\xFF\xFE".b],
      [Encoding::UTF_16BE, "\xFE\xFF".b],
      [Encoding::Windows_31J, "".b],
      [Encoding::EUC_JP, "".b]
    ].each do |encoding, bom|
      original = bom + "日本\r\n  本文\r\n".encode(encoding).b
      detection = Menkar.detect(original, hint: encoding)
      text = Menkar.decode(original, detection)
      assert_equal "日本\r\n  本文\r\n", text
      assert_equal Encoding::UTF_8, text.encoding
      assert_equal original, Menkar.encode(text, detection)
      assert Menkar.roundtrip?(original, detection)
    end
  end

  def test_unrepresentable_edited_text_is_not_roundtrippable
    original = "日本".encode(Encoding::Windows_31J).b
    detection = Menkar.detect(original, hint: Encoding::Windows_31J)
    refute Menkar.roundtrip?("日本😀", detection)
    assert_raises(Menkar::Error) { Menkar.encode("日本😀", detection) }
  end

  def test_invalid_source_and_stale_bom_are_rejected
    detection = Menkar.detect("\xEF\xBB\xBFok".b)
    assert_raises(Menkar::Error) { Menkar.decode("ok".b, detection) }

    invalid = Menkar::Detection.new(Encoding::UTF_8, 0.5, "".b.freeze, :none, nil, false)
    assert_raises(Menkar::Error) { Menkar.decode("\xFF".b, invalid) }

    unsupported = invalid.with(encoding: Encoding::ISO_8859_1)
    assert_raises(Menkar::Error) { Menkar.decode("ok".b, unsupported) }
    wrong_bom = invalid.with(bom: "\xFF\xFE".b)
    assert_raises(Menkar::Error) { Menkar.decode("\xFF\xFEo\x00k\x00".b, wrong_bom) }
  end

  def test_binary_detection_cannot_be_transcoded
    detection = Menkar.detect("\x00\x01\x02\x03".b * 20)
    assert_raises(Menkar::Error) { Menkar.decode("anything", detection) }
    assert_raises(Menkar::Error) { Menkar.encode("anything", detection) }
    refute Menkar.roundtrip?("anything", detection)
  end

  def test_normalize_newlines_reports_original_form
    normalized, original = Menkar.normalize_newlines("a\r\nb\rc\n", to: :lf)
    assert_equal ["a\nb\nc\n", :mixed], [normalized, original]
    assert_equal ["a\r\nb\r\n", :lf], Menkar.normalize_newlines("a\nb\n", to: :crlf)
    assert_raises(Menkar::Error) { Menkar.normalize_newlines("x", to: :native) }
  end
end
