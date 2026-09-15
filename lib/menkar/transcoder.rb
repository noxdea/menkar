# frozen_string_literal: true

module Menkar
  NEWLINES = {lf: "\n", crlf: "\r\n", cr: "\r"}.freeze

  module_function

  def decode(bytes, detection)
    validate_detection!(detection)
    raise Error, "cannot decode binary input" if detection.binary
    raise Error, "bytes must be a String" unless bytes.is_a?(String)

    source = bytes.b
    unless detection.bom.empty?
      raise Error, "input does not start with the detected BOM" unless source.start_with?(detection.bom)

      source = source.byteslice(detection.bom.bytesize..) || "".b
    end
    source.force_encoding(detection.encoding)
    raise Error, "invalid #{detection.encoding.name} input" unless source.valid_encoding?

    source.encode(Encoding::UTF_8)
  rescue EncodingError => error
    raise Error, "cannot decode #{detection.encoding.name}: #{error.message}"
  end

  def encode(string, detection)
    validate_detection!(detection)
    raise Error, "cannot encode binary input" if detection.binary
    raise Error, "string must be valid text" unless string.is_a?(String) && string.valid_encoding?

    utf8 = string.encode(Encoding::UTF_8)
    detection.bom + utf8.encode(detection.encoding).b
  rescue EncodingError => error
    raise Error, "cannot encode #{detection.encoding.name}: #{error.message}"
  end

  def roundtrip?(value, detection)
    return false unless value.is_a?(String)

    if value.encoding == Encoding::UTF_8 && value.valid_encoding?
      decode(encode(value, detection), detection) == value
    else
      encode(decode(value, detection), detection) == value.b
    end
  rescue Error
    false
  end

  def normalize_newlines(string, to: :lf)
    raise Error, "string must be valid text" unless string.is_a?(String) && string.valid_encoding?
    replacement = NEWLINES.fetch(to) { raise Error, "newline must be :lf, :crlf, or :cr" }
    utf8 = string.encode(Encoding::UTF_8)
    original = newline_kind(utf8)
    [utf8.gsub(/\r\n|\r|\n/, replacement), original]
  end

  def validate_detection!(detection)
    unless detection.is_a?(Detection) && (detection.encoding.nil? || SUPPORTED_ENCODINGS.include?(detection.encoding)) &&
        detection.confidence.is_a?(Float) && detection.confidence.finite? && detection.confidence.between?(0.0, 1.0) &&
        detection.bom.is_a?(String) && detection.bom.encoding == Encoding::BINARY &&
        [:lf, :crlf, :cr, :mixed, :none, nil].include?(detection.newline) &&
        (detection.indent.nil? || detection.indent.is_a?(Indent)) &&
        detection.binary == !!detection.binary
      raise Error, "invalid detection"
    end
    raise Error, "text detection requires an encoding" if !detection.binary && detection.encoding.nil?
    raise Error, "binary detection cannot specify text metadata" if detection.binary && (detection.encoding || !detection.bom.empty?)
    if !detection.bom.empty? && !BOMS.include?([detection.bom, detection.encoding])
      raise Error, "BOM does not match the detected encoding"
    end
  end
  private_class_method :validate_detection!
end
