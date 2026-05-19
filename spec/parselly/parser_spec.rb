# frozen_string_literal: true

RSpec.describe Parselly::Parser do
  let(:parser) { described_class.new }

  def find_all(node, type)
    node.each.select { |child| child.type == type }
  end

  describe 'descendant combinator handling' do
    it 'uses actual whitespace instead of adjacent token guesses' do
      compact = parser.parse('div.foo')
      spaced = parser.parse('div .foo')

      expect(find_all(compact, :descendant_combinator)).to be_empty
      expect(find_all(spaced, :descendant_combinator).size).to eq(1)
      expect(compact.to_selector).to eq('div.foo')
      expect(spaced.to_selector).to eq('div .foo')
    end

    it 'distinguishes compound pseudo selectors from descendant pseudo selectors' do
      compact = parser.parse('a:hover')
      spaced = parser.parse('a :hover')

      expect(find_all(compact, :descendant_combinator)).to be_empty
      expect(find_all(spaced, :descendant_combinator).size).to eq(1)
      expect(compact.to_selector).to eq('a:hover')
      expect(spaced.to_selector).to eq('a :hover')
    end

    it 'treats comments as descendant-separating ignored input' do
      ast = parser.parse('div/*x*/.foo')

      expect(find_all(ast, :descendant_combinator).size).to eq(1)
      expect(ast.to_selector).to eq('div .foo')
    end
  end

  describe 'source positions' do
    it 'stores start positions for reduced nodes' do
      ast = parser.parse('input[type="text"]')
      attribute = find_all(ast, :attribute_selector).first
      value = find_all(ast, :value).first

      expect(attribute.position).to include(line: 1, column: 6, offset: 5)
      expect(value.position).to include(line: 1, column: 12, offset: 11)
    end

    it 'raises Parselly::SyntaxError in strict mode' do
      expect { parser.parse('div >') }.to raise_error(Parselly::SyntaxError)
    end
  end

  describe 'CSS syntax coverage' do
    it 'handles CSS identifier escapes and unicode identifiers' do
      ast = parser.parse('.\\31 23.caf\\e9.日本語')

      expect(ast.classes).to eq(['123', 'café', '日本語'])
      expect(ast.to_selector(mode: :preserve)).to eq('.\\31 23.caf\\e9.日本語')
    end

    it 'supports attribute modifiers and numeric attribute values' do
      flagged = parser.parse('[type="A" i]')
      numeric = parser.parse('[data-id=123]')

      expect(flagged.attribute_selectors.first).to include(
        name: 'type',
        value: 'A',
        quote: '"',
        modifier: 'i'
      )
      expect(flagged.to_selector(mode: :preserve)).to eq('[type="A" i]')
      expect(numeric.attributes).to eq([{ name: 'data-id', operator: '=', value: '123' }])
    end

    it 'supports namespaced type, universal, and attribute selectors' do
      ast = parser.parse('svg|a[*|href]')

      expect(ast.type_selectors.first).to include(name: 'a', namespace: 'svg')
      expect(ast.attribute_selectors.first).to include(name: 'href', namespace: '*')
      expect(ast.to_selector(mode: :preserve)).to eq('svg|a[*|href]')
    end

    it 'supports nth-child selector arguments' do
      ast = parser.parse(':nth-child(2n+1 of li.important)')
      pseudo = find_all(ast, :pseudo_function).first
      argument = pseudo.children.first

      expect(argument.type).to eq(:nth_selector_argument)
      expect(argument.children.first.value).to eq('2n+1')
      expect(ast.to_selector).to eq(':nth-child(2n+1 of li.important)')

      keyword = parser.parse(':nth-child(even of .item)')
      keyword_argument = find_all(keyword, :pseudo_function).first.children.first
      expect(keyword_argument.children.first.value).to eq('even')
    end

    it 'supports functional pseudo-elements and column combinators' do
      pseudo_element = parser.parse('::slotted(.item)')
      columns = parser.parse('col || td')

      expect(find_all(pseudo_element, :pseudo_element_function).first.value).to eq('slotted')
      expect(find_all(columns, :column_combinator).first.value).to eq('||')
      expect(columns.to_selector).to eq('col || td')
    end

    it 'classifies legacy single-colon pseudo-elements' do
      ast = parser.parse(':before')

      expect(find_all(ast, :pseudo_element).first.value).to eq('before')
      expect(ast.pseudo_element_names).to eq(['before'])
    end

    it 'rejects invalid known pseudo-function arguments' do
      expect { parser.parse(':nth-child(foo)') }.to raise_error(Parselly::SyntaxError)
    end
  end

  describe 'tolerant recovery' do
    it 'recovers valid selector-list entries after an invalid entry' do
      result = parser.parse('div, [=bad], span', tolerant: true)

      expect(result).to be_failure
      expect(result.ast.to_selector).to eq('div, span')
      expect(result.first_error).to include(:message, :line, :column, :offset)
    end
  end

  describe 'resource limits' do
    it 'supports max length and max token limits' do
      expect { parser.parse('div', max_length: 2) }.to raise_error(Parselly::ParseError)
      expect { parser.parse('div.class', max_tokens: 2) }.to raise_error(Parselly::ParseError)
    end

    it 'supports max depth limits' do
      expect { parser.parse('div > span', max_depth: 2) }.to raise_error(Parselly::ParseError)
    end
  end
end
