# frozen_string_literal: true

require 'rspec'
require 'parselly'

RSpec.describe Parselly do
  describe '.sanitize' do
    it 'escapes a single dash' do
      expect(Parselly.sanitize('-')).to eq('\\-')
    end

    it 'replaces null character with replacement character' do
      expect(Parselly.sanitize("\0")).to eq("\uFFFD")
    end

    it 'escapes control characters' do
      input = "\x01\x02\x7F"
      expected = '\\1 \\2 \\7f '
      expect(Parselly.sanitize(input)).to eq(expected)
    end

    it 'escapes first character when it is a digit' do
      input = '1abc'
      expected = '\\31 abc'
      expect(Parselly.sanitize(input)).to eq(expected)
    end

    it 'escapes second character digit after dash' do
      input = '-1abc'
      expected = '-\\31 abc'
      expect(Parselly.sanitize(input)).to eq(expected)
    end

    it 'preserves alphanumeric and safe characters' do
      input = 'a-Z_0-9'
      expect(Parselly.sanitize(input)).to eq('a-Z_0-9')
    end

    it 'escapes special characters' do
      input = '!@#$%^&*()'
      expected = '\\!\\@\\#\\$\\%\\^\\&\\*\\(\\)'
      expect(Parselly.sanitize(input)).to eq(expected)
    end

    it 'handles mixed input with various character types' do
      input = "-1a\x01b\0c!"
      expected = '-\\31 a\\1 b�c\\!'
      expect(Parselly.sanitize(input)).to eq(expected)
    end

    it 'returns empty string for empty input' do
      expect(Parselly.sanitize('')).to eq('')
    end

    it 'preserves all safe characters' do
      input = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_'
      expect(Parselly.sanitize(input)).to eq(input)
    end
  end
end
