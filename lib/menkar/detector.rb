# frozen_string_literal: true

module Menkar
  DEFAULT_SAMPLE = 64 * 1024
  MAX_SAMPLE = 16 * 1024 * 1024

  BOMS = [
    ["\xFF\xFE\x00\x00".b.freeze, Encoding::UTF_32LE],
    ["\x00\x00\xFE\xFF".b.freeze, Encoding::UTF_32BE],
    ["\xEF\xBB\xBF".b.freeze, Encoding::UTF_8],
    ["\xFF\xFE".b.freeze, Encoding::UTF_16LE],
    ["\xFE\xFF".b.freeze, Encoding::UTF_16BE]
  ].freeze

  SUPPORTED_ENCODINGS = ([Encoding::UTF_8, Encoding::UTF_16LE, Encoding::UTF_16BE,
    Encoding::UTF_32LE, Encoding::UTF_32BE] + EncodingScorer.encodings).freeze

  module_function

  def detect(bytes, hint: nil, sample: DEFAULT_SAMPLE)
    validate_bytes!(bytes)
    limit = validate_sample!(sample)
    hint_encoding = normalize_hint(hint)
    chunk = (bytes.byteslice(0, limit) || "").b
    truncated = bytes.bytesize > chunk.bytesize
    bom, bom_encoding = BOMS.find { |mark, _encoding| chunk.start_with?(mark) }

    if bom_encoding
      text = EncodingScorer.decode(chunk.byteslice(bom.bytesize..) || "".b, bom_encoding, truncated: truncated)
      return detection(bom_encoding, 1.0, bom, text, binary: false)
    end

    if chunk.include?("\0")
      encoding, text = nul_encoding(chunk, truncated: truncated)
      return detection(encoding, 0.95, "".b.freeze, text, binary: false) if encoding

      return detection(nil, 1.0, "".b.freeze, nil, binary: true)
    end

    return detection(nil, 1.0, "".b.freeze, nil, binary: true) if binary_sample?(chunk)

    if chunk.match?(/\e\$(?:@|B)|\e\([BJ]/n)
      text = EncodingScorer.decode(chunk, Encoding::ISO_2022_JP, truncated: truncated)
      return detection(Encoding::ISO_2022_JP, 0.99, "".b.freeze, text, binary: false) if text
    end

    utf8 = EncodingScorer.decode(chunk, Encoding::UTF_8, truncated: truncated)
    if utf8
      if utf8.ascii_only? && hint_encoding && hint_encoding != Encoding::UTF_8
        return detection(hint_encoding, 0.6, "".b.freeze, utf8, binary: false)
      end
      return detection(Encoding::UTF_8, utf8.ascii_only? ? 0.5 : 0.9, "".b.freeze, utf8, binary: false)
    end

    encoding, confidence, text = EncodingScorer.legacy(chunk, hint_encoding, truncated: truncated)
    return detection(nil, 1.0, "".b.freeze, nil, binary: true) unless encoding

    detection(encoding, confidence, "".b.freeze, text, binary: false)
  end

  def detect_file(path, sample: DEFAULT_SAMPLE)
    limit = validate_sample!(sample)
    unless path.is_a?(String) && path.valid_encoding? && !path.include?("\0")
      raise Error, "path must be a valid String without NUL bytes"
    end

    bytes = File.open(path, "rb") { |file| file.read(limit + 1) || "".b }
    detect(bytes, sample: limit)
  rescue SystemCallError => error
    raise Error, "cannot read #{path}: #{error.message}"
  end

  def binary?(bytes)
    detect(bytes).binary
  end

  def detection(encoding, confidence, bom, text, binary:)
    Detection.new(encoding, confidence, bom, text && newline_kind(text), text && indent(text), binary)
  end
  private_class_method :detection

  def indent(text)
    prefixes = text.each_line.filter_map { |line| line[/\A[ \t]+(?=\S)/] }
    return nil if prefixes.empty?

    tabs = prefixes.count { |prefix| prefix.start_with?("\t") }
    spaces = prefixes.filter_map { |prefix| prefix[/\A +/]&.length }
    return Indent.new(:tab, nil) if tabs > spaces.length
    return nil if spaces.empty?

    widths = [2, 3, 4, 8]
    width = widths.max_by { |candidate| [spaces.count { |value| (value % candidate).zero? }.fdiv(spaces.length), candidate] }
    width = 1 if spaces.count { |value| (value % width).zero? }.fdiv(spaces.length) < 0.6
    Indent.new(:space, width)
  end
  private_class_method :indent

  def nul_encoding(bytes, truncated:)
    options = []
    if bytes.bytesize >= 4
      columns = 4.times.map { |offset| bytes.bytes.each_with_index.count { |byte, index| (index % 4) == offset && byte.zero? } }
      groups = bytes.bytesize / 4
      options << Encoding::UTF_32LE if columns[1..].all? { |count| count.fdiv(groups) > 0.6 }
      options << Encoding::UTF_32BE if columns[0, 3].all? { |count| count.fdiv(groups) > 0.6 }
    end
    if bytes.bytesize >= 2
      pairs = bytes.bytesize / 2
      even = bytes.bytes.each_with_index.count { |byte, index| index.even? && byte.zero? }.fdiv(pairs)
      odd = bytes.bytes.each_with_index.count { |byte, index| index.odd? && byte.zero? }.fdiv(pairs)
      options << Encoding::UTF_16LE if odd > 0.3 && even < 0.2
      options << Encoding::UTF_16BE if even > 0.3 && odd < 0.2
    end

    options.uniq.each do |encoding|
      text = EncodingScorer.decode(bytes, encoding, truncated: truncated)
      return [encoding, text] if text && EncodingScorer.textual?(text)
    end
    [nil, nil]
  end
  private_class_method :nul_encoding

  def binary_sample?(bytes)
    return false if bytes.empty?

    controls = bytes.each_byte.count { |byte| byte < 32 && ![9, 10, 12, 13, 27].include?(byte) }
    controls.fdiv(bytes.bytesize) > 0.3
  end
  private_class_method :binary_sample?

  def normalize_hint(hint)
    return nil if hint.nil?
    hint = hint[:encoding] || hint["encoding"] if hint.is_a?(Hash)
    encoding = hint.is_a?(Encoding) ? hint : Encoding.find(hint.to_s)
    encoding = Encoding::Windows_31J if encoding == Encoding::Shift_JIS
    raise Error, "unsupported encoding hint: #{hint}" unless SUPPORTED_ENCODINGS.include?(encoding)

    encoding
  rescue ArgumentError
    raise Error, "unknown encoding hint: #{hint}"
  end
  private_class_method :normalize_hint

  def validate_bytes!(bytes)
    raise Error, "bytes must be a String" unless bytes.is_a?(String)
  end
  private_class_method :validate_bytes!

  def validate_sample!(sample)
    raise Error, "sample must be an Integer between 4 and #{MAX_SAMPLE}" unless sample.is_a?(Integer) && sample.between?(4, MAX_SAMPLE)

    sample
  end
  private_class_method :validate_sample!
end
