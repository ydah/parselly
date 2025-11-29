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
    end

    # Adds a child node to this node.
    #
    # @param node [Node, nil] the child node to add
    # @return [Node, nil] the added node, or nil if the input was nil
    def add_child(node)
      return nil if node.nil?

      node.parent = self
      @children << node
      node
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
      result = []
      @children.each do |child|
        result << child
        result.concat(child.descendants)
      end
      result
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
  end
end
