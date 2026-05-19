# frozen_string_literal: true

module Parselly
  # Represents a node in the Abstract Syntax Tree (AST) for CSS selectors.
  class Node
    include Enumerable

    SIMPLE_SELECTOR_TYPES = Set[
      :type_selector,
      :universal_selector,
      :id_selector,
      :class_selector,
      :attribute_selector,
      :pseudo_class,
      :pseudo_function,
      :pseudo_element,
      :pseudo_element_function
    ].freeze

    COMBINATOR_TYPES = {
      child_combinator: '>',
      adjacent_combinator: '+',
      sibling_combinator: '~',
      descendant_combinator: ' ',
      column_combinator: '||'
    }.freeze

    SPECIFICITY_ZERO_PSEUDO_FUNCTIONS = Set['where'].freeze
    SPECIFICITY_MAX_ARGUMENT_PSEUDO_FUNCTIONS = Set['is', 'not', 'has'].freeze
    NTH_PSEUDO_FUNCTIONS = Set['nth-child', 'nth-last-child', 'nth-of-type', 'nth-last-of-type', 'nth-col', 'nth-last-col'].freeze

    class ChildList < Array
      def initialize(owner)
        @owner = owner
        super()
      end

      def <<(node)
        return self if node.nil?

        @owner.__send__(:adopt_child, node)
        super(node)
        @owner.__send__(:invalidate_cache)
        self
      end

      def push(*nodes)
        nodes.each { |node| self << node }
        self
      end

      def concat(nodes)
        nodes.each { |node| self << node }
        self
      end

      def []=(index, node)
        old_node = self[index]
        @owner.__send__(:detach_child, old_node) if old_node
        @owner.__send__(:adopt_child, node)
        super
        @owner.__send__(:invalidate_cache)
        node
      end

      def insert(index, *nodes)
        nodes.each { |node| @owner.__send__(:adopt_child, node) }
        result = super
        @owner.__send__(:invalidate_cache)
        result
      end

      def delete_at(index)
        node = super
        @owner.__send__(:detach_child, node) if node
        @owner.__send__(:invalidate_cache)
        node
      end

      def delete(node)
        deleted = super
        @owner.__send__(:detach_child, deleted) if deleted
        @owner.__send__(:invalidate_cache) if deleted
        deleted
      end

      def clear
        each { |node| @owner.__send__(:detach_child, node) }
        result = super
        @owner.__send__(:invalidate_cache)
        result
      end

      private
    end

    attr_accessor :type, :value, :raw_value, :parent, :position, :namespace, :quote, :modifier
    attr_reader :children

    def initialize(type, value = nil, position = {}, raw_value: nil, line: nil, column: nil, offset: nil,
                   namespace: nil, quote: nil, modifier: nil)
      @type = type
      @value = value
      @raw_value = raw_value.nil? ? value : raw_value
      @children = ChildList.new(self)
      @parent = nil
      @namespace = namespace
      @quote = quote
      @modifier = modifier
      unless position.nil? || position.is_a?(Hash)
        raise ArgumentError, 'position must be a Hash'
      end

      resolved_position = position ? position.dup : {}
      resolved_position[:line] = line unless line.nil?
      resolved_position[:column] = column unless column.nil?
      resolved_position[:offset] = offset unless offset.nil?
      @position = resolved_position
      @descendants_cache = nil
    end

    def children=(nodes)
      @children.clear
      Array(nodes).each { |node| add_child(node) }
    end

    def add_child(node)
      return nil if node.nil?

      @children << node
      node
    end

    def replace_child(index, new_node)
      return nil if new_node.nil?
      return nil if index.negative? || index >= @children.size

      @children[index] = new_node
    end

    def insert_child(index, node)
      return nil if node.nil?
      return nil if index.negative? || index > @children.size

      @children.insert(index, node)
      node
    end

    def remove_child(node_or_index)
      if node_or_index.is_a?(Integer)
        return nil if node_or_index.negative? || node_or_index >= @children.size

        return @children.delete_at(node_or_index)
      end

      @children.delete(node_or_index)
    end

    def insert_before(reference_child, new_child)
      index = @children.index(reference_child)
      return nil unless index

      insert_child(index, new_child)
    end

    def insert_after(reference_child, new_child)
      index = @children.index(reference_child)
      return nil unless index

      insert_child(index + 1, new_child)
    end

    def ancestors
      result = []
      node = parent
      while node
        result << node
        node = node.parent
      end
      result
    end

    def descendants
      return @descendants_cache if @descendants_cache

      @descendants_cache = []
      queue = @children.to_a
      index = 0
      while index < queue.length
        node = queue[index]
        @descendants_cache << node
        queue.concat(node.children) unless node.children.empty?
        index += 1
      end
      @descendants_cache
    end

    def each
      return enum_for(:each) unless block_given?

      stack = [self]
      until stack.empty?
        node = stack.pop
        yield node
        stack.concat(node.children.reverse) unless node.children.empty?
      end

      self
    end

    def find_all(type)
      each.select { |node| node.type == type }
    end

    def siblings
      return [] unless parent

      parent.children.reject { |child| child == self }
    end

    def to_tree(indent = 0)
      lines = []
      prefix = '  ' * indent
      pos_info = position.empty? ? '' : " [#{position[:line]}:#{position[:column]}]"

      lines << "#{prefix}#{type}#{"(#{value.inspect})" if value}#{pos_info}"
      children.each { |child| lines << child.to_tree(indent + 1) }
      lines.join("\n")
    end

    def inspect
      "#<#{self.class.name} type=#{type} value=#{value.inspect} children=#{children.size}>"
    end

    def to_selector(mode: :normalized)
      validate_selector_mode!(mode)

      case type
      when :selector_list
        children.map { |child| child.to_selector(mode: mode) }.join(', ')
      when :selector, :simple_selector_sequence
        children.map { |child| child.to_selector(mode: mode) }.join
      when :type_selector, :universal_selector
        selector_name(mode)
      when :id_selector
        "##{selector_identifier(mode)}"
      when :class_selector
        ".#{selector_identifier(mode)}"
      when :attribute_selector
        build_attribute_selector(mode)
      when :pseudo_class
        ":#{selector_identifier(mode)}"
      when :pseudo_element
        "::#{selector_identifier(mode)}"
      when :pseudo_function
        ":#{selector_identifier(mode)}(#{children.map { |child| child.to_selector(mode: mode) }.join})"
      when :pseudo_element_function
        "::#{selector_identifier(mode)}(#{children.map { |child| child.to_selector(mode: mode) }.join})"
      when :child_combinator
        ' > '
      when :adjacent_combinator
        ' + '
      when :sibling_combinator
        ' ~ '
      when :descendant_combinator
        ' '
      when :column_combinator
        ' || '
      when :nth_selector_argument
        "#{children[0].to_selector(mode: mode)} of #{children[1].to_selector(mode: mode)}"
      when :an_plus_b
        value.to_s
      when :argument
        argument_selector(mode)
      when :attribute, :value,
           :equal_operator, :includes_operator, :dashmatch_operator,
           :prefixmatch_operator, :suffixmatch_operator, :substringmatch_operator
        value.to_s
      else
        children.map { |child| child.to_selector(mode: mode) }.join
      end
    end

    def id?
      any? { |node| node.type == :id_selector }
    end

    def id
      ids.first
    end

    def ids
      each.with_object([]) { |node, result| result << node.value if node.type == :id_selector }
    end

    def classes
      each.with_object([]) { |node, result| result << node.value if node.type == :class_selector }
    end

    def attribute?
      any? { |node| node.type == :attribute_selector }
    end

    def attributes
      attribute_selector_nodes.map { |node| extract_attribute_info(node) }
    end

    def attribute_selectors
      attribute_selector_nodes.map { |node| extract_attribute_node(node) }
    end

    def pseudo_classes
      each.with_object([]) do |node, result|
        if [:pseudo_class, :pseudo_element, :pseudo_function, :pseudo_element_function].include?(node.type)
          result << node.value
        end
      end
    end

    def pseudo_class_names
      each.with_object([]) { |node, result| result << node.value if node.type == :pseudo_class }
    end

    def pseudo_element_names
      each.with_object([]) do |node, result|
        result << node.value if [:pseudo_element, :pseudo_element_function].include?(node.type)
      end
    end

    def pseudo_function_names
      each.with_object([]) { |node, result| result << node.value if node.type == :pseudo_function }
    end

    def type_selector?
      any? { |node| node.type == :type_selector }
    end

    def type_names
      each.with_object([]) { |node, result| result << node.value if node.type == :type_selector }
    end

    def type_selectors
      each.with_object([]) do |node, result|
        next unless node.type == :type_selector

        detail = { name: node.value, raw_name: node.raw_value, position: node.position }
        detail[:namespace] = node.namespace unless node.namespace.nil?
        result << detail
      end
    end

    def combinators
      each.with_object([]) do |node, result|
        next unless COMBINATOR_TYPES.key?(node.type)

        result << { type: node.type, value: node.value, position: node.position }
      end
    end

    def selector_list?
      type == :selector_list
    end

    def complex_selector?
      type == :selector || any? { |node| COMBINATOR_TYPES.key?(node.type) }
    end

    def compound_selector?
      case type
      when :selector_list
        children.size == 1 && children.first.compound_selector?
      when :simple_selector_sequence
        children.count { |child| SIMPLE_SELECTOR_TYPES.include?(child.type) } > 1
      else
        false
      end
    end

    def specificity
      case type
      when :selector_list
        children.map(&:specificity).max || [0, 0, 0]
      when :selector, :simple_selector_sequence
        children.reduce([0, 0, 0]) { |sum, child| add_specificity(sum, child.specificity) }
      when :id_selector
        [1, 0, 0]
      when :class_selector, :attribute_selector, :pseudo_class
        [0, 1, 0]
      when :type_selector, :pseudo_element, :pseudo_element_function
        [0, 0, 1]
      when :pseudo_function
        pseudo_function_specificity
      else
        [0, 0, 0]
      end
    end

    def to_h
      hash = {
        type: type,
        value: value,
        raw_value: raw_value,
        namespace: namespace,
        quote: quote,
        modifier: modifier,
        position: position,
        children: children.map(&:to_h)
      }
      hash.delete_if { |key, val| key != :children && (val.nil? || val == {}) }
    end

    def as_json(*)
      to_h
    end

    def deconstruct_keys(keys)
      hash = to_h
      return hash if keys.nil?

      keys.each_with_object({}) { |key, result| result[key] = hash[key] if hash.key?(key) }
    end

    def freeze_tree
      children.each(&:freeze_tree)
      children.freeze
      freeze
    end

    def dup_tree
      duplicate = self.class.new(
        type,
        value,
        position.dup,
        raw_value: raw_value,
        namespace: namespace,
        quote: quote,
        modifier: modifier
      )
      children.each { |child| duplicate.add_child(child.dup_tree) }
      duplicate
    end
    alias deep_dup dup_tree

    private

    def adopt_child(node)
      raise ArgumentError, 'child must be a Parselly::Node' unless node.is_a?(Node)

      node.parent.remove_child(node) if node.parent && node.parent != self
      node.parent = self
    end

    def detach_child(node)
      node.parent = nil if node&.parent == self
    end

    def invalidate_cache
      node = self
      while node
        node.instance_variable_set(:@descendants_cache, nil)
        node = node.parent
      end
    end

    def attribute_selector_nodes
      each.select { |node| node.type == :attribute_selector }
    end

    def extract_attribute_info(node)
      info = {}

      if node.value
        info[:name] = node.value
        return info
      end

      node.children.each do |child|
        case child.type
        when :attribute
          info[:name] = child.value
        when :equal_operator, :includes_operator, :dashmatch_operator,
             :prefixmatch_operator, :suffixmatch_operator, :substringmatch_operator
          info[:operator] = child.value
        when :value
          info[:value] = child.value
        end
      end

      info[:modifier] = node.modifier if node.modifier
      info
    end

    def extract_attribute_node(node)
      info = {}

      if node.value
        info[:name] = node.value
        info[:raw_name] = node.raw_value
        info[:namespace] = node.namespace unless node.namespace.nil?
        info[:position] = node.position unless node.position.empty?
        return info
      end

      info[:modifier] = node.modifier if node.modifier
      node.children.each do |child|
        case child.type
        when :attribute
          info[:name] = child.value
          info[:raw_name] = child.raw_value
          info[:namespace] = child.namespace unless child.namespace.nil?
          info[:position] = child.position unless child.position.empty?
        when :equal_operator, :includes_operator, :dashmatch_operator,
             :prefixmatch_operator, :suffixmatch_operator, :substringmatch_operator
          info[:operator] = child.value
        when :value
          info[:value] = child.value
          info[:raw_value] = child.raw_value
          info[:quote] = child.quote if child.quote
        end
      end

      info
    end

    def build_attribute_selector(mode)
      if value
        return "[#{attribute_name_for(self, mode)}]"
      end

      attr_name = nil
      operator = nil
      attr_value = nil

      children.each do |child|
        case child.type
        when :attribute
          attr_name = attribute_name_for(child, mode)
        when :equal_operator, :includes_operator, :dashmatch_operator,
             :prefixmatch_operator, :suffixmatch_operator, :substringmatch_operator
          operator = child.value
        when :value
          attr_value = attribute_value_for(child, mode)
        end
      end

      modifier_part = modifier ? " #{modifier}" : ''
      operator && attr_value ? "[#{attr_name}#{operator}#{attr_value}#{modifier_part}]" : "[#{attr_name}]"
    end

    def attribute_name_for(node, mode)
      return node.raw_value.to_s if mode == :preserve && node.raw_value

      local = Parselly.sanitize(node.value.to_s)
      return local if node.namespace.nil?

      prefix = node.namespace == '*' ? '*' : Parselly.sanitize(node.namespace.to_s)
      "#{prefix}|#{local}"
    end

    def attribute_value_for(node, mode)
      if mode == :preserve
        value = node.raw_value.to_s
        return "#{node.quote}#{value}#{node.quote}" if node.quote

        return value
      end

      "\"#{escape_string(node.value.to_s)}\""
    end

    def selector_name(mode)
      return raw_value.to_s if mode == :preserve && raw_value

      local = value == '*' ? '*' : Parselly.sanitize(value.to_s)
      return local if namespace.nil?

      prefix = namespace == '*' ? '*' : Parselly.sanitize(namespace.to_s)
      "#{prefix}|#{local}"
    end

    def selector_identifier(mode)
      return raw_value.to_s if mode == :preserve && raw_value

      Parselly.sanitize(value.to_s)
    end

    def argument_selector(mode)
      if quote
        value = mode == :preserve ? raw_value.to_s : escape_string(value.to_s)
        return "#{quote}#{value}#{quote}"
      end

      mode == :preserve && raw_value ? raw_value.to_s : value.to_s
    end

    def escape_string(string)
      string.each_char.with_object(+'') do |char, result|
        case char
        when '"', '\\'
          result << "\\#{char}"
        when "\n"
          result << '\\a '
        when "\r"
          result << '\\d '
        when "\f"
          result << '\\c '
        else
          result << char
        end
      end
    end

    def validate_selector_mode!(mode)
      return if [:normalized, :preserve].include?(mode)

      raise ArgumentError, "unknown selector serialization mode: #{mode.inspect}"
    end

    def pseudo_function_specificity
      return [0, 0, 0] if SPECIFICITY_ZERO_PSEUDO_FUNCTIONS.include?(value)

      if SPECIFICITY_MAX_ARGUMENT_PSEUDO_FUNCTIONS.include?(value)
        child = children.first
        return child ? child.specificity : [0, 0, 0]
      end

      if NTH_PSEUDO_FUNCTIONS.include?(value)
        nth_argument = children.first
        selector_specificity = nth_argument&.type == :nth_selector_argument ? nth_argument.children[1].specificity : [0, 0, 0]
        return add_specificity([0, 1, 0], selector_specificity)
      end

      [0, 1, 0]
    end

    def add_specificity(left, right)
      [left[0] + right[0], left[1] + right[1], left[2] + right[2]]
    end
  end
end
