# frozen_string_literal: true

require 'parselly'

RSpec.describe 'CSS Selector Parser Integration' do
  let(:parser) { Parselly::Parser.new }

  describe 'Real-world CSS selectors' do
    context 'Bootstrap selectors' do
      it 'parses Bootstrap button selectors' do
        selectors = [
          '.btn',
          '.btn-primary',
          '.btn-lg.btn-block',
          '.btn:not(:disabled):not(.disabled)',
          '.btn-group > .btn:not(:first-child)',
          '.btn-group > .btn-group:not(:last-child) > .btn',
          '.btn-toolbar .btn-group + .btn-group'
        ]

        selectors.each do |selector|
          ast = parser.parse(selector)
          expect(ast).not_to be_nil
          expect(ast.type).to eq(:selector_list)
        end
      end

      it 'parses Bootstrap form selectors' do
        selectors = [
          '.form-control',
          '.form-control:focus',
          '.form-control:disabled',
          '.form-control-plaintext',
          '.was-validated .form-control:invalid',
          '.form-check-input:checked ~ .form-check-label',
          '.custom-select[multiple]',
          'input[type="range"].custom-range'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses Bootstrap grid selectors' do
        selectors = [
          '.container',
          '.container-fluid',
          '.row',
          '.col',
          '.col-sm-6',
          '.col-md-4.col-lg-3',
          '[class^="col-"]',
          '[class*=" col-"]',
          '.row > [class^="col-"]'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end
    end

    context 'Tailwind CSS selectors' do
      it 'parses Tailwind utility selectors' do
        selectors = [
          '.hover\\:bg-blue-500:hover',
          '.focus\\:outline-none:focus',
          '.sm\\:text-center',
          '.dark\\:bg-gray-800',
          '.group:hover .group-hover\\:text-white',
          '.peer:checked ~ .peer-checked\\:bg-blue-600'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end
    end

    context 'CSS Grid and Flexbox selectors' do
      it 'parses grid-related selectors' do
        selectors = [
          '.grid > *',
          '.grid-cols-3 > :nth-child(3n+1)',
          '.flex-container > .flex-item:first-child',
          '.grid [style*="grid-area"]',
          '.flex-wrap > *:not(:last-child)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end
    end

    context 'An+B notation in pseudo-classes' do
      it 'parses :nth-child with various An+B patterns' do
        selectors = [
          # Simple number
          ':nth-child(3)',
          'li:nth-child(5)',

          # Keywords
          'tr:nth-child(even)',
          'div:nth-child(odd)',

          # An format
          ':nth-child(2n)',
          ':nth-child(3n)',

          # An+B format
          ':nth-child(2n+1)',
          ':nth-child(3n+2)',
          ':nth-child(4n+3)',

          # An-B format
          ':nth-child(2n-1)',
          ':nth-child(3n-2)',

          # n+B format
          ':nth-child(n+5)',
          ':nth-child(n+10)',

          # n-B format
          ':nth-child(n-3)',

          # Negative A
          ':nth-child(-n+3)',
          ':nth-child(-2n+5)',
          ':nth-child(-n-2)',

          # Just n
          ':nth-child(n)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'creates correct AST for An+B keyword patterns' do
        # Test 'even' keyword
        ast = parser.parse(':nth-child(even)')
        seq = ast.children.first
        pseudo_func = seq.children.find { |c| c.type == :pseudo_function }
        an_plus_b = pseudo_func.children.first
        expect(an_plus_b.type).to eq(:an_plus_b)
        expect(an_plus_b.value).to eq('even')

        # Test 'odd' keyword
        ast = parser.parse(':nth-child(odd)')
        seq = ast.children.first
        pseudo_func = seq.children.find { |c| c.type == :pseudo_function }
        an_plus_b = pseudo_func.children.first
        expect(an_plus_b.type).to eq(:an_plus_b)
        expect(an_plus_b.value).to eq('odd')

        # Test 'n' keyword
        ast = parser.parse(':nth-child(n)')
        seq = ast.children.first
        pseudo_func = seq.children.find { |c| c.type == :pseudo_function }
        an_plus_b = pseudo_func.children.first
        expect(an_plus_b.type).to eq(:an_plus_b)
        expect(an_plus_b.value).to eq('n')
      end

      it 'parses :nth-last-child with An+B patterns' do
        selectors = [
          ':nth-last-child(1)',
          ':nth-last-child(2n)',
          ':nth-last-child(2n+1)',
          'li:nth-last-child(even)',
          'tr:nth-last-child(-n+3)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses :nth-of-type with An+B patterns' do
        selectors = [
          'p:nth-of-type(2)',
          'div:nth-of-type(odd)',
          'span:nth-of-type(3n+1)',
          'h2:nth-of-type(n+2)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses :nth-last-of-type with An+B patterns' do
        selectors = [
          'p:nth-last-of-type(1)',
          'div:nth-last-of-type(2n)',
          'li:nth-last-of-type(-n+5)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses :nth-col with An+B patterns' do
        selectors = [
          ':nth-col(2)',
          ':nth-col(even)',
          ':nth-col(3n+1)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses :nth-last-col with An+B patterns' do
        selectors = [
          ':nth-last-col(1)',
          ':nth-last-col(2n+1)',
          ':nth-last-col(-n+3)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses complex selectors combining An+B notation' do
        selectors = [
          'table tr:nth-child(even) td:nth-of-type(2)',
          'ul > li:nth-child(3n+1):not(:last-child)',
          'div:nth-of-type(2n) > p:nth-child(odd)',
          '.grid > :nth-child(n+3):nth-child(-n+6)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'creates correct AST structure for An+B notation' do
        ast = parser.parse(':nth-child(2n+1)')

        # Navigate the AST: selector_list > simple_selector_sequence > pseudo_function
        selector_seq = ast.children.first
        pseudo_func = selector_seq.children.first

        expect(pseudo_func.type).to eq(:pseudo_function)
        expect(pseudo_func.value).to eq('nth-child')

        # Check the An+B argument
        an_plus_b_node = pseudo_func.children.first
        expect(an_plus_b_node.type).to eq(:an_plus_b)
        expect(an_plus_b_node.value).to eq('2n+1')
      end

      it 'preserves An+B notation values correctly' do
        test_cases = {
          ':nth-child(even)' => 'even',
          ':nth-child(odd)' => 'odd',
          ':nth-child(3)' => '3',
          ':nth-child(2n)' => '2n',
          ':nth-child(3n+1)' => '3n+1',
          ':nth-child(2n-1)' => '2n-1',
          ':nth-child(-n+3)' => '-n+3',
          ':nth-child(n)' => 'n'
        }

        test_cases.each do |selector, expected_value|
          ast = parser.parse(selector)
          # Navigate: selector_list > simple_selector_sequence > pseudo_function > an_plus_b
          selector_seq = ast.children.first
          pseudo_func = selector_seq.children.first
          an_plus_b_node = pseudo_func.children.first

          expect(an_plus_b_node.value).to eq(expected_value),
                                          "Expected #{selector} to have An+B value '#{expected_value}', got '#{an_plus_b_node.value}'"
        end
      end
    end

    context 'Modern CSS4 selectors' do
      it 'parses :is() pseudo-class' do
        selectors = [
          ':is(h1, h2, h3)',
          ':is(.error, .warning) p',
          'article :is(h1, h2, h3):is(:hover, :focus)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses :where() pseudo-class' do
        selectors = [
          ':where(h1, h2, h3)',
          ':where(.card) :where(h1, h2)',
          'nav :where(ul, ol) li'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses :has() pseudo-class' do
        selectors = [
          ':has(img)',
          'article:has(> h2)',
          '.card:has(.badge)',
          'li:has(+ li:hover)',
          'div:has(> img:only-child)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end
    end

    context 'Media query related selectors' do
      it 'parses responsive design patterns' do
        selectors = [
          '[data-mobile="true"]',
          '[class*="mobile-"]',
          '[class^="desktop-"]:not([class*="mobile"])',
          '[data-responsive]:not([data-desktop="false"])'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end
    end

    context ':not() negation pseudo-class' do
      it 'parses :not() with simple selectors' do
        selectors = [
          ':not(p)',
          'div:not(.active)',
          'button:not(#submit)',
          'input:not([disabled])',
          'a:not(:hover)',
          '*:not(::before)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses :not() with attribute selectors' do
        selectors = [
          'a:not([target="_blank"])',
          'input:not([type="hidden"])',
          '[class]:not([class*="test"])',
          'button:not([disabled]):not([aria-disabled])'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses :not() with pseudo-classes' do
        selectors = [
          'li:not(:first-child)',
          'tr:not(:nth-child(even))',
          'div:not(:empty)',
          'input:not(:checked)',
          'option:not(:disabled)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses multiple :not() pseudo-classes chained' do
        selectors = [
          'button:not(.primary):not(.secondary)',
          'input:not([type="submit"]):not([type="reset"])',
          'div:not(:first-child):not(:last-child)',
          '.btn:not(:disabled):not(.disabled)'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'parses :not() in complex selectors' do
        selectors = [
          'div > p:not(.intro)',
          'ul > li:not(:first-child) + li',
          '.container > *:not(.hidden)',
          'form input:not([type="hidden"])',
          'nav a:not(.active):hover'
        ]

        selectors.each do |selector|
          expect { parser.parse(selector) }.not_to raise_error
        end
      end

      it 'creates correct AST structure for :not()' do
        ast = parser.parse('div:not(.active)')

        # Navigate: selector_list > simple_selector_sequence
        seq = ast.children.first
        expect(seq.type).to eq(:simple_selector_sequence)

        # Should have div (type_selector) and :not() (pseudo_function)
        type_sel = seq.children.find { |c| c.type == :type_selector }
        expect(type_sel.value).to eq('div')

        pseudo_func = seq.children.find { |c| c.type == :pseudo_function }
        expect(pseudo_func.value).to eq('not')

        # :not() should contain a selector_list with .active
        selector_list = pseudo_func.children.first
        expect(selector_list.type).to eq(:selector_list)

        # Inside selector_list should be the .active class selector
        inner_seq = selector_list.children.first
        class_sel = inner_seq.children.find { |c| c.type == :class_selector }
        expect(class_sel.value).to eq('active')
      end
    end
  end

  describe 'Performance benchmarks' do
    it 'parses complex selector within reasonable time' do
      complex_selector = 'html > body > div#app > main.content > article:first-of-type > section.intro > div.container > div.row > div[class^="col-"]:nth-child(2) > p:not(:empty) + ul > li:first-child > a[href^="https://"]:not([target="_blank"])'

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      parser.parse(complex_selector)
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect(end_time - start_time).to be < 0.1 # Should parse in less than 100ms
    end

    it 'handles deeply nested selectors' do
      depth = 100
      selector = "#{'div > ' * depth}span"

      expect { parser.parse(selector) }.not_to raise_error
    end

    it 'handles long selector lists' do
      count = 100
      selector = (1..count).map { |i| ".class-#{i}" }.join(', ')

      expect { parser.parse(selector) }.not_to raise_error
    end
  end

  describe 'AST traversal and manipulation' do
    it 'allows walking the AST tree' do
      ast = parser.parse('div.container > p + span')

      visited = []
      stack = [ast]

      while (node = stack.pop)
        visited << node.type
        stack.concat(node.children.reverse)
      end

      expect(visited).to include(:selector_list)
      expect(visited).to include(:selector)
    end

    it 'supports finding nodes by type' do
      ast = parser.parse('div.class#id[attr="value"]:hover::before')

      def find_by_type(node, type, results = [])
        results << node if node.type == type
        node.children.each { |child| find_by_type(child, type, results) }
        results
      end

      class_selectors = find_by_type(ast, :class_selector)
      expect(class_selectors.length).to eq(1)
      expect(class_selectors[0].value).to eq('class')

      pseudo_elements = find_by_type(ast, :pseudo_element)
      expect(pseudo_elements.length).to eq(1)
      expect(pseudo_elements[0].value).to eq('before')
    end

    it 'can serialize AST back to selector string' do
      # This would be a useful feature to implement
      pending 'Serialization not yet implemented'

      original = 'div.container > p#content'
      ast = parser.parse(original)
      serialized = ast.to_selector # Method to implement
      expect(serialized).to eq(original)
    end
  end

  describe 'Comprehensive AST structure tests' do
    def find_node(ast, type)
      return ast if ast.type == type
      return nil unless ast.respond_to?(:children)

      ast.children.each do |child|
        found = find_node(child, type)
        return found if found
      end
      nil
    end

    def find_all_nodes(ast, type, results = [])
      results << ast if ast.type == type
      return results unless ast.respond_to?(:children)

      ast.children.each { |child| find_all_nodes(child, type, results) }
      results
    end

    context 'Combinator nodes' do
      it 'creates child_combinator node for >' do
        ast = parser.parse('div > p')
        combinator = find_node(ast, :child_combinator)

        expect(combinator).not_to be_nil
        expect(combinator.type).to eq(:child_combinator)
        expect(combinator.value).to eq('>')
      end

      it 'creates adjacent_combinator node for +' do
        ast = parser.parse('div + p')
        combinator = find_node(ast, :adjacent_combinator)

        expect(combinator).not_to be_nil
        expect(combinator.type).to eq(:adjacent_combinator)
        expect(combinator.value).to eq('+')
      end

      it 'creates sibling_combinator node for ~' do
        ast = parser.parse('div ~ p')
        combinator = find_node(ast, :sibling_combinator)

        expect(combinator).not_to be_nil
        expect(combinator.type).to eq(:sibling_combinator)
        expect(combinator.value).to eq('~')
      end

      it 'creates descendant_combinator node for space' do
        ast = parser.parse('div p')
        combinator = find_node(ast, :descendant_combinator)

        expect(combinator).not_to be_nil
        expect(combinator.type).to eq(:descendant_combinator)
        expect(combinator.value).to eq(' ')
      end
    end

    context 'Selector nodes' do
      it 'creates type_selector node for element names' do
        ast = parser.parse('div')
        type_sel = find_node(ast, :type_selector)

        expect(type_sel).not_to be_nil
        expect(type_sel.type).to eq(:type_selector)
        expect(type_sel.value).to eq('div')
      end

      it 'creates universal_selector node for *' do
        ast = parser.parse('*')
        universal = find_node(ast, :universal_selector)

        expect(universal).not_to be_nil
        expect(universal.type).to eq(:universal_selector)
        expect(universal.value).to eq('*')
      end

      it 'creates id_selector node for #id' do
        ast = parser.parse('#myid')
        id_sel = find_node(ast, :id_selector)

        expect(id_sel).not_to be_nil
        expect(id_sel.type).to eq(:id_selector)
        expect(id_sel.value).to eq('myid')
      end

      it 'creates class_selector node for .class' do
        ast = parser.parse('.myclass')
        class_sel = find_node(ast, :class_selector)

        expect(class_sel).not_to be_nil
        expect(class_sel.type).to eq(:class_selector)
        expect(class_sel.value).to eq('myclass')
      end

      it 'creates pseudo_class node for :pseudo' do
        ast = parser.parse(':hover')
        pseudo = find_node(ast, :pseudo_class)

        expect(pseudo).not_to be_nil
        expect(pseudo.type).to eq(:pseudo_class)
        expect(pseudo.value).to eq('hover')
      end

      it 'creates pseudo_element node for ::pseudo' do
        ast = parser.parse('::before')
        pseudo_elem = find_node(ast, :pseudo_element)

        expect(pseudo_elem).not_to be_nil
        expect(pseudo_elem.type).to eq(:pseudo_element)
        expect(pseudo_elem.value).to eq('before')
      end

      it 'creates simple_selector_sequence for compound selectors' do
        ast = parser.parse('div.class#id')
        seq = find_node(ast, :simple_selector_sequence)

        expect(seq).not_to be_nil
        expect(seq.type).to eq(:simple_selector_sequence)
        expect(seq.children.size).to eq(3)
      end
    end

    context 'Attribute selector nodes' do
      it 'creates attribute_selector for [attr]' do
        ast = parser.parse('[disabled]')
        attr_sel = find_node(ast, :attribute_selector)

        expect(attr_sel).not_to be_nil
        expect(attr_sel.type).to eq(:attribute_selector)
        expect(attr_sel.value).to eq('disabled')
      end

      it 'creates attribute_selector with equal_operator for [attr=value]' do
        ast = parser.parse('[type="text"]')
        attr_sel = find_node(ast, :attribute_selector)
        equal_op = find_node(ast, :equal_operator)

        expect(attr_sel).not_to be_nil
        expect(equal_op).not_to be_nil
        expect(equal_op.type).to eq(:equal_operator)
        expect(equal_op.value).to eq('=')
      end

      it 'creates includes_operator for [attr~=value]' do
        ast = parser.parse('[class~="button"]')
        includes_op = find_node(ast, :includes_operator)

        expect(includes_op).not_to be_nil
        expect(includes_op.type).to eq(:includes_operator)
        expect(includes_op.value).to eq('~=')
      end

      it 'creates dashmatch_operator for [attr|=value]' do
        ast = parser.parse('[lang|="en"]')
        dashmatch_op = find_node(ast, :dashmatch_operator)

        expect(dashmatch_op).not_to be_nil
        expect(dashmatch_op.type).to eq(:dashmatch_operator)
        expect(dashmatch_op.value).to eq('|=')
      end

      it 'creates prefixmatch_operator for [attr^=value]' do
        ast = parser.parse('[href^="https"]')
        prefix_op = find_node(ast, :prefixmatch_operator)

        expect(prefix_op).not_to be_nil
        expect(prefix_op.type).to eq(:prefixmatch_operator)
        expect(prefix_op.value).to eq('^=')
      end

      it 'creates suffixmatch_operator for [attr$=value]' do
        ast = parser.parse('[href$=".pdf"]')
        suffix_op = find_node(ast, :suffixmatch_operator)

        expect(suffix_op).not_to be_nil
        expect(suffix_op.type).to eq(:suffixmatch_operator)
        expect(suffix_op.value).to eq('$=')
      end

      it 'creates substringmatch_operator for [attr*=value]' do
        ast = parser.parse('[href*="example"]')
        substring_op = find_node(ast, :substringmatch_operator)

        expect(substring_op).not_to be_nil
        expect(substring_op.type).to eq(:substringmatch_operator)
        expect(substring_op.value).to eq('*=')
      end

      it 'creates attribute and value nodes' do
        ast = parser.parse('[data-id="123"]')
        attribute = find_node(ast, :attribute)
        value = find_node(ast, :value)

        expect(attribute).not_to be_nil
        expect(attribute.type).to eq(:attribute)
        expect(attribute.value).to eq('data-id')

        expect(value).not_to be_nil
        expect(value.type).to eq(:value)
        expect(value.value).to eq('123')
      end
    end

    context 'Pseudo-function nodes' do
      it 'creates pseudo_function node for :nth-child()' do
        ast = parser.parse(':nth-child(2n+1)')
        pseudo_func = find_node(ast, :pseudo_function)

        expect(pseudo_func).not_to be_nil
        expect(pseudo_func.type).to eq(:pseudo_function)
        expect(pseudo_func.value).to eq('nth-child')
        expect(pseudo_func.children.size).to eq(1)
      end

      it 'creates argument node for string values in pseudo-functions' do
        ast = parser.parse(':lang("en")')
        argument = find_node(ast, :argument)

        expect(argument).not_to be_nil
        expect(argument.type).to eq(:argument)
        expect(argument.value).to eq('en')
      end

      it 'creates selector_list inside :is() pseudo-function' do
        ast = parser.parse(':is(h1, h2, h3)')
        pseudo_func = find_node(ast, :pseudo_function)

        # The argument should be a selector_list
        expect(pseudo_func.children.size).to eq(1)
        child = pseudo_func.children.first
        expect(child.type).to eq(:selector_list)
        expect(child.children.size).to eq(3) # h1, h2, h3
      end
    end

    context 'Complex selector structures' do
      it 'creates proper hierarchy for complex selectors' do
        ast = parser.parse('div.container > p#intro.highlight:hover')

        # Should have selector_list at root
        expect(ast.type).to eq(:selector_list)

        # Should have a selector node with combinator
        selector = find_node(ast, :selector)
        expect(selector).not_to be_nil

        # Should have both simple_selector_sequences
        sequences = find_all_nodes(ast, :simple_selector_sequence)
        expect(sequences.size).to eq(2)

        # First sequence: div.container
        first_seq = sequences[0]
        expect(find_node(first_seq, :type_selector)&.value).to eq('div')
        expect(find_node(first_seq, :class_selector)&.value).to eq('container')

        # Second sequence: p#intro.highlight:hover
        second_seq = sequences[1]
        expect(find_node(second_seq, :type_selector)&.value).to eq('p')
        expect(find_node(second_seq, :id_selector)&.value).to eq('intro')
        expect(find_node(second_seq, :class_selector)&.value).to eq('highlight')
        expect(find_node(second_seq, :pseudo_class)&.value).to eq('hover')

        # Should have child combinator
        combinator = find_node(ast, :child_combinator)
        expect(combinator).not_to be_nil
      end

      it 'creates multiple selectors in selector_list' do
        ast = parser.parse('h1, h2, h3')

        expect(ast.type).to eq(:selector_list)
        expect(ast.children.size).to eq(3)

        ast.children.each do |child|
          expect(child.type).to eq(:simple_selector_sequence)
        end
      end

      it 'handles all combinators in one selector' do
        ast = parser.parse('div p > span + a ~ em')

        descendant = find_node(ast, :descendant_combinator)
        child = find_node(ast, :child_combinator)
        adjacent = find_node(ast, :adjacent_combinator)
        sibling = find_node(ast, :sibling_combinator)

        expect(descendant).not_to be_nil
        expect(child).not_to be_nil
        expect(adjacent).not_to be_nil
        expect(sibling).not_to be_nil
      end
    end

    context 'Node value preservation' do
      it 'preserves exact values for all selector types' do
        test_cases = {
          'myElement' => [:type_selector, 'myElement'],
          '#myId' => [:id_selector, 'myId'],
          '.myClass' => [:class_selector, 'myClass'],
          ':myPseudo' => [:pseudo_class, 'myPseudo'],
          '::myPseudoElement' => [:pseudo_element, 'myPseudoElement'],
          '[data-custom-attr]' => [:attribute_selector, 'data-custom-attr']
        }

        test_cases.each do |selector, (node_type, expected_value)|
          ast = parser.parse(selector)
          node = find_node(ast, node_type)
          expect(node&.value).to eq(expected_value),
                                 "Expected #{selector} to create #{node_type} with value '#{expected_value}'"
        end
      end

      it 'preserves operator symbols correctly' do
        operators = {
          '[a="b"]' => [:equal_operator, '='],
          '[a~="b"]' => [:includes_operator, '~='],
          '[a|="b"]' => [:dashmatch_operator, '|='],
          '[a^="b"]' => [:prefixmatch_operator, '^='],
          '[a$="b"]' => [:suffixmatch_operator, '$='],
          '[a*="b"]' => [:substringmatch_operator, '*=']
        }

        operators.each do |selector, (node_type, expected_value)|
          ast = parser.parse(selector)
          node = find_node(ast, node_type)
          expect(node&.value).to eq(expected_value),
                                 "Expected #{selector} to create #{node_type} with value '#{expected_value}'"
        end
      end

      it 'preserves combinator symbols correctly' do
        combinators = {
          'a > b' => [:child_combinator, '>'],
          'a + b' => [:adjacent_combinator, '+'],
          'a ~ b' => [:sibling_combinator, '~'],
          'a b' => [:descendant_combinator, ' ']
        }

        combinators.each do |selector, (node_type, expected_value)|
          ast = parser.parse(selector)
          node = find_node(ast, node_type)
          expect(node&.value).to eq(expected_value),
                                 "Expected #{selector} to create #{node_type} with value '#{expected_value}'"
        end
      end
    end
  end

  describe 'Error handling' do
    context 'Invalid selector syntax' do
      it 'raises error for unclosed attribute selector' do
        expect { parser.parse('[attr') }.to raise_error(/Parse error|Unexpected/)
      end

      it 'raises error for unclosed parenthesis in pseudo-function' do
        expect { parser.parse(':nth-child(2n') }.to raise_error(/Parse error|Unexpected/)
      end

      it 'raises error for invalid attribute operator' do
        expect { parser.parse('[attr==value]') }.to raise_error(/Parse error|Unexpected/)
      end

      it 'raises error for missing selector after combinator' do
        expect { parser.parse('div >') }.to raise_error(/Parse error|Unexpected/)
      end

      it 'raises error for consecutive combinators' do
        expect { parser.parse('div > > p') }.to raise_error(/Parse error|Unexpected/)
      end
    end

    context 'Invalid characters' do
      it 'raises error for invalid characters in selector' do
        expect { parser.parse('div@class') }.to raise_error(/Unexpected character/)
      end

      it 'raises error for invalid characters at start' do
        expect { parser.parse('@invalid') }.to raise_error(/Unexpected character/)
      end
    end

    context 'Empty or malformed input' do
      it 'raises error for empty string' do
        expect { parser.parse('') }.to raise_error(/Parse error|Unexpected/)
      end

      it 'raises error for only whitespace' do
        expect { parser.parse('   ') }.to raise_error(/Parse error|Unexpected/)
      end

      it 'raises error for only combinator' do
        expect { parser.parse('>') }.to raise_error(/Parse error|Unexpected/)
      end
    end
  end
end
