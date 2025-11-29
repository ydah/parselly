# frozen_string_literal: true

require 'parselly'

RSpec.describe Parselly::Lexer do
  let(:lexer) { Parselly::Lexer.new(input) }

  describe '#tokenize' do
    context 'with simple selectors' do
      let(:input) { 'div.class#id' }

      it 'tokenizes element, class, and id' do
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:IDENT, 'div', { line: 1, column: 1 }])
        expect(tokens[1]).to eq([:DOT, '.', { line: 1, column: 4 }])
        expect(tokens[2]).to eq([:IDENT, 'class', { line: 1, column: 5 }])
        expect(tokens[3]).to eq([:HASH, '#', { line: 1, column: 10 }])
        expect(tokens[4]).to eq([:IDENT, 'id', { line: 1, column: 11 }])
      end
    end

    context 'with operators' do
      let(:input) { '>' }

      it 'tokenizes child combinator' do
        tokens = lexer.tokenize
        expect(tokens[0][0]).to eq(:CHILD)
      end
    end

    context 'with attribute operators' do
      it 'tokenizes ~=' do
        lexer = Parselly::Lexer.new('[class~="test"]')
        tokens = lexer.tokenize
        expect(tokens.map(&:first)).to include(:INCLUDES)
      end

      it 'tokenizes |=' do
        lexer = Parselly::Lexer.new('[lang|="en"]')
        tokens = lexer.tokenize
        expect(tokens.map(&:first)).to include(:DASHMATCH)
      end

      it 'tokenizes ^=' do
        lexer = Parselly::Lexer.new('[href^="http"]')
        tokens = lexer.tokenize
        expect(tokens.map(&:first)).to include(:PREFIXMATCH)
      end

      it 'tokenizes $=' do
        lexer = Parselly::Lexer.new('[href$=".pdf"]')
        tokens = lexer.tokenize
        expect(tokens.map(&:first)).to include(:SUFFIXMATCH)
      end

      it 'tokenizes *=' do
        lexer = Parselly::Lexer.new('[title*="hello"]')
        tokens = lexer.tokenize
        expect(tokens.map(&:first)).to include(:SUBSTRINGMATCH)
      end
    end

    context 'with strings' do
      it 'tokenizes double-quoted strings' do
        lexer = Parselly::Lexer.new('"hello world"')
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:STRING, 'hello world', { line: 1, column: 1 }])
      end

      it 'tokenizes single-quoted strings' do
        lexer = Parselly::Lexer.new("'hello world'")
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:STRING, 'hello world', { line: 1, column: 1 }])
      end

      it 'handles escaped characters' do
        lexer = Parselly::Lexer.new('"hello \"world\""')
        tokens = lexer.tokenize
        # NOTE: Escape sequences inside strings are not processed.
        # The raw string content is returned as-is after removing outer quotes.
        # This test verifies the string is tokenized, but escapes remain unprocessed.
        expect(tokens[0][0]).to eq(:STRING)
        expect(tokens[0][1]).to eq('hello \"world\"')
      end
    end

    context 'with numbers' do
      it 'tokenizes integers' do
        lexer = Parselly::Lexer.new('123')
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:NUMBER, '123', { line: 1, column: 1 }])
      end

      it 'tokenizes decimals' do
        lexer = Parselly::Lexer.new('3.14')
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:NUMBER, '3.14', { line: 1, column: 1 }])
      end
    end

    context 'with identifiers' do
      it 'tokenizes simple identifiers' do
        lexer = Parselly::Lexer.new('div')
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:IDENT, 'div', { line: 1, column: 1 }])
      end

      it 'tokenizes identifiers with hyphens' do
        lexer = Parselly::Lexer.new('custom-element')
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:IDENT, 'custom-element', { line: 1, column: 1 }])
      end

      it 'tokenizes identifiers with underscores' do
        lexer = Parselly::Lexer.new('my_class')
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:IDENT, 'my_class', { line: 1, column: 1 }])
      end
    end

    context 'position tracking' do
      let(:input) { "div\n.class" }

      it 'tracks line numbers' do
        tokens = lexer.tokenize
        expect(tokens[0][2]).to eq({ line: 1, column: 1 })
        expect(tokens[1][2]).to eq({ line: 2, column: 1 })
      end

      it 'tracks column numbers' do
        lexer = Parselly::Lexer.new('div .class')
        tokens = lexer.tokenize
        expect(tokens[0][2]).to eq({ line: 1, column: 1 })
        expect(tokens[1][2]).to eq({ line: 1, column: 5 })
      end
    end

    context 'whitespace handling' do
      it 'skips spaces' do
        lexer = Parselly::Lexer.new('div   >   p')
        tokens = lexer.tokenize
        expect(tokens.map(&:first)).to eq([:IDENT, :CHILD, :IDENT, false])
      end

      it 'skips tabs' do
        lexer = Parselly::Lexer.new("div\t>\tp")
        tokens = lexer.tokenize
        expect(tokens.map(&:first)).to eq([:IDENT, :CHILD, :IDENT, false])
      end

      it 'handles newlines' do
        lexer = Parselly::Lexer.new("div\n>\np")
        tokens = lexer.tokenize
        expect(tokens.map(&:first)).to eq([:IDENT, :CHILD, :IDENT, false])
      end
    end

    context 'error handling' do
      it 'raises error for invalid characters' do
        lexer = Parselly::Lexer.new('div & p')
        expect { lexer.tokenize }.to raise_error(/Unexpected character/)
      end

      it 'includes position in error message' do
        lexer = Parselly::Lexer.new('div & p')
        expect { lexer.tokenize }.to raise_error(/at 1:5/)
      end
    end
  end
end
