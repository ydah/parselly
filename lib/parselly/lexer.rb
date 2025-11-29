# frozen_string_literal: true

require 'strscan'

module Parselly
  class Lexer
    TOKENS = {
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

    # Pre-compiled regular expressions for better performance
    MULTI_CHAR_OPERATORS = [
      [/~=/, :INCLUDES],
      [/\|=/, :DASHMATCH],
      [/\^=/, :PREFIXMATCH],
      [/\$=/, :SUFFIXMATCH],
      [/\*=/, :SUBSTRINGMATCH]
    ].freeze

    SINGLE_CHAR_OPERATOR_REGEX = /[>+~\[\]():,.#*=-]/.freeze
    WHITESPACE_REGEX = /[ \t\n\r]+/.freeze
    STRING_DOUBLE_REGEX = /"([^"\\]|\\.)*"/.freeze
    STRING_SINGLE_REGEX = /'([^'\\]|\\.)*'/.freeze
    IDENTIFIER_REGEX = /(?:--|-?[a-zA-Z_])(?:[\w-]|\\[^\n\r\f])*/.freeze
    NUMBER_REGEX = /\d+(\.\d+)?/.freeze
    ESCAPE_REGEX = /\\(.)/.freeze

    attr_reader :line, :column

    def initialize(input)
      @scanner = StringScanner.new(input)
      @line = 1
      @column = 1
      @tokens = []
    end

    def tokenize
      until @scanner.eos?
        skip_whitespace
        break if @scanner.eos?

        pos = { line: @line, column: @column }

        if (token = scan_string)
          @tokens << [:STRING, token, pos]
        elsif (token = scan_number)
          @tokens << [:NUMBER, token, pos]
        elsif (token = scan_operator)
          @tokens << [token, @scanner.matched, pos]
        elsif (token = scan_identifier)
          @tokens << [:IDENT, token, pos]
        else
          char = @scanner.getch
          raise "Unexpected character: #{char} at #{pos[:line]}:#{pos[:column]}"
        end
      end

      @tokens << [false, nil, { line: @line, column: @column }]
      @tokens
    end

    private

    def skip_whitespace
      while @scanner.scan(WHITESPACE_REGEX)
        matched = @scanner.matched
        newline_count = matched.count("\n")
        if newline_count > 0
          @line += newline_count
          @column = matched.size - matched.rindex("\n")
        else
          @column += matched.size
        end
      end
    end

    def scan_operator
      # Check multi-character operators first
      MULTI_CHAR_OPERATORS.each do |regex, token|
        if @scanner.scan(regex)
          update_position(@scanner.matched)
          return token
        end
      end

      # Single character operators
      return unless @scanner.scan(SINGLE_CHAR_OPERATOR_REGEX)

      char = @scanner.matched
      update_position(char)
      TOKENS[char]
    end

    # NOTE: Unlike identifiers (where backslash escapes are processed),
    # escape sequences inside strings (e.g., \n, \", \', \\) are NOT processed.
    # The raw string content is returned as-is after removing outer quotes.
    # This is a known limitation for attribute values, as strings are treated
    # as raw text for simplicity. Identifiers process escapes to support patterns
    # like .hover\:bg-blue-500, but strings in attributes don't require this.
    def scan_string
      if @scanner.scan(STRING_DOUBLE_REGEX)
        str = @scanner.matched
        update_position(str)
        str[1..-2] # Remove quotes
      elsif @scanner.scan(STRING_SINGLE_REGEX)
        str = @scanner.matched
        update_position(str)
        str[1..-2] # Remove quotes
      end
    end

    def scan_identifier
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
      # Remove backslashes from escaped characters
      ident.gsub(ESCAPE_REGEX, '\1')
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
  end
end
