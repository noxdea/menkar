# frozen_string_literal: true

module Menkar
  module EncodingScorer
    CANDIDATES = [
      [Encoding::Windows_31J, :japanese],
      [Encoding::EUC_JP, :japanese],
      [Encoding::ISO_2022_JP, :japanese],
      [Encoding::GBK, :simplified_chinese],
      [Encoding::Big5, :traditional_chinese],
      [Encoding::EUC_KR, :korean],
      [Encoding::Windows_1252, :western]
    ].freeze

    COMMON = {
      japanese: "のにをはがとでてし日本人一日年大中本時行見言生子上来国私",
      simplified_chinese: "的一是不了在人有我他这中大来上国个们为时会后发里",
      traditional_chinese: "的一是不了在人有我他這中大來上國個們為時會後發裡",
      korean: "이다는을를에의가이은한하로있것수나그되사",
      western: "etaoinshrdlucmETAOINSHRDLUCM"
    }.transform_values(&:freeze).freeze

    module_function

    def encodings = CANDIDATES.map(&:first)

    def legacy(bytes, hint, truncated:)
      scored = []
      CANDIDATES.each do |encoding, language|
        text = decode(bytes, encoding, truncated: truncated)
        next unless text && textual?(text)

        score = language_score(text, language)
        score += 0.35 if encoding == hint
        return [encoding, confidence(score), text] if language == :japanese && score >= 1.8

        scored << [score, encoding, text]
      end
      return [nil, nil, nil] if scored.empty?

      score, encoding, text = scored.max_by(&:first)
      [encoding, confidence(score), text]
    end

    def decode(bytes, encoding, truncated:)
      cuts = truncated ? 0..[4, bytes.bytesize].min : 0..0
      cuts.each do |cut|
        source = bytes.byteslice(0, bytes.bytesize - cut).dup.force_encoding(encoding)
        next unless source.valid_encoding?

        return source.encode(Encoding::UTF_8)
      rescue EncodingError
        next
      end
      nil
    end

    def textual?(text)
      return true if text.empty?
      return false if text.include?("\0")

      text.scan(/[\x00-\x08\x0B\x0E-\x1F]/).length.fdiv(text.length) < 0.05
    end

    def confidence(score)
      [[0.5 + (score * 0.18), 0.99].min, 0.5].max
    end
    private_class_method :confidence

    def language_score(text, language)
      total = text.count(language == :western ? "^ \t\r\n\f\v" : "^\x00-\x7F")
      return 0.0 if total.zero?

      ratio = ->(characters) { text.count(characters).fdiv(total) }
      common = text.count(COMMON.fetch(language)).fdiv(total)

      case language
      when :japanese
        0.2 + ratio.call("\u3040-\u30FF") * 3.1 + ratio.call("\uFF61-\uFF9F") * 0.6 +
          ratio.call("\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF\u{20000}-\u{2FA1F}") * 0.35 + common * 0.8
      when :simplified_chinese, :traditional_chinese
        0.2 + ratio.call("\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF\u{20000}-\u{2FA1F}") * 1.2 + common * 1.1
      when :korean
        0.2 + ratio.call("\u1100-\u11FF\u3130-\u318F\uA960-\uA97F\uAC00-\uD7AF\uD7B0-\uD7FF") * 1.5 + common
      else
        0.2 + ratio.call("A-Za-z\u00C0-\u024F\u1E00-\u1EFF") * 1.2 + common * 0.6
      end
    end
    private_class_method :language_score
  end
end
