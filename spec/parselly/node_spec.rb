# frozen_string_literal: true

RSpec.describe Parselly::Node do
  let(:parser) { Parselly::Parser.new }

  describe '#id?' do
    it 'returns true when node contains an ID selector' do
      ast = parser.parse('#myid')
      expect(ast.id?).to be true
    end

    it 'returns false when node does not contain an ID selector' do
      ast = parser.parse('.myclass')
      expect(ast.id?).to be false
    end

    it 'returns true when descendant contains an ID selector' do
      ast = parser.parse('div#myid')
      expect(ast.id?).to be true
    end
  end

  describe '#id' do
    it 'extracts the ID value from an ID selector' do
      ast = parser.parse('#myid')
      expect(ast.id).to eq('myid')
    end

    it 'returns nil when no ID selector is present' do
      ast = parser.parse('.myclass')
      expect(ast.id).to be_nil
    end

    it 'extracts the ID value from a compound selector' do
      ast = parser.parse('div#myid.myclass')
      expect(ast.id).to eq('myid')
    end
  end

  describe '#classes' do
    it 'extracts a single class name' do
      ast = parser.parse('.myclass')
      expect(ast.classes).to eq(['myclass'])
    end

    it 'extracts multiple class names' do
      ast = parser.parse('.foo.bar.baz')
      expect(ast.classes).to eq(['foo', 'bar', 'baz'])
    end

    it 'returns empty array when no class selectors are present' do
      ast = parser.parse('#myid')
      expect(ast.classes).to eq([])
    end

    it 'extracts class names from a compound selector' do
      ast = parser.parse('div.foo#myid.bar')
      expect(ast.classes).to eq(['foo', 'bar'])
    end
  end

  describe '#attribute?' do
    it 'returns true when node contains an attribute selector' do
      ast = parser.parse('[disabled]')
      expect(ast.attribute?).to be true
    end

    it 'returns false when node does not contain an attribute selector' do
      ast = parser.parse('.myclass')
      expect(ast.attribute?).to be false
    end

    it 'returns true when descendant contains an attribute selector' do
      ast = parser.parse('input[type="text"]')
      expect(ast.attribute?).to be true
    end
  end

  describe '#attributes' do
    it 'extracts a simple attribute selector' do
      ast = parser.parse('[disabled]')
      expect(ast.attributes).to eq([{ name: 'disabled' }])
    end

    it 'extracts attribute with equality operator' do
      ast = parser.parse('[type="text"]')
      expect(ast.attributes).to eq([{ name: 'type', operator: '=', value: 'text' }])
    end

    it 'extracts attribute with includes operator' do
      ast = parser.parse('[class~="highlight"]')
      expect(ast.attributes).to eq([{ name: 'class', operator: '~=', value: 'highlight' }])
    end

    it 'extracts attribute with prefix match operator' do
      ast = parser.parse('[href^="https"]')
      expect(ast.attributes).to eq([{ name: 'href', operator: '^=', value: 'https' }])
    end

    it 'extracts attribute with suffix match operator' do
      ast = parser.parse('[src$=".png"]')
      expect(ast.attributes).to eq([{ name: 'src', operator: '$=', value: '.png' }])
    end

    it 'extracts attribute with substring match operator' do
      ast = parser.parse('[title*="test"]')
      expect(ast.attributes).to eq([{ name: 'title', operator: '*=', value: 'test' }])
    end

    it 'extracts attribute with dash match operator' do
      ast = parser.parse('[lang|="en"]')
      expect(ast.attributes).to eq([{ name: 'lang', operator: '|=', value: 'en' }])
    end

    it 'extracts multiple attributes' do
      ast = parser.parse('[type="text"][disabled]')
      expect(ast.attributes).to contain_exactly(
        { name: 'type', operator: '=', value: 'text' },
        { name: 'disabled' }
      )
    end

    it 'returns empty array when no attribute selectors are present' do
      ast = parser.parse('.myclass')
      expect(ast.attributes).to eq([])
    end
  end

  describe '#pseudo_classes' do
    it 'extracts a pseudo-class' do
      ast = parser.parse(':hover')
      expect(ast.pseudo_classes).to eq(['hover'])
    end

    it 'extracts a pseudo-element' do
      ast = parser.parse('::before')
      expect(ast.pseudo_classes).to eq(['before'])
    end

    it 'extracts a pseudo-function' do
      ast = parser.parse(':nth-child(2)')
      expect(ast.pseudo_classes).to eq(['nth-child'])
    end

    it 'extracts multiple pseudo-classes' do
      ast = parser.parse('a:hover:focus')
      expect(ast.pseudo_classes).to eq(['hover', 'focus'])
    end

    it 'extracts mixed pseudo-classes and pseudo-elements' do
      ast = parser.parse('p:first-child::before')
      expect(ast.pseudo_classes).to eq(['first-child', 'before'])
    end

    it 'returns empty array when no pseudo-classes are present' do
      ast = parser.parse('.myclass')
      expect(ast.pseudo_classes).to eq([])
    end
  end

  describe '#compound_selector?' do
    it 'returns false for a single type selector' do
      ast = parser.parse('div')
      expect(ast.compound_selector?).to be false
    end

    it 'returns false for a single class selector' do
      ast = parser.parse('.myclass')
      expect(ast.compound_selector?).to be false
    end

    it 'returns false for a single ID selector' do
      ast = parser.parse('#myid')
      expect(ast.compound_selector?).to be false
    end

    it 'returns true for type and class selector' do
      ast = parser.parse('div.myclass')
      expect(ast.compound_selector?).to be true
    end

    it 'returns true for type and ID selector' do
      ast = parser.parse('div#myid')
      expect(ast.compound_selector?).to be true
    end

    it 'returns true for type, ID, and class selector' do
      ast = parser.parse('div#myid.myclass')
      expect(ast.compound_selector?).to be true
    end

    it 'returns true for type and attribute selector' do
      ast = parser.parse('input[type="text"]')
      expect(ast.compound_selector?).to be true
    end

    it 'returns true for type and pseudo-class selector' do
      ast = parser.parse('a:hover')
      expect(ast.compound_selector?).to be true
    end

    it 'returns true for class and pseudo-class selector' do
      ast = parser.parse('.button:hover')
      expect(ast.compound_selector?).to be true
    end

    it 'returns false for multiple classes' do
      ast = parser.parse('.foo.bar')
      expect(ast.compound_selector?).to be false
    end
  end

  describe '#to_selector' do
    it 'converts a type selector back to string' do
      ast = parser.parse('div')
      expect(ast.to_selector).to eq('div')
    end

    it 'converts a class selector back to string' do
      ast = parser.parse('.myclass')
      expect(ast.to_selector).to eq('.myclass')
    end

    it 'converts an ID selector back to string' do
      ast = parser.parse('#myid')
      expect(ast.to_selector).to eq('#myid')
    end

    it 'converts a universal selector back to string' do
      ast = parser.parse('*')
      expect(ast.to_selector).to eq('*')
    end

    it 'converts a compound selector back to string' do
      ast = parser.parse('div.foo#bar')
      expect(ast.to_selector).to eq('div.foo#bar')
    end

    it 'converts a child combinator selector back to string' do
      ast = parser.parse('div > span')
      expect(ast.to_selector).to eq('div > span')
    end

    it 'converts an adjacent combinator selector back to string' do
      ast = parser.parse('h1 + h2')
      expect(ast.to_selector).to eq('h1 + h2')
    end

    it 'converts a sibling combinator selector back to string' do
      ast = parser.parse('h1 ~ h2')
      expect(ast.to_selector).to eq('h1 ~ h2')
    end

    it 'converts a simple attribute selector back to string' do
      ast = parser.parse('[disabled]')
      expect(ast.to_selector).to eq('[disabled]')
    end

    it 'converts an attribute selector with equality operator back to string' do
      ast = parser.parse('[type="text"]')
      expect(ast.to_selector).to eq('[type="text"]')
    end

    it 'converts an attribute selector with includes operator back to string' do
      ast = parser.parse('[class~="highlight"]')
      expect(ast.to_selector).to eq('[class~="highlight"]')
    end

    it 'converts an attribute selector with prefix match operator back to string' do
      ast = parser.parse('[href^="https"]')
      expect(ast.to_selector).to eq('[href^="https"]')
    end

    it 'converts an attribute selector with dash match operator back to string' do
      ast = parser.parse('[lang|="en"]')
      expect(ast.to_selector).to eq('[lang|="en"]')
    end

    it 'converts a pseudo-class selector back to string' do
      ast = parser.parse(':hover')
      expect(ast.to_selector).to eq(':hover')
    end

    it 'converts a pseudo-element selector back to string' do
      ast = parser.parse('::before')
      expect(ast.to_selector).to eq('::before')
    end

    it 'converts a pseudo-function selector back to string' do
      ast = parser.parse(':nth-child(2n+1)')
      expect(ast.to_selector).to eq(':nth-child(2n+1)')
    end

    it 'converts multiple pseudo-classes back to string' do
      ast = parser.parse('a:hover:focus')
      expect(ast.to_selector).to eq('a:hover:focus')
    end

    it 'converts a selector list back to string' do
      ast = parser.parse('div.foo, p.bar')
      expect(ast.to_selector).to eq('div.foo, p.bar')
    end

    it 'converts a complex selector with multiple combinators back to string' do
      ast = parser.parse('div > span + a')
      expect(ast.to_selector).to eq('div > span + a')
    end

    it 'converts a compound selector with attribute back to string' do
      ast = parser.parse('input.form-control[type="text"]')
      expect(ast.to_selector).to eq('input.form-control[type="text"]')
    end
  end

  describe 'tree traversal methods' do
    describe '#ancestors' do
      it 'returns empty array for root node' do
        ast = parser.parse('div')
        expect(ast.ancestors).to eq([])
      end

      it 'returns parent nodes in order' do
        ast = parser.parse('div.myclass')
        class_node = ast.descendants.find { |n| n.type == :class_selector }
        ancestors = class_node.ancestors
        expect(ancestors).not_to be_empty
        expect(ancestors.last).to eq(ast)
      end
    end

    describe '#descendants' do
      it 'returns empty array when no children' do
        node = Parselly::Node.new(:type_selector, 'div')
        expect(node.descendants).to eq([])
      end

      it 'returns all descendant nodes' do
        ast = parser.parse('div#myid.myclass')
        descendants = ast.descendants
        types = descendants.map(&:type)
        expect(types).to include(:id_selector, :class_selector)
      end

      it 'caches descendants after first call' do
        ast = parser.parse('div#myid.myclass')
        first_call = ast.descendants
        second_call = ast.descendants
        expect(first_call).to be(second_call) # Same object identity
      end

      it 'returns correct descendants after add_child' do
        parent = Parselly::Node.new(:selector_list)
        child1 = Parselly::Node.new(:type_selector, 'div')
        parent.add_child(child1)

        expect(parent.descendants).to eq([child1])

        child2 = Parselly::Node.new(:class_selector, 'myclass')
        parent.add_child(child2)

        expect(parent.descendants).to contain_exactly(child1, child2)
      end

      it 'invalidates cache when structure changes via replace_child' do
        parent = Parselly::Node.new(:selector_list)
        child1 = Parselly::Node.new(:type_selector, 'div')
        parent.add_child(child1)

        first_descendants = parent.descendants
        expect(first_descendants).to eq([child1])

        child2 = Parselly::Node.new(:class_selector, 'myclass')
        parent.replace_child(0, child2)

        expect(parent.descendants).to eq([child2])
        expect(parent.descendants).not_to be(first_descendants) # Different cache
      end

      it 'invalidates ancestor caches when child is added' do
        grandparent = Parselly::Node.new(:selector_list)
        parent = Parselly::Node.new(:selector)
        grandparent.add_child(parent)

        # Cache descendants
        grandparent_descendants = grandparent.descendants
        expect(grandparent_descendants).to eq([parent])

        # Add new child to parent
        child = Parselly::Node.new(:type_selector, 'div')
        parent.add_child(child)

        # Grandparent's cache should be invalidated
        new_grandparent_descendants = grandparent.descendants
        expect(new_grandparent_descendants).to contain_exactly(parent, child)
        expect(new_grandparent_descendants).not_to be(grandparent_descendants)
      end

      it 'invalidates ancestor caches when child is replaced' do
        grandparent = Parselly::Node.new(:selector_list)
        parent = Parselly::Node.new(:selector)
        child1 = Parselly::Node.new(:type_selector, 'div')

        grandparent.add_child(parent)
        parent.add_child(child1)

        # Cache descendants
        grandparent_descendants = grandparent.descendants
        expect(grandparent_descendants).to contain_exactly(parent, child1)

        # Replace child in parent
        child2 = Parselly::Node.new(:class_selector, 'myclass')
        parent.replace_child(0, child2)

        # Grandparent's cache should be invalidated
        new_grandparent_descendants = grandparent.descendants
        expect(new_grandparent_descendants).to contain_exactly(parent, child2)
        expect(new_grandparent_descendants).not_to be(grandparent_descendants)
      end
    end

    describe '#siblings' do
      it 'returns empty array when no parent' do
        node = Parselly::Node.new(:type_selector, 'div')
        expect(node.siblings).to eq([])
      end

      it 'returns sibling nodes excluding self' do
        parent = Parselly::Node.new(:selector_list)
        child1 = Parselly::Node.new(:type_selector, 'div')
        child2 = Parselly::Node.new(:class_selector, 'myclass')
        parent.add_child(child1)
        parent.add_child(child2)

        expect(child1.siblings).to eq([child2])
        expect(child2.siblings).to eq([child1])
      end
    end
  end
end
