# frozen_string_literal: true

RSpec.describe Parselly::Lexer do
  let(:lexer) { Parselly::Lexer.new(input) }

  describe '#tokenize' do
    context 'with simple selectors' do
      let(:input) { 'div.class#id' }

      it 'tokenizes element, class, and id' do
        tokens = lexer.tokenize
        expect(tokens[0]).to be_a(Parselly::Lexer::Token)
        expect(tokens[0][0]).to eq(:IDENT)
        expect(tokens[0][1].value).to eq('div')
        expect(tokens[0][1].raw).to eq('div')
        expect(tokens[0][2]).to include(
          line: 1,
          column: 1,
          offset: 0,
          start_line: 1,
          start_column: 1,
          start_offset: 0,
          end_line: 1,
          end_column: 4,
          end_offset: 3
        )
        expect(tokens[1]).to eq([:DOT, '.', { line: 1, column: 4, offset: 3 }])
        expect(tokens[2][0]).to eq(:IDENT)
        expect(tokens[2][1].value).to eq('class')
        expect(tokens[2][1].raw).to eq('class')
        expect(tokens[2][2]).to include(line: 1, column: 5, offset: 4)
        expect(tokens[3]).to eq([:HASH, '#', { line: 1, column: 10, offset: 9 }])
        expect(tokens[4][0]).to eq(:IDENT)
        expect(tokens[4][1].value).to eq('id')
        expect(tokens[4][1].raw).to eq('id')
        expect(tokens[4][2]).to include(line: 1, column: 11, offset: 10)
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
        expect(tokens[0]).to eq([:STRING, 'hello world', { line: 1, column: 1, offset: 0 }])
      end

      it 'tokenizes single-quoted strings' do
        lexer = Parselly::Lexer.new("'hello world'")
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:STRING, 'hello world', { line: 1, column: 1, offset: 0 }])
      end

      it 'handles escaped characters' do
        lexer = Parselly::Lexer.new('"hello \"world\""')
        tokens = lexer.tokenize
        expect(tokens[0][0]).to eq(:STRING)
        expect(tokens[0][1].value).to eq('hello "world"')
        expect(tokens[0][1].raw).to eq('hello \"world\"')
        expect(tokens[0][1].quote).to eq('"')
      end

      it 'consumes escaped newlines in strings' do
        lexer = Parselly::Lexer.new("\"line\\\nbreak\"")
        tokens = lexer.tokenize

        expect(tokens[0][0]).to eq(:STRING)
        expect(tokens[0][1].value).to eq('linebreak')
        expect(tokens[0][1].raw).to eq("line\\\nbreak")
        expect(tokens[0][2]).to include(start_line: 1, end_line: 2)
      end

      it 'returns a string token when EOF ends the string' do
        lexer = Parselly::Lexer.new('"unterminated')
        tokens = lexer.tokenize

        expect(tokens[0][0]).to eq(:STRING)
        expect(tokens[0][1].value).to eq('unterminated')
      end

      it 'returns a bad string token for unescaped newlines' do
        lexer = Parselly::Lexer.new("\"line\nbreak\"")
        tokens = lexer.tokenize

        expect(tokens[0][0]).to eq(:BAD_STRING)
        expect(tokens[0][1].value).to eq('line')
        expect(tokens[0][2]).to include(start_line: 1, end_line: 1)
      end

      it 'decodes invalid escaped code points as replacement characters' do
        lexer = Parselly::Lexer.new('"\\0 \\D800 \\110000 "')
        tokens = lexer.tokenize

        expect(tokens[0][1].value).to eq("\uFFFD\uFFFD\uFFFD")
      end

      it 'preprocesses null code points before tokenizing strings' do
        lexer = Parselly::Lexer.new("\"a\0b\"")
        tokens = lexer.tokenize

        expect(tokens[0][1].value).to eq("a\uFFFDb")
        expect(tokens[0][1].raw).to eq("a\uFFFDb")
        expect(tokens[0][2]).to include(start_offset: 0, end_offset: 5)
      end
    end

    context 'with numbers' do
      it 'tokenizes integers' do
        lexer = Parselly::Lexer.new('123')
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:NUMBER, '123', { line: 1, column: 1, offset: 0 }])
      end

      it 'tokenizes decimals' do
        lexer = Parselly::Lexer.new('3.14')
        tokens = lexer.tokenize
        expect(tokens[0]).to eq([:NUMBER, '3.14', { line: 1, column: 1, offset: 0 }])
      end
    end

    context 'with identifiers' do
      it 'tokenizes simple identifiers' do
        lexer = Parselly::Lexer.new('div')
        tokens = lexer.tokenize
        expect(tokens[0][0]).to eq(:IDENT)
        expect(tokens[0][1].value).to eq('div')
        expect(tokens[0][1].raw).to eq('div')
        expect(tokens[0][2]).to include(line: 1, column: 1, offset: 0)
      end

      it 'tokenizes identifiers with hyphens' do
        lexer = Parselly::Lexer.new('custom-element')
        tokens = lexer.tokenize
        expect(tokens[0][0]).to eq(:IDENT)
        expect(tokens[0][1].value).to eq('custom-element')
        expect(tokens[0][1].raw).to eq('custom-element')
        expect(tokens[0][2]).to include(line: 1, column: 1, offset: 0)
      end

      it 'tokenizes identifiers with underscores' do
        lexer = Parselly::Lexer.new('my_class')
        tokens = lexer.tokenize
        expect(tokens[0][0]).to eq(:IDENT)
        expect(tokens[0][1].value).to eq('my_class')
        expect(tokens[0][1].raw).to eq('my_class')
        expect(tokens[0][2]).to include(line: 1, column: 1, offset: 0)
      end

      it 'preprocesses null code points before tokenizing identifiers' do
        lexer = Parselly::Lexer.new(".a\0b")
        tokens = lexer.tokenize

        expect(tokens.map(&:first)).to eq([:DOT, :IDENT, false])
        expect(tokens[1][1].value).to eq("a\uFFFDb")
        expect(tokens[1][1].raw).to eq("a\uFFFDb")
        expect(tokens[1][2]).to include(start_offset: 1, end_offset: 4)
      end
    end

    context 'position tracking' do
      let(:input) { "div\n.class" }

      it 'tracks line numbers' do
        tokens = lexer.tokenize
        expect(tokens[0][2]).to include(line: 1, column: 1, offset: 0)
        expect(tokens[1][2]).to include(line: 2, column: 1, offset: 4)
      end

      it 'tracks column numbers' do
        lexer = Parselly::Lexer.new('div .class')
        tokens = lexer.tokenize
        expect(tokens[0][2]).to include(line: 1, column: 1, offset: 0)
        expect(tokens[1][2]).to include(line: 1, column: 5, offset: 4)
      end

      it 'tracks CSS newline variants' do
        cr_tokens = Parselly::Lexer.new("div\r.class").tokenize
        crlf_tokens = Parselly::Lexer.new("div\r\n.class").tokenize
        ff_tokens = Parselly::Lexer.new("div\f.class").tokenize

        expect(cr_tokens[1][2]).to include(line: 2, column: 1, offset: 4)
        expect(crlf_tokens[1][2]).to include(line: 2, column: 1, offset: 5)
        expect(ff_tokens[1][2]).to include(line: 2, column: 1, offset: 4)
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

      it 'handles form feed as whitespace' do
        lexer = Parselly::Lexer.new("div\f>\fp")
        tokens = lexer.tokenize
        expect(tokens.map(&:first)).to eq([:IDENT, :CHILD, :IDENT, false])
      end

      it 'handles comments as ignored input' do
        lexer = Parselly::Lexer.new('div/* comment */.class')
        tokens = lexer.tokenize
        expect(tokens.map(&:first)).to eq([:IDENT, :DOT, :IDENT, false])
        expect(tokens[1][2]).to include(line: 1, column: 17, offset: 16)
      end

      it 'tracks positions after multiline comments with unicode prefixes' do
        lexer = Parselly::Lexer.new("あ/*\n*/.class")
        tokens = lexer.tokenize

        expect(tokens.map(&:first)).to eq([:IDENT, :DOT, :IDENT, false])
        expect(tokens[1][2]).to include(line: 2, column: 3, offset: 8)
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

      it 'raises lexer errors for invalid encodings' do
        input = "\xFF".b.force_encoding(Encoding::UTF_8)
        expect { Parselly::Lexer.new(input) }.to raise_error(Parselly::LexError)
      end
    end
  end
end
