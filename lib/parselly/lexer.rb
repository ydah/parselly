# frozen_string_literal: true

require 'strscan'

module Parselly
  class Lexer
    Identifier = Struct.new(:value, :raw) do
      attr_accessor :position

      def to_s
        value
      end

      def ==(other)
        other.respond_to?(:value) ? value == other.value : value == other
      end
    end

    TokenValue = Struct.new(:value, :raw, :position, :quote, keyword_init: true) do
      def to_s
        value.to_s
      end

      def ==(other)
        other.respond_to?(:value) ? value == other.value : value == other
      end
    end

    Token = Struct.new(:type, :value, :position, keyword_init: true) do
      def [](index)
        to_ary[index]
      end

      def []=(index, new_value)
        case index
        when 0
          self.type = new_value
        when 1
          self.value = new_value
        when 2
          self.position = new_value
        else
          raise IndexError, "index #{index} outside of token"
        end
      end

      def first
        type
      end

      def last
        position
      end

      def to_ary
        [type, value, position]
      end

      alias to_a to_ary

      def ==(other)
        return super unless other.respond_to?(:to_ary)

        other_type, other_value, other_position = other.to_ary
        return false unless type == other_type
        return false unless value == other_value
        return position == other_position unless position.is_a?(Hash) && other_position.is_a?(Hash)

        other_position.all? { |key, expected| position[key] == expected }
      end
    end

    TOKENS = {
      # Namespace and column combinators
      '|' => :PIPE,
      '||' => :COLUMN,

      # Combinators
      '>' => :CHILD,
      '+' => :ADJACENT,
      '~' => :SIBLING,

      # Delimiters
      '[' => :LBRACKET,
      ']' => :RBRACKET,
      '(' => :LPAREN,
      ')' => :RPAREN,
      ':' => :COLON,
      ',' => :COMMA,
      '.' => :DOT,
      '#' => :HASH,
      '*' => :STAR,
      '=' => :EQUAL,
      '-' => :MINUS,

      # Attribute operators
      '~=' => :INCLUDES,
      '|=' => :DASHMATCH,
      '^=' => :PREFIXMATCH,
      '$=' => :SUFFIXMATCH,
      '*=' => :SUBSTRINGMATCH
    }.freeze

    MULTI_CHAR_TOKENS = {
      '~=' => :INCLUDES,
      '|=' => :DASHMATCH,
      '^=' => :PREFIXMATCH,
      '$=' => :SUFFIXMATCH,
      '*=' => :SUBSTRINGMATCH,
      '||' => :COLUMN
    }.freeze

    SINGLE_CHAR_OPERATOR_REGEX = /[|>+~\[\]():,.#*=-]/.freeze
    WHITESPACE_REGEX = /[ \t\n\r\f]+/.freeze
    COMMENT_REGEX = %r{/\*[^*]*\*+(?:[^/*][^*]*\*+)*/}.freeze
    ESCAPE_SEQUENCE = /\\(?:[0-9a-fA-F]{1,6}[ \t\n\r\f]?|[^\n\r\f])/.freeze
    IDENTIFIER_REGEX = /
      (?:
        --
        |
        -?(?:[a-zA-Z_]|[^\x00-\x7F]|#{ESCAPE_SEQUENCE})
      )
      (?:[a-zA-Z0-9_-]|[^\x00-\x7F]|#{ESCAPE_SEQUENCE})*
    /x.freeze
    NUMBER_REGEX = /\d+(\.\d+)?/.freeze
    HEX_ESCAPE_REGEX = /\\([0-9a-fA-F]{1,6})([ \t\n\r\f])?/.freeze
    ESCAPED_NEWLINE_REGEX = /\\(?:\r\n|[\n\r\f])/.freeze
    SIMPLE_ESCAPE_REGEX = /\\([^\n\r\f])/.freeze
    REPLACEMENT_CHARACTER = "\uFFFD"

    attr_reader :line, :column

    def initialize(input)
      unless input.valid_encoding?
        raise_lexer_error('Invalid input encoding', { line: 1, column: 1, offset: 0 })
      end

      preprocessed_input, @offset_map = preprocess_input(input)
      @scanner = StringScanner.new(preprocessed_input)
      @line = 1
      @column = 1
      @tokens = []
    end

    def tokenize
      until @scanner.eos?
        skip_ignored
        break if @scanner.eos?

        start_position = current_position

        if (token = scan_string(start_position))
          type, value = token
          @tokens << build_token(type, value, start_position)
        elsif (value = scan_number)
          @tokens << build_token(:NUMBER, value, start_position)
        elsif (type = scan_operator)
          @tokens << build_token(type, @scanner.matched, start_position)
        elsif (value = scan_identifier(start_position))
          @tokens << build_token(:IDENT, value, start_position)
        else
          char = @scanner.getch
          raise_lexer_error("Unexpected character: #{char}", start_position)
        end
      end

      @tokens << Token.new(type: false, value: nil, position: eof_position)
      @tokens
    end

    private

    def preprocess_input(input)
      output = +''
      offset_map = { 0 => 0 }
      chars = input.each_char.to_a
      original_offset = 0
      index = 0

      while index < chars.length
        char = chars[index]
        original_start = original_offset
        original_offset += char.bytesize

        if char == "\r"
          if chars[index + 1] == "\n"
            index += 1
            original_offset += chars[index].bytesize
          end
          append_preprocessed(output, offset_map, "\n", original_start, original_offset)
        elsif char == "\f"
          append_preprocessed(output, offset_map, "\n", original_start, original_offset)
        elsif char == "\0" || surrogate_codepoint?(char)
          append_preprocessed(output, offset_map, REPLACEMENT_CHARACTER, original_start, original_offset)
        else
          append_preprocessed(output, offset_map, char, original_start, original_offset)
        end

        index += 1
      end

      offset_map[output.bytesize] = original_offset
      [output, offset_map]
    end

    def append_preprocessed(output, offset_map, value, original_start, original_end)
      offset_map[output.bytesize] = original_start
      output << value
      offset_map[output.bytesize] = original_end
    end

    def surrogate_codepoint?(char)
      char.ord.between?(0xD800, 0xDFFF)
    end

    def skip_ignored
      loop do
        if @scanner.scan(WHITESPACE_REGEX)
          update_position(@scanner.matched)
        elsif @scanner.peek(2) == '/*'
          pos = { line: @line, column: @column, offset: @scanner.pos }
          unless @scanner.scan(COMMENT_REGEX)
            raise_lexer_error('Unterminated comment', pos)
          end
          update_position(@scanner.matched)
        else
          break
        end
      end
    end

    def scan_operator
      two_chars = @scanner.peek(2)
      if (token = MULTI_CHAR_TOKENS[two_chars])
        @scanner.pos += 2
        update_position(two_chars)
        return token
      end

      return unless @scanner.scan(SINGLE_CHAR_OPERATOR_REGEX)

      char = @scanner.matched
      update_position(char)
      TOKENS[char]
    end

    def scan_string(position)
      quote = @scanner.peek(1)
      return unless quote == '"' || quote == "'"

      @scanner.getch
      update_position(quote)
      raw = +''

      until @scanner.eos?
        char = @scanner.peek(1)
        return build_string_token(:STRING, raw, position, quote) if char == quote && consume_string_char(raw)
        return build_string_token(:BAD_STRING, raw, position, quote) if newline?(char)

        consume_string_char(raw)
      end

      build_string_token(:STRING, raw, position, quote)
    end

    def scan_identifier(position)
      # Match identifiers with optional escape sequences
      # CSS allows \<any-char> as escape in identifiers (e.g., .hover\:bg-blue-500)
      #
      # NOTE: This also accepts CSS custom properties starting with -- (e.g., --my-variable).
      # While custom properties are technically only valid in property contexts (not selectors),
      # this parser accepts them as a superset of valid CSS for flexibility. In practice,
      # selectors like .--invalid-class would parse but aren't valid CSS selectors.
      return unless @scanner.scan(IDENTIFIER_REGEX)

      ident = @scanner.matched
      update_position(ident)
      Identifier.new(unescape_css(ident), ident).tap { |identifier| identifier.position = position }
    end

    def scan_number
      return unless @scanner.scan(NUMBER_REGEX)

      num = @scanner.matched
      update_position(num)
      num
    end

    def consume_string_char(raw)
      char = @scanner.getch
      update_position(char)
      return true if char == '"' || char == "'"

      raw << char
      return true unless char == '\\'
      return true if @scanner.eos?

      escaped = @scanner.getch
      update_position(escaped)
      raw << escaped
      true
    end

    def build_string_token(type, raw, position, quote)
      [type, TokenValue.new(value: unescape_css(raw), raw: raw, position: position, quote: quote)]
    end

    def newline?(char)
      char == "\n" || char == "\r" || char == "\f"
    end

    def update_position(text)
      unless text.match?(/[\n\r\f]/)
        @column += text.each_char.count
        return
      end

      lines = text.split(/\r\n|[\n\r\f]/, -1)
      @line += lines.length - 1
      @column = lines.last.each_char.count + 1
    end

    def current_position
      { line: @line, column: @column, offset: original_offset(@scanner.pos) }
    end

    def original_offset(preprocessed_offset)
      @offset_map.fetch(preprocessed_offset, preprocessed_offset)
    end

    def build_token(type, value, start_position)
      position = start_position.merge(
        start_line: start_position[:line],
        start_column: start_position[:column],
        start_offset: start_position[:offset],
        end_line: @line,
        end_column: @column,
        end_offset: original_offset(@scanner.pos)
      )

      value.position = position if value.respond_to?(:position=)
      Token.new(type: type, value: value, position: position)
    end

    def eof_position
      current_position.merge(
        start_line: @line,
        start_column: @column,
        start_offset: original_offset(@scanner.pos),
        end_line: @line,
        end_column: @column,
        end_offset: original_offset(@scanner.pos)
      )
    end

    def unescape_css(value)
      value
        .gsub(ESCAPED_NEWLINE_REGEX, '')
        .gsub(HEX_ESCAPE_REGEX) { decode_hex_escape(Regexp.last_match(1)) }
        .gsub(SIMPLE_ESCAPE_REGEX, '\1')
    end

    def decode_hex_escape(hex)
      codepoint = hex.to_i(16)
      return REPLACEMENT_CHARACTER if codepoint.zero? || codepoint > 0x10FFFF

      codepoint.chr(Encoding::UTF_8)
    rescue RangeError
      REPLACEMENT_CHARACTER
    end

    def raise_lexer_error(message, position)
      error = {
        message: "#{message} at #{position[:line]}:#{position[:column]} (offset #{position[:offset]})",
        line: position[:line],
        column: position[:column],
        offset: position[:offset]
      }

      if defined?(Parselly::LexError)
        raise Parselly::LexError, error
      end

      raise error[:message]
    end
  end
end
