# frozen_string_literal: true

require 'strscan'

class Parselly
  VERSION = "0.1.0"

  def self.sanitize(selector)
    scanner = StringScanner.new(selector)
    result = +''

    # Special case: if the selector is of length 1 and
    # the first character is `-`
    if selector.length == 1 && scanner.peek(1) == '-'
      return "\\#{selector}"
    end

    until scanner.eos?
      # NULL character (U+0000)
      if scanner.scan(/\0/)
        result << "\uFFFD"
      # Control characters (U+0001 to U+001F, U+007F)
      elsif scanner.scan(/[\x01-\x1F\x7F]/)
        result << escaped_hex(scanner.matched)
      # First character is a digit (U+0030 to U+0039)
      elsif scanner.pos.zero? && scanner.scan(/\d/)
        result << escaped_hex(scanner.matched)
      # Second character is a digit and first is `-`
      elsif scanner.pos == 1 && scanner.scan(/\d/) &&
          scanner.pre_match == '-'
        result << escaped_hex(scanner.matched)
      # Alphanumeric characters, `-`, `_`
      elsif scanner.scan(/[a-zA-Z0-9\-_]/)
        result << scanner.matched
      # Any other characters, escape them
      elsif scanner.scan(/./)
        result << "\\#{scanner.matched}"
      end
    end

    result
  end

  def self.escaped_hex(char)
    "\\#{char.ord.to_s(16)} "
  end
  private_class_method :escaped_hex
end
