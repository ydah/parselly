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
    STRING_DOUBLE_REGEX = /"([^"\\]|\\.)*"/.freeze
    STRING_SINGLE_REGEX = /'([^'\\]|\\.)*'/.freeze
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
    SIMPLE_ESCAPE_REGEX = /\\([^\n\r\f])/.freeze
    REPLACEMENT_CHARACTER = "\uFFFD"

    attr_reader :line, :column

    def initialize(input)
      unless input.valid_encoding?
        raise_lexer_error('Invalid input encoding', { line: 1, column: 1, offset: 0 })
      end

      @scanner = StringScanner.new(input)
      @line = 1
      @column = 1
      @tokens = []
    end

    def tokenize
      until @scanner.eos?
        skip_ignored
        break if @scanner.eos?

        pos = { line: @line, column: @column, offset: @scanner.pos }

        if (token = scan_string(pos))
          @tokens << [:STRING, token, pos]
        elsif (token = scan_number)
          @tokens << [:NUMBER, token, pos]
        elsif (token = scan_operator)
          @tokens << [token, @scanner.matched, pos]
        elsif (token = scan_identifier(pos))
          @tokens << [:IDENT, token, pos]
        else
          char = @scanner.getch
          raise_lexer_error("Unexpected character: #{char}", pos)
        end
      end

      @tokens << [false, nil, { line: @line, column: @column, offset: @scanner.pos }]
      @tokens
    end

    private

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
      if @scanner.scan(STRING_DOUBLE_REGEX)
        str = @scanner.matched
        update_position(str)
        raw = str[1..-2]
        TokenValue.new(value: unescape_css(raw), raw: raw, position: position, quote: '"')
      elsif @scanner.scan(STRING_SINGLE_REGEX)
        str = @scanner.matched
        update_position(str)
        raw = str[1..-2]
        TokenValue.new(value: unescape_css(raw), raw: raw, position: position, quote: "'")
      end
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

    def update_position(text)
      text.each_char do |char|
        if char == "\n"
          @line += 1
          @column = 1
        else
          @column += 1
        end
      end
    end

    def unescape_css(value)
      value
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
