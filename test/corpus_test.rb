# frozen_string_literal: true

require_relative "test_helper"

class CorpusTest < Minitest::Test
  EXPECTED = {
    "windows_31j" => Encoding::Windows_31J,
    "euc_jp" => Encoding::EUC_JP,
    "iso_2022_jp" => Encoding::ISO_2022_JP,
    "windows_1252" => Encoding::Windows_1252,
    "gbk" => Encoding::GBK,
    "big5" => Encoding::Big5,
    "euc_kr" => Encoding::EUC_KR
  }.freeze

  def test_public_domain_corpus_accuracy
    scores = EXPECTED.to_h do |directory, encoding|
      fixtures = Dir[File.join(__dir__, "fixtures/corpus", directory, "*.txt")]
      correct = fixtures.count { |path| Menkar.detect(File.binread(path)).encoding == encoding }
      [directory, [correct, fixtures.length]]
    end

    japanese_names = %w[windows_31j euc_jp iso_2022_jp]
    other_names = %w[windows_1252 gbk big5 euc_kr]
    japanese = japanese_names.sum { |name| scores.fetch(name).first }
    japanese_total = japanese_names.sum { |name| scores.fetch(name).last }
    other = other_names.sum { |name| scores.fetch(name).first }
    other_total = other_names.sum { |name| scores.fetch(name).last }

    assert_operator japanese.fdiv(japanese_total), :>=, 0.98, scores.inspect
    assert_operator other.fdiv(other_total), :>=, 0.90, scores.inspect
  end
end
