# frozen_string_literal: true

RSpec.describe Parselly do
  describe '.parse' do
    it 'parses a selector via module-level API' do
      ast = described_class.parse('div#main.content')

      expect(ast).not_to be_nil
      expect(ast).to respond_to(:type)
    end

    it 'returns partial AST and errors in tolerant mode' do
      result = described_class.parse('div >', tolerant: true)

      expect(result).to be_a(Parselly::ParseResult)
      expect(result.errors).not_to be_empty
      expect(result.errors.first).to include(:message, :line, :column, :offset)
      expect(result.ast).not_to be_nil
    end

    it 'supports keyword initialization for parse results' do
      result = Parselly::ParseResult.new(ast: :ast, errors: [])

      expect(result.ast).to eq(:ast)
      expect(result.errors).to eq([])
      expect(result.to_a).to eq([:ast, []])
      expect(result.deconstruct_keys([:ast])).to eq(ast: :ast)
    end

    it 'captures lexer errors in tolerant mode' do
      result = described_class.parse('div@class', tolerant: true)

      expect(result).to be_a(Parselly::ParseResult)
      expect(result.errors).not_to be_empty
      expect(result.errors.first).to include(:message, :line, :column, :offset)
      expect(result.ast).to be_nil
    end

    it 'normalizes non-string input errors' do
      expect { described_class.parse(nil) }.to raise_error(Parselly::ParseError, /Input must be a String/)

      result = described_class.parse(nil, tolerant: true)
      expect(result).to be_failure
      expect(result.ast).to be_nil
      expect(result.first_error).to include(message: 'Input must be a String', line: 1, column: 1, offset: 0)
    end
  end
end
