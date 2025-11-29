class Parselly::Parser
  expect 0
  error_on_expect_mismatch
  token IDENT STRING NUMBER
        HASH DOT STAR
        LBRACKET RBRACKET
        LPAREN RPAREN
        COLON COMMA
        CHILD ADJACENT SIBLING DESCENDANT
        EQUAL INCLUDES DASHMATCH
        PREFIXMATCH SUFFIXMATCH SUBSTRINGMATCH
        MINUS

  # Precedence rules to resolve shift/reduce conflicts in an_plus_b grammar
  # These rules ensure that in patterns like "2n+1" or "n-3", the operators
  # (+/-) are shifted rather than reducing early. This allows proper parsing
  # of An+B notation used in :nth-child() and similar pseudo-classes.
  # Lower precedence comes first
  prechigh
    left ADJACENT MINUS  # In an_plus_b context, shift these operators
    nonassoc IDENT       # Prevent premature reduction when IDENT follows NUMBER
  preclow
rule
  selector_list
    : complex_selector (COMMA complex_selector)*
      {
        result = Node.new(:selector_list, nil, @current_position)
        result.add_child(val[0])
        val[1].each { |pair| result.add_child(pair[1]) }
      }
    ;

  complex_selector
    : compound_selector (combinator compound_selector)*
      {
        if val[1].empty?
          result = val[0]
        else
          result = val[0]
          val[1].each do |pair|
            node = Node.new(:selector, nil, result.position)
            node.add_child(result)
            node.add_child(pair[0])
            node.add_child(pair[1])
            result = node
          end
        end
      }
    ;

  combinator
    : CHILD
      { result = Node.new(:child_combinator, '>', @current_position) }
    | ADJACENT
      { result = Node.new(:adjacent_combinator, '+', @current_position) }
    | SIBLING
      { result = Node.new(:sibling_combinator, '~', @current_position) }
    | DESCENDANT
      { result = Node.new(:descendant_combinator, ' ', @current_position) }
    ;

  compound_selector
    : simple_selector_head simple_selector_tail
      {
        result = Node.new(:simple_selector_sequence, nil, val[0].position)
        result.add_child(val[0])
        val[1].each { |sel| result.add_child(sel) } unless val[1].empty?
      }
    ;

  simple_selector_head
    : type_selector
      { result = val[0] }
    | subclass_selector
      { result = val[0] }
    ;

  simple_selector_tail
    : subclass_selector*
      { result = val[0] }
    ;

  type_selector
    : IDENT
      { result = Node.new(:type_selector, val[0], @current_position) }
    | STAR
      { result = Node.new(:universal_selector, '*', @current_position) }
    ;

  subclass_selector
    : id_selector
      { result = val[0] }
    | class_selector
      { result = val[0] }
    | attribute_selector
      { result = val[0] }
    | pseudo_class_selector
      { result = val[0] }
    | pseudo_element_selector
      { result = val[0] }
    ;

  id_selector
    : HASH IDENT
      { result = Node.new(:id_selector, val[1], @current_position) }
    ;

  class_selector
    : DOT IDENT
      { result = Node.new(:class_selector, val[1], @current_position) }
    ;

  attribute_selector
    : LBRACKET IDENT RBRACKET
      { result = Node.new(:attribute_selector, val[1], @current_position) }
    | LBRACKET IDENT attr_matcher STRING RBRACKET
      {
        result = Node.new(:attribute_selector, nil, @current_position)
        result.add_child(Node.new(:attribute, val[1], @current_position))
        result.add_child(val[2])
        result.add_child(Node.new(:value, val[3], @current_position))
      }
    | LBRACKET IDENT attr_matcher IDENT RBRACKET
      {
        result = Node.new(:attribute_selector, nil, @current_position)
        result.add_child(Node.new(:attribute, val[1], @current_position))
        result.add_child(val[2])
        result.add_child(Node.new(:value, val[3], @current_position))
      }
    ;

  attr_matcher
    : EQUAL
      { result = Node.new(:equal_operator, '=', @current_position) }
    | INCLUDES
      { result = Node.new(:includes_operator, '~=', @current_position) }
    | DASHMATCH
      { result = Node.new(:dashmatch_operator, '|=', @current_position) }
    | PREFIXMATCH
      { result = Node.new(:prefixmatch_operator, '^=', @current_position) }
    | SUFFIXMATCH
      { result = Node.new(:suffixmatch_operator, '$=', @current_position) }
    | SUBSTRINGMATCH
      { result = Node.new(:substringmatch_operator, '*=', @current_position) }
    ;

  pseudo_class_selector
    : COLON IDENT
      { result = Node.new(:pseudo_class, val[1], @current_position) }
    | COLON IDENT LPAREN any_value RPAREN
      {
        fn = Node.new(:pseudo_function, val[1], @current_position)
        fn.add_child(val[3])
        result = fn
      }
    ;

  pseudo_element_selector
    : COLON COLON IDENT
      { result = Node.new(:pseudo_element, val[2], @current_position) }
    ;

  any_value
    : STRING
      { result = Node.new(:argument, val[0], @current_position) }
    | an_plus_b
      { result = val[0] }
    | relative_selector_list
      { result = val[0] }
    ;

  an_plus_b
    # Positive coefficient cases
    : NUMBER IDENT ADJACENT NUMBER
      {
        # Handle 'An+B' like '2n+1'
        result = Node.new(:an_plus_b, "#{val[0]}#{val[1]}+#{val[3]}", @current_position)
      }
    | NUMBER IDENT MINUS NUMBER
      {
        # Handle 'An-B' like '2n-1'
        result = Node.new(:an_plus_b, "#{val[0]}#{val[1]}-#{val[3]}", @current_position)
      }
    | NUMBER IDENT
      {
        # Handle 'An' like '2n' or composite like '2n-1' (when '-1' is part of IDENT)
        result = Node.new(:an_plus_b, "#{val[0]}#{val[1]}", @current_position)
      }
    | IDENT ADJACENT NUMBER
      {
        # Handle 'n+B' like 'n+5' or keywords followed by offset (rare but valid)
        result = Node.new(:an_plus_b, "#{val[0]}+#{val[2]}", @current_position)
      }
    | IDENT MINUS NUMBER
      {
        # Handle 'n-B' like 'n-3'
        result = Node.new(:an_plus_b, "#{val[0]}-#{val[2]}", @current_position)
      }
    # Negative coefficient cases
    | MINUS NUMBER IDENT ADJACENT NUMBER
      {
        # Handle '-An+B' like '-2n+1'
        result = Node.new(:an_plus_b, "-#{val[1]}#{val[2]}+#{val[4]}", @current_position)
      }
    | MINUS NUMBER IDENT MINUS NUMBER
      {
        # Handle '-An-B' like '-2n-1'
        result = Node.new(:an_plus_b, "-#{val[1]}#{val[2]}-#{val[4]}", @current_position)
      }
    | MINUS NUMBER IDENT
      {
        # Handle '-An' like '-2n' or composite like '-2n+1' (when '+1' is part of IDENT)
        result = Node.new(:an_plus_b, "-#{val[1]}#{val[2]}", @current_position)
      }
    | MINUS IDENT ADJACENT NUMBER
      {
        # Handle '-n+B' like '-n+3'
        result = Node.new(:an_plus_b, "-#{val[1]}+#{val[3]}", @current_position)
      }
    | MINUS IDENT MINUS NUMBER
      {
        # Handle '-n-B' like '-n-2'
        result = Node.new(:an_plus_b, "-#{val[1]}-#{val[3]}", @current_position)
      }
    | MINUS IDENT
      {
        # Handle '-n' or composite like '-n+3' (when '+3' is part of IDENT)
        result = Node.new(:an_plus_b, "-#{val[1]}", @current_position)
      }
    # Simple cases
    | NUMBER
      {
        # Handle just a number like '3'
        result = Node.new(:an_plus_b, val[0].to_s, @current_position)
      }
    ;

  relative_selector_list
    : relative_selector (COMMA relative_selector)*
      {
        result = Node.new(:selector_list, nil, @current_position)
        result.add_child(val[0])
        val[1].each { |pair| result.add_child(pair[1]) }
      }
    ;

  relative_selector
    : complex_selector
      { result = val[0] }
    | combinator complex_selector
      {
        result = Node.new(:selector, nil, val[0].position)
        result.add_child(val[0])
        result.add_child(val[1])
      }
    ;

end

---- header
require 'set'

---- inner
def parse(input)
  @lexer = Parselly::Lexer.new(input)
  @tokens = @lexer.tokenize
  preprocess_tokens!
  @index = 0
  @current_position = { line: 1, column: 1 }
  ast = do_parse
  normalize_an_plus_b(ast)
  ast
end

def preprocess_tokens!
  return if @tokens.size <= 1

  new_tokens = Array.new(@tokens.size + (@tokens.size / 2)) # Pre-allocate with conservative estimate
  new_tokens_idx = 0

  last_idx = @tokens.size - 1
  @tokens.each_with_index do |token, i|
    new_tokens[new_tokens_idx] = token
    new_tokens_idx += 1

    if i < last_idx
      next_token = @tokens[i + 1]
      if needs_descendant?(token, next_token)
        pos = { line: token[2][:line], column: token[2][:column] }
        new_tokens[new_tokens_idx] = [:DESCENDANT, ' ', pos]
        new_tokens_idx += 1
      end
    end
  end

  @tokens = new_tokens.first(new_tokens_idx)
end

# Pre-computed sets for faster lookup
CAN_END_COMPOUND = Set[:IDENT, :STAR, :RPAREN, :RBRACKET].freeze
CAN_START_COMPOUND = Set[:IDENT, :STAR, :DOT, :HASH, :LBRACKET, :COLON].freeze
TYPE_SELECTOR_TYPES = Set[:IDENT, :STAR].freeze
SUBCLASS_SELECTOR_TYPES = Set[:DOT, :HASH, :LBRACKET, :COLON].freeze

# Insert DESCENDANT combinator if:
# - Current token can end a compound selector
# - Next token can start a compound selector
# - EXCEPT when current is type_selector and next is subclass_selector
#   (they belong to the same compound selector)
def needs_descendant?(current, next_tok)
  current_type = current[0]
  next_type = next_tok[0]

  # Type selector followed by subclass selector = same compound
  return false if TYPE_SELECTOR_TYPES.include?(current_type) &&
                  SUBCLASS_SELECTOR_TYPES.include?(next_type)

  CAN_END_COMPOUND.include?(current_type) && CAN_START_COMPOUND.include?(next_type)
end

NTH_PSEUDO_NAMES = Set['nth-child', 'nth-last-child', 'nth-of-type', 'nth-last-of-type', 'nth-col', 'nth-last-col'].freeze
AN_PLUS_B_REGEX = /^(even|odd|[+-]?\d*n(?:[+-]\d+)?|[+-]?n(?:[+-]\d+)?|\d+)$/.freeze

def normalize_an_plus_b(node)
  return unless node.respond_to?(:children) && node.children

  if node.type == :pseudo_function && NTH_PSEUDO_NAMES.include?(node.value)
    child = node.children.first
    if child&.type == :selector_list
      an_plus_b_value = extract_an_plus_b_value(child)
      if an_plus_b_value
        node.replace_child(0, Node.new(:an_plus_b, an_plus_b_value, child.position))
      end
    end
  end
  node.children.compact.each { |child| normalize_an_plus_b(child) }
end

def extract_an_plus_b_value(selector_list_node)
  return nil unless selector_list_node.children.size == 1

  seq = selector_list_node.children.first
  return nil unless seq.type == :simple_selector_sequence && seq.children.size == 1

  type_sel = seq.children.first
  return nil unless type_sel.type == :type_selector

  value = type_sel.value
  value if value =~ AN_PLUS_B_REGEX
end

def next_token
  return [false, nil] if @index >= @tokens.size

  token_type, token_value, token_position = @tokens[@index]
  @index += 1
  @current_position = token_position

  [token_type, token_value]
end

def on_error(token_id, val, vstack)
  token_name = token_to_str(token_id) || '?'
  pos = @current_position || { line: '?', column: '?' }
  raise "Parse error: unexpected #{token_name} '#{val}' at #{pos[:line]}:#{pos[:column]}"
end
