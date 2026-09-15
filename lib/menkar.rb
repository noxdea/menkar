# frozen_string_literal: true

require_relative "menkar/version"

module Menkar
  class Error < StandardError; end

  module Value
    module_function

    def define(*members)
      return Data.define(*members) if defined?(Data)

      Struct.new(*members) do
        members.each { |member| undef_method("#{member}=") }

        def initialize(*values, **keywords)
          if keywords.empty?
            raise ArgumentError, "wrong number of arguments" unless values.length == self.class.members.length

            super(*values)
          else
            raise ArgumentError, "cannot mix positional and keyword arguments" unless values.empty?

            missing = self.class.members - keywords.keys
            unknown = keywords.keys - self.class.members
            raise ArgumentError, "missing keyword: #{missing.first.inspect}" unless missing.empty?
            raise ArgumentError, "unknown keyword: #{unknown.first.inspect}" unless unknown.empty?

            super(*self.class.members.map { |member| keywords.fetch(member) })
          end
          freeze
        end

        def with(**changes)
          return self if changes.empty?

          unknown = changes.keys - self.class.members
          raise ArgumentError, "unknown keyword: #{unknown.first.inspect}" unless unknown.empty?

          self.class.new(**to_h.merge(changes))
        end
      end
    end
  end

  Detection = Value.define(:encoding, :confidence, :bom, :newline, :indent, :binary)
  Indent = Value.define(:style, :width)
  private_constant :Value

  def self.newline_kind(text)
    crlf = text.scan(/\r\n/).length
    rest = text.gsub(/\r\n/, "")
    kinds = []
    kinds << :crlf if crlf.positive?
    kinds << :lf if rest.include?("\n")
    kinds << :cr if rest.include?("\r")
    return :none if kinds.empty?

    kinds.one? ? kinds.first : :mixed
  end
  private_class_method :newline_kind
end

require_relative "menkar/encoding_scorer"
require_relative "menkar/detector"
require_relative "menkar/transcoder"

module Menkar
  private_constant :BOMS, :SUPPORTED_ENCODINGS, :NEWLINES, :EncodingScorer
end
