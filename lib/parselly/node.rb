# frozen_string_literal: true

module Parselly
  class Node
    attr_accessor :type, :value, :children, :parent, :position

    def initialize(type, value = nil, position = {})
      @type = type
      @value = value
      @children = []
      @parent = nil
      @position = position
    end

    def add_child(node)
      node.parent = self
      @children << node
      node
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
      result = []
      @children.each do |child|
        result << child
        result.concat(child.descendants)
      end
      result
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
