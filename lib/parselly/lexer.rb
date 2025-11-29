# frozen_string_literal: true

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
      while @scanner.scan(/[ \t\n\r]+/)
        @scanner.matched.each_char do |char|
          update_position(char)
        end
      end
    end

    def scan_operator
      # Check multi-character operators first
      ['~=', '|=', '^=', '$=', '*='].each do |op|
        if @scanner.scan(/#{Regexp.escape(op)}/)
          update_position(@scanner.matched)
          return TOKENS[op]
        end
      end

      # Single character operators
      return unless @scanner.scan(/[>+~\[\]():,.#*=-]/)

      char = @scanner.matched
      update_position(char)
      TOKENS[char]
    end

    def scan_string
      if @scanner.scan(/"([^"\\]|\\.)*"/)
        str = @scanner.matched
        update_position(str)
        # NOTE: Escape sequences inside strings (e.g., \n, \", \\) are not processed.
        # The raw string content is returned as-is after removing quotes.
        # This is a known limitation for attribute values.
        str[1..-2] # Remove quotes
      elsif @scanner.scan(/'([^'\\]|\\.)*'/)
        str = @scanner.matched
        update_position(str)
        # NOTE: Escape sequences inside strings (e.g., \n, \', \\) are not processed.
        # The raw string content is returned as-is after removing quotes.
        # This is a known limitation for attribute values.
        str[1..-2] # Remove quotes
      end
    end

    def scan_identifier
      # Match identifiers with optional escape sequences
      # CSS allows \<any-char> as escape in identifiers (e.g., .hover\:bg-blue-500)
      # Also support CSS custom properties starting with -- (e.g., --my-variable)
      return unless @scanner.scan(/(?:--|-?[a-zA-Z_])(?:[\w-]|\\[^\n\r\f])*/)

      ident = @scanner.matched
      update_position(ident)
      # Remove backslashes from escaped characters
      ident.gsub(/\\(.)/, '\1')
    end

    def scan_number
      return unless @scanner.scan(/\d+(\.\d+)?/)

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
