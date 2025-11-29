# frozen_string_literal: true

module Parselly
  # Represents a node in the Abstract Syntax Tree (AST) for CSS selectors.
  #
  # Each Node represents a parsed CSS selector component (e.g., type selector,
  # class selector, combinator, or selector list) with its type, optional value,
  # child nodes, parent reference, and source position.
  #
  # @example Creating a simple AST node
  #   node = Parselly::Node.new(:type_selector, 'div', { line: 1, column: 1 })
  #   node.add_child(Parselly::Node.new(:class_selector, 'container'))
  #
  # @example Traversing the AST
  #   node.ancestors    # Returns array of ancestor nodes
  #   node.descendants  # Returns array of all descendant nodes
  #   node.siblings     # Returns array of sibling nodes
  class Node
    attr_accessor :type, :value, :children, :parent, :position

    # Creates a new AST node.
    #
    # @param type [Symbol] the type of the node (e.g., :type_selector, :class_selector)
    # @param value [String, nil] optional value associated with the node
    # @param position [Hash] source position with :line and :column keys
    def initialize(type, value = nil, position = {})
      @type = type
      @value = value
      @children = []
      @parent = nil
      @position = position
      @descendants_cache = nil
    end

    # Adds a child node to this node.
    #
    # @param node [Node, nil] the child node to add
    # @return [Node, nil] the added node, or nil if the input was nil
    def add_child(node)
      return nil if node.nil?

      node.parent = self
      @children << node
      invalidate_cache
      node
    end

    # Replaces a child node at the specified index.
    #
    # @param index [Integer] the index of the child to replace
    # @param new_node [Node] the new child node
    # @return [Node, nil] the new node, or nil if invalid parameters
    def replace_child(index, new_node)
      return nil if new_node.nil?
      return nil if index < 0 || index >= @children.size

      old_node = @children[index]
      old_node.parent = nil if old_node

      @children[index] = new_node
      new_node.parent = self
      invalidate_cache
      new_node
    end

    # Returns an array of all ancestor nodes from parent to root.
    #
    # @return [Array<Node>] array of ancestor nodes
    def ancestors
      result = []
      node = parent
      while node
        result << node
        node = node.parent
      end
      result
    end

    # Returns an array of all descendant nodes (children, grandchildren, etc.).
    #
    # @return [Array<Node>] array of all descendant nodes
    def descendants
      return @descendants_cache if @descendants_cache

      @descendants_cache = []
      queue = @children.dup
      until queue.empty?
        node = queue.shift
        @descendants_cache << node
        queue.concat(node.children) unless node.children.empty?
      end
      @descendants_cache
    end

    # Returns an array of sibling nodes (excluding self).
    #
    # @return [Array<Node>] array of sibling nodes, or empty array if no parent
    def siblings
      return [] unless parent

      parent.children.reject { |child| child == self }
    end

    # Returns a tree representation of this node and its descendants.
    #
    # @param indent [Integer] indentation level for the tree display
    # @return [String] formatted tree string
    def to_tree(indent = 0)
      lines = []
      prefix = '  ' * indent
      pos_info = position.empty? ? '' : " [#{position[:line]}:#{position[:column]}]"

      lines << "#{prefix}#{type}#{"(#{value.inspect})" if value}#{pos_info}"

      children.each do |child|
        lines << child.to_tree(indent + 1)
      end

      lines.join("\n")
    end

    def inspect
      "#<#{self.class.name} type=#{type} value=#{value.inspect} children=#{children.size}>"
    end

    # Converts the AST node back to a CSS selector string.
    #
    # @return [String] the CSS selector string representation of this node
    def to_selector
      case type
      when :selector_list
        children.map(&:to_selector).join(', ')
      when :selector
        children.map(&:to_selector).join
      when :simple_selector_sequence
        children.map(&:to_selector).join
      when :type_selector
        value
      when :universal_selector
        value
      when :id_selector
        "##{value}"
      when :class_selector
        ".#{value}"
      when :attribute_selector
        build_attribute_selector
      when :pseudo_class
        ":#{value}"
      when :pseudo_element
        "::#{value}"
      when :pseudo_function
        ":#{value}(#{children.map(&:to_selector).join})"
      when :child_combinator
        ' > '
      when :adjacent_combinator
        ' + '
      when :sibling_combinator
        ' ~ '
      when :descendant_combinator
        ' '
      when :an_plus_b, :argument
        value
      when :attribute, :value
        value
      when :equal_operator, :includes_operator, :dashmatch_operator,
           :prefixmatch_operator, :suffixmatch_operator, :substringmatch_operator
        value
      else
        children.map(&:to_selector).join
      end
    end

    # Checks if this node or any descendant contains an ID selector.
    #
    # @return [Boolean] true if an ID selector is present
    def id?
      return true if type == :id_selector
      descendants.any? { |node| node.type == :id_selector }
    end

    # Extracts the ID value from this node or its descendants.
    #
    # @return [String, nil] the ID value without the '#' prefix, or nil if no ID selector is found
    def id
      return value if type == :id_selector

      descendants.each do |node|
        return node.value if node.type == :id_selector
      end
      nil
    end

    # Extracts all class names from this node and its descendants.
    #
    # @return [Array<String>] array of class names without the '.' prefix
    def classes
      result = []
      result << value if type == :class_selector
      descendants.each do |node|
        result << node.value if node.type == :class_selector
      end
      result
    end

    # Checks if this node or any descendant contains an attribute selector.
    #
    # @return [Boolean] true if an attribute selector is present
    def attribute?
      return true if type == :attribute_selector
      descendants.any? { |node| node.type == :attribute_selector }
    end

    # Extracts all attribute selectors from this node and its descendants.
    #
    # @return [Array<Hash>] array of attribute information hashes
    #   Each hash contains :name, :operator (optional), and :value (optional) keys
    def attributes
      result = []

      if type == :attribute_selector
        result << extract_attribute_info(self)
      end

      descendants.each do |node|
        if node.type == :attribute_selector
          result << extract_attribute_info(node)
        end
      end

      result
    end

    # Extracts all pseudo-classes and pseudo-elements from this node and its descendants.
    #
    # @return [Array<String>] array of pseudo-class and pseudo-element names
    def pseudo_classes
      result = []

      if [:pseudo_class, :pseudo_element, :pseudo_function].include?(type)
        result << value
      end

      descendants.each do |node|
        if [:pseudo_class, :pseudo_element, :pseudo_function].include?(node.type)
          result << node.value
        end
      end

      result
    end

    # Checks if this selector is a compound selector, as defined by CSS.
    # A compound selector combines multiple simple selectors (type, class, id,
    # attribute, pseudo-class) without combinators (e.g., `div.class#id[attr]:hover`).
    # Returns true if more than one simple selector type is present.
    #
    # @return [Boolean] true if this node represents a compound selector
    def compound_selector?
      types = []

      types << :id if id?
      types << :class unless classes.empty?
      types << :attribute if attribute?
      types << :pseudo unless pseudo_classes.empty?
      types << :type if type_selector?

      types.size > 1
    end

    # Checks if this node or any descendant contains a type selector.
    #
    # @return [Boolean] true if a type selector is present
    def type_selector?
      return true if type == :type_selector
      descendants.any? { |node| node.type == :type_selector }
    end

    private

    # Invalidates the descendants cache for this node and all ancestors.
    # This ensures that cached descendants are cleared when the tree structure changes.
    def invalidate_cache
      node = self
      while node
        node.instance_variable_set(:@descendants_cache, nil)
        node = node.parent
      end
    end

    # Helper method to extract attribute information from an attribute_selector node.
    #
    # @param node [Node] an attribute_selector node
    # @return [Hash] attribute information hash
    def extract_attribute_info(node)
      info = {}

      # Simple attribute selector like [disabled]
      if node.value
        info[:name] = node.value
        return info
      end

      # Attribute selector with operator and value like [type="text"]
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

      info
    end

    # Helper method to build an attribute selector string.
    #
    # @return [String] the attribute selector string
    def build_attribute_selector
      # Simple attribute selector like [disabled]
      return "[#{value}]" if value

      # Attribute selector with operator and value like [type="text"]
      attr_name = nil
      operator = nil
      attr_value = nil

      children.each do |child|
        case child.type
        when :attribute
          attr_name = child.value
        when :equal_operator, :includes_operator, :dashmatch_operator,
             :prefixmatch_operator, :suffixmatch_operator, :substringmatch_operator
          operator = child.value
        when :value
          attr_value = child.value
        end
      end

      if operator && attr_value
        "[#{attr_name}#{operator}\"#{attr_value}\"]"
      else
        "[#{attr_name}]"
      end
    end
  end
end
