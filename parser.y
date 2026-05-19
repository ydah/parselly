class Parselly::Parser
  expect 0
  error_on_expect_mismatch
  token IDENT STRING BAD_STRING NUMBER OF
        HASH DOT STAR
        LBRACKET RBRACKET
        LPAREN RPAREN
        COLON COMMA
        CHILD ADJACENT SIBLING DESCENDANT COLUMN
        EQUAL INCLUDES DASHMATCH
        PREFIXMATCH SUFFIXMATCH SUBSTRINGMATCH
        MINUS PIPE

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
        result = Node.new(:selector_list, nil, val[0].position)
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
      { result = Node.new(:child_combinator, '>', token_position(val[0])) }
    | ADJACENT
      { result = Node.new(:adjacent_combinator, '+', token_position(val[0])) }
    | SIBLING
      { result = Node.new(:sibling_combinator, '~', token_position(val[0])) }
    | DESCENDANT
      { result = Node.new(:descendant_combinator, ' ', token_position(val[0])) }
    | COLUMN
      { result = Node.new(:column_combinator, '||', token_position(val[0])) }
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
      { result = Node.new(:type_selector, token_value(val[0]), token_position(val[0]), raw_value: token_raw(val[0])) }
    | STAR
      { result = Node.new(:universal_selector, '*', token_position(val[0])) }
    | IDENT PIPE IDENT
      {
        result = Node.new(
          :type_selector,
          token_value(val[2]),
          token_position(val[0]),
          raw_value: "#{token_raw(val[0])}|#{token_raw(val[2])}",
          namespace: token_value(val[0])
        )
      }
    | STAR PIPE IDENT
      {
        result = Node.new(
          :type_selector,
          token_value(val[2]),
          token_position(val[0]),
          raw_value: "*|#{token_raw(val[2])}",
          namespace: '*'
        )
      }
    | PIPE IDENT
      {
        result = Node.new(
          :type_selector,
          token_value(val[1]),
          token_position(val[0]),
          raw_value: "|#{token_raw(val[1])}",
          namespace: ''
        )
      }
    | IDENT PIPE STAR
      {
        result = Node.new(
          :universal_selector,
          '*',
          token_position(val[0]),
          raw_value: "#{token_raw(val[0])}|*",
          namespace: token_value(val[0])
        )
      }
    | STAR PIPE STAR
      {
        result = Node.new(
          :universal_selector,
          '*',
          token_position(val[0]),
          raw_value: '*|*',
          namespace: '*'
        )
      }
    | PIPE STAR
      {
        result = Node.new(
          :universal_selector,
          '*',
          token_position(val[0]),
          raw_value: '|*',
          namespace: ''
        )
      }
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
      { result = Node.new(:id_selector, token_value(val[1]), token_position(val[0]), raw_value: token_raw(val[1])) }
    ;

  class_selector
    : DOT IDENT
      { result = Node.new(:class_selector, token_value(val[1]), token_position(val[0]), raw_value: token_raw(val[1])) }
    ;

  attribute_selector
    : LBRACKET attribute_name RBRACKET
      {
        result = Node.new(
          :attribute_selector,
          val[1].value,
          token_position(val[0]),
          raw_value: val[1].raw_value,
          namespace: val[1].namespace
        )
      }
    | LBRACKET attribute_name attr_matcher attribute_value attr_modifier RBRACKET
      {
        result = Node.new(:attribute_selector, nil, token_position(val[0]), modifier: val[4])
        result.add_child(val[1])
        result.add_child(val[2])
        result.add_child(val[3])
      }
    ;

  attribute_name
    : IDENT
      {
        result = Node.new(:attribute, token_value(val[0]), token_position(val[0]), raw_value: token_raw(val[0]))
      }
    | IDENT PIPE IDENT
      {
        result = Node.new(
          :attribute,
          token_value(val[2]),
          token_position(val[0]),
          raw_value: "#{token_raw(val[0])}|#{token_raw(val[2])}",
          namespace: token_value(val[0])
        )
      }
    | STAR PIPE IDENT
      {
        result = Node.new(
          :attribute,
          token_value(val[2]),
          token_position(val[0]),
          raw_value: "*|#{token_raw(val[2])}",
          namespace: '*'
        )
      }
    | PIPE IDENT
      {
        result = Node.new(
          :attribute,
          token_value(val[1]),
          token_position(val[0]),
          raw_value: "|#{token_raw(val[1])}",
          namespace: ''
        )
      }
    ;

  attr_matcher
    : EQUAL
      { result = Node.new(:equal_operator, '=', token_position(val[0])) }
    | INCLUDES
      { result = Node.new(:includes_operator, '~=', token_position(val[0])) }
    | DASHMATCH
      { result = Node.new(:dashmatch_operator, '|=', token_position(val[0])) }
    | PREFIXMATCH
      { result = Node.new(:prefixmatch_operator, '^=', token_position(val[0])) }
    | SUFFIXMATCH
      { result = Node.new(:suffixmatch_operator, '$=', token_position(val[0])) }
    | SUBSTRINGMATCH
      { result = Node.new(:substringmatch_operator, '*=', token_position(val[0])) }
    ;

  attribute_value
    : STRING
      { result = Node.new(:value, token_value(val[0]), token_position(val[0]), raw_value: token_raw(val[0]), quote: token_quote(val[0])) }
    | IDENT
      { result = Node.new(:value, token_value(val[0]), token_position(val[0]), raw_value: token_raw(val[0])) }
    | NUMBER
      { result = Node.new(:value, token_value(val[0]), token_position(val[0]), raw_value: token_raw(val[0])) }
    ;

  attr_modifier
    :
      { result = nil }
    | IDENT
      { result = attribute_modifier_value(val[0]) }
    ;

  pseudo_class_selector
    : COLON IDENT
      {
        name = token_value(val[1])
        node_type = LEGACY_PSEUDO_ELEMENT_NAMES.include?(pseudo_name(name)) ? :pseudo_element : :pseudo_class
        result = Node.new(node_type, name, token_position(val[0]), raw_value: token_raw(val[1]), prefix: ':')
      }
    | COLON IDENT LPAREN any_value RPAREN
      {
        fn = Node.new(:pseudo_function, token_value(val[1]), token_position(val[0]), raw_value: token_raw(val[1]), prefix: ':')
        fn.add_child(normalize_pseudo_argument(fn.value, val[3]))
        result = fn
      }
    ;

  pseudo_element_selector
    : COLON COLON IDENT
      { result = Node.new(:pseudo_element, token_value(val[2]), token_position(val[0]), raw_value: token_raw(val[2]), prefix: '::') }
    | COLON COLON IDENT LPAREN any_value RPAREN
      {
        fn = Node.new(:pseudo_element_function, token_value(val[2]), token_position(val[0]), raw_value: token_raw(val[2]), prefix: '::')
        fn.add_child(val[4])
        result = fn
      }
    ;

  any_value
    : nth_of_value
      { result = val[0] }
    | STRING
      { result = Node.new(:argument, token_value(val[0]), token_position(val[0]), raw_value: token_raw(val[0]), quote: token_quote(val[0])) }
    | an_plus_b
      { result = val[0] }
    | relative_selector_list
      { result = val[0] }
    ;

  nth_of_value
    : nth_of_an_plus_b OF relative_selector_list
      {
        result = Node.new(:nth_selector_argument, nil, val[0].position)
        result.add_child(val[0])
        result.add_child(val[2])
      }
    ;

  nth_of_an_plus_b
    : an_plus_b
      { result = val[0] }
    | IDENT
      {
        value = token_value(val[0])
        unless value =~ AN_PLUS_B_REGEX
          raise Parselly::SyntaxError, parse_error("Parse error: invalid An+B value '#{value}'", token_position(val[0]))
        end

        result = Node.new(:an_plus_b, value, token_position(val[0]), raw_value: token_raw(val[0]))
      }
    ;

  an_plus_b
    # Positive coefficient cases
    : NUMBER IDENT ADJACENT NUMBER
      {
        # Handle 'An+B' like '2n+1'
        result = Node.new(:an_plus_b, "#{token_value(val[0])}#{token_value(val[1])}+#{token_value(val[3])}", token_position(val[0]))
      }
    | NUMBER IDENT MINUS NUMBER
      {
        # Handle 'An-B' like '2n-1'
        result = Node.new(:an_plus_b, "#{token_value(val[0])}#{token_value(val[1])}-#{token_value(val[3])}", token_position(val[0]))
      }
    | NUMBER IDENT
      {
        # Handle 'An' like '2n' or composite like '2n-1' (when '-1' is part of IDENT)
        result = Node.new(:an_plus_b, "#{token_value(val[0])}#{token_value(val[1])}", token_position(val[0]))
      }
    | IDENT ADJACENT NUMBER
      {
        # Handle 'n+B' like 'n+5' or keywords followed by offset (rare but valid)
        result = Node.new(:an_plus_b, "#{token_value(val[0])}+#{token_value(val[2])}", token_position(val[0]))
      }
    | IDENT MINUS NUMBER
      {
        # Handle 'n-B' like 'n-3'
        result = Node.new(:an_plus_b, "#{token_value(val[0])}-#{token_value(val[2])}", token_position(val[0]))
      }
    # Negative coefficient cases
    | MINUS NUMBER IDENT ADJACENT NUMBER
      {
        # Handle '-An+B' like '-2n+1'
        result = Node.new(:an_plus_b, "-#{token_value(val[1])}#{token_value(val[2])}+#{token_value(val[4])}", token_position(val[0]))
      }
    | MINUS NUMBER IDENT MINUS NUMBER
      {
        # Handle '-An-B' like '-2n-1'
        result = Node.new(:an_plus_b, "-#{token_value(val[1])}#{token_value(val[2])}-#{token_value(val[4])}", token_position(val[0]))
      }
    | MINUS NUMBER IDENT
      {
        # Handle '-An' like '-2n' or composite like '-2n+1' (when '+1' is part of IDENT)
        result = Node.new(:an_plus_b, "-#{token_value(val[1])}#{token_value(val[2])}", token_position(val[0]))
      }
    | MINUS IDENT ADJACENT NUMBER
      {
        # Handle '-n+B' like '-n+3'
        result = Node.new(:an_plus_b, "-#{token_value(val[1])}+#{token_value(val[3])}", token_position(val[0]))
      }
    | MINUS IDENT MINUS NUMBER
      {
        # Handle '-n-B' like '-n-2'
        result = Node.new(:an_plus_b, "-#{token_value(val[1])}-#{token_value(val[3])}", token_position(val[0]))
      }
    | MINUS IDENT
      {
        # Handle '-n' or composite like '-n+3' (when '+3' is part of IDENT)
        result = Node.new(:an_plus_b, "-#{token_value(val[1])}", token_position(val[0]))
      }
    # Simple cases
    | NUMBER
      {
        # Handle just a number like '3'
        result = Node.new(:an_plus_b, token_value(val[0]).to_s, token_position(val[0]))
      }
    ;

  relative_selector_list
    : relative_selector (COMMA relative_selector)*
      {
        result = Node.new(:selector_list, nil, val[0].position)
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

# Pre-computed sets for faster lookup
CAN_END_COMPOUND = Set[:IDENT, :STAR, :RPAREN, :RBRACKET, :NUMBER].freeze
CAN_START_COMPOUND = Set[:IDENT, :STAR, :DOT, :HASH, :LBRACKET, :COLON].freeze
NTH_PSEUDO_NAMES = Set['nth-child', 'nth-last-child', 'nth-of-type', 'nth-last-of-type', 'nth-col', 'nth-last-col'].freeze
AN_PLUS_B_REGEX = /^(even|odd|[+-]?\d*n(?:[+-]\d+)?|[+-]?n(?:[+-]\d+)?|\d+)$/i.freeze
SELECTOR_LIST_PSEUDO_NAMES = Set['is', 'where', 'not'].freeze
RELATIVE_SELECTOR_LIST_PSEUDO_NAMES = Set['has'].freeze
LEGACY_PSEUDO_ELEMENT_NAMES = Set['before', 'after', 'first-line', 'first-letter'].freeze
ATTRIBUTE_MODIFIERS = Set['i', 's'].freeze

---- inner
def parse(input, tolerant: false, max_length: nil, max_tokens: nil, max_depth: nil, freeze: false)
  @tolerant = tolerant
  @errors = []
  @error_index = nil
  @suppress_errors = false
  @max_depth = max_depth
  @freeze_tree = freeze

  unless input.is_a?(String)
    error = parse_error('Input must be a String', { line: 1, column: 1, offset: 0 })
    return Parselly::ParseResult.new(nil, [error]) if tolerant

    raise Parselly::ParseError, error
  end

  if max_length && input.length > max_length
    error = parse_error("Input exceeds max_length #{max_length}", { line: 1, column: 1, offset: 0 })
    return Parselly::ParseResult.new(nil, [error]) if tolerant

    raise Parselly::ParseError, error
  end

  @lexer = Parselly::Lexer.new(input)
  begin
    @tokens = @lexer.tokenize
  rescue Parselly::ParseError, RuntimeError => e
    if tolerant
      @errors << parse_error_from_exception(e)
      return Parselly::ParseResult.new(nil, @errors)
    end
    raise
  end

  if max_tokens && @tokens.size > max_tokens
    error = parse_error("Input exceeds max_tokens #{max_tokens}", @tokens[max_tokens][2])
    return Parselly::ParseResult.new(nil, [error]) if tolerant

    raise Parselly::ParseError, error
  end

  preprocess_tokens!
  @index = 0
  @current_position = { line: 1, column: 1, offset: 0 }

  if tolerant
    ast = parse_with_recovery
    ast = validate_or_recover_tolerant_ast(ast) if ast
    ast.freeze_tree if ast && @freeze_tree
    return Parselly::ParseResult.new(ast, @errors)
  end

  ast = do_parse
  finalize_ast(ast)
  ast.freeze_tree if @freeze_tree
  ast
end

def parse_with_recovery
  do_parse
rescue Parselly::ParseError, RuntimeError
  parse_selector_list_recovery || parse_partial_ast
end

def validate_or_recover_tolerant_ast(ast)
  finalize_ast(ast)
  ast
rescue Parselly::ParseError => e
  @errors << parse_error_from_exception(e)
  parse_selector_list_recovery(validate: true) || ast
end

def parse_selector_list_recovery(validate: false)
  return nil unless @tokens && @tokens.any? { |token| token[0] == :COMMA }

  eof_token = @tokens.last if @tokens.last && @tokens.last[0] == false
  body_tokens = eof_token ? @tokens[0...-1] : @tokens
  segments = []
  current = []

  body_tokens.each do |token|
    if token[0] == :COMMA
      segments << current
      current = []
    else
      current << token
    end
  end
  segments << current

  result = Node.new(:selector_list, nil, body_tokens.first&.[](2) || { line: 1, column: 1, offset: 0 })
  recovered = false

  segments.each do |segment|
    next if segment.empty?

    begin
      parsed = parse_from_tokens(segment + [eof_token || [false, nil, segment.last[2]]], suppress_errors: true)
      finalize_ast(parsed) if validate
      result.add_child(parsed)
      recovered = true
    rescue Parselly::ParseError, RuntimeError
      next
    end
  end

  recovered ? result : nil
end

def parse_partial_ast
  return nil unless @tokens && !@tokens.empty?

  eof_token = @tokens.last if @tokens.last && @tokens.last[0] == false
  tokens = @tokens.dup
  tokens.pop if eof_token
  limit = @error_index || tokens.length

  while limit > 0
    truncated = tokens[0...limit]
    truncated << eof_token if eof_token
    begin
      return parse_from_tokens(truncated, suppress_errors: true)
    rescue Parselly::ParseError, RuntimeError
      limit -= 1
    end
  end
  nil
end

def parse_from_tokens(tokens, suppress_errors: false)
  @tokens = tokens
  @index = 0
  @current_position = { line: 1, column: 1, offset: 0 }
  @suppress_errors = suppress_errors
  do_parse
ensure
  @suppress_errors = false
end

def parse_error_from_exception(error)
  return error.error if error.respond_to?(:error)

  line = nil
  column = nil
  offset = nil
  if error.message =~ /at (\d+):(\d+)/
    line = Regexp.last_match(1).to_i
    column = Regexp.last_match(2).to_i
  end
  if error.message =~ /offset (\d+)/
    offset = Regexp.last_match(1).to_i
  end
  { message: error.message, line: line, column: column, offset: offset }
end

def parse_error(message, position)
  {
    message: message,
    line: position[:line],
    column: position[:column],
    offset: position[:offset]
  }.tap do |error|
    error[:end_line] = position[:end_line] if position.key?(:end_line)
    error[:end_column] = position[:end_column] if position.key?(:end_column)
    error[:end_offset] = position[:end_offset] if position.key?(:end_offset)
  end
end

def token_value(token)
  token.respond_to?(:value) ? token.value : token
end

def token_raw(token)
  token.respond_to?(:raw) ? token.raw : token_value(token)
end

def token_position(token)
  token.respond_to?(:position) && token.position ? token.position : @current_position
end

def token_quote(token)
  token.respond_to?(:quote) ? token.quote : nil
end

def pseudo_name(name)
  name.to_s.downcase
end

def attribute_modifier_value(token)
  modifier = token_value(token).to_s
  normalized_modifier = modifier.downcase
  return normalized_modifier if ATTRIBUTE_MODIFIERS.include?(normalized_modifier)

  raise_syntax_error("Parse error: invalid attribute modifier '#{modifier}'", token_position(token))
end

def raise_syntax_error(message, position)
  error = parse_error(message, position)
  if @tolerant
    @errors << error unless @suppress_errors
    @error_index ||= [@index - 1, 0].max
  end
  raise Parselly::SyntaxError, error
end

def preprocess_tokens!
  return if @tokens.size <= 1

  mark_nth_of_tokens!

  new_tokens = Array.new(@tokens.size + (@tokens.size / 2)) # Pre-allocate with conservative estimate
  new_tokens_idx = 0

  last_idx = @tokens.size - 1
  @tokens.each_with_index do |token, i|
    new_tokens[new_tokens_idx] = token
    new_tokens_idx += 1

    if i < last_idx
      next_token = @tokens[i + 1]
      if needs_descendant?(token, next_token)
        pos = next_token[2]
        new_tokens[new_tokens_idx] = [:DESCENDANT, ' ', pos]
        new_tokens_idx += 1
      end
    end
  end

  @tokens = new_tokens.first(new_tokens_idx)
end

def mark_nth_of_tokens!
  paren_depth = 0
  last_idx = @tokens.size - 1

  @tokens.each_with_index do |token, index|
    case token[0]
    when :LPAREN
      paren_depth += 1
    when :RPAREN
      paren_depth -= 1 if paren_depth.positive?
    when :IDENT
      next unless paren_depth.positive?
      next unless token_value(token[1]) == 'of'
      next if index.zero? || index >= last_idx

      previous_token = @tokens[index - 1]
      next_token = @tokens[index + 1]
      if token_gap?(previous_token, token) && token_gap?(token, next_token) &&
         CAN_START_COMPOUND.include?(next_token[0])
        token[0] = :OF
      end
    end
  end
end

# Insert DESCENDANT combinator only when actual ignored input
# (CSS whitespace or comments) separated two compound selector tokens.
def needs_descendant?(current, next_tok)
  current_type = current[0]
  next_type = next_tok[0]

  CAN_END_COMPOUND.include?(current_type) &&
    CAN_START_COMPOUND.include?(next_type) &&
    token_gap?(current, next_tok)
end

def token_gap?(current, next_tok)
  current_end = current[2][:end_offset] || current[2][:offset]
  next_tok[2][:offset] > current_end
end

def finalize_ast(node)
  validate_known_pseudo_functions!(node)
  validate_max_depth!(node) if @max_depth
end

def validate_known_pseudo_functions!(node)
  return unless node.respond_to?(:children) && node.children

  if node.type == :pseudo_function
    name = pseudo_name(node.value)
    validate_nth_pseudo!(node) if NTH_PSEUDO_NAMES.include?(name)
    validate_selector_list_pseudo!(node) if SELECTOR_LIST_PSEUDO_NAMES.include?(name)
    validate_relative_selector_list_pseudo!(node) if RELATIVE_SELECTOR_LIST_PSEUDO_NAMES.include?(name)
  end

  node.children.compact.each { |child| validate_known_pseudo_functions!(child) }
end

def validate_nth_pseudo!(node)
  child = node.children.first
  return if child&.type == :an_plus_b
  return if child&.type == :nth_selector_argument

  raise Parselly::SyntaxError, parse_error(
    "Parse error: invalid argument for :#{node.value}()",
    child&.position || node.position
  )
end

def validate_selector_list_pseudo!(node)
  child = node.children.first
  return if child&.type == :selector_list && !relative_selector_list?(child)

  raise Parselly::SyntaxError, parse_error(
    "Parse error: invalid argument for :#{node.value}()",
    child&.position || node.position
  )
end

def validate_relative_selector_list_pseudo!(node)
  child = node.children.first
  return if child&.type == :selector_list

  raise Parselly::SyntaxError, parse_error(
    "Parse error: invalid argument for :#{node.value}()",
    child&.position || node.position
  )
end

def relative_selector_list?(node)
  node.type == :selector_list &&
    node.children.any? { |child| relative_selector?(child) }
end

def relative_selector?(node)
  node.type == :selector && node.children.first &&
    node.children.first.type.to_s.end_with?('_combinator')
end

def validate_max_depth!(node)
  stack = [[node, 1]]

  until stack.empty?
    current, depth = stack.pop
    if depth > @max_depth
      raise Parselly::ParseError, parse_error(
        "Input exceeds max_depth #{@max_depth}",
        current.position
      )
    end
    current.children.each { |child| stack << [child, depth + 1] }
  end
end

def normalize_pseudo_argument(name, argument)
  return argument unless NTH_PSEUDO_NAMES.include?(pseudo_name(name))
  return argument unless argument&.type == :selector_list

  an_plus_b_value = extract_an_plus_b_value(argument)
  return argument unless an_plus_b_value

  Node.new(:an_plus_b, an_plus_b_value, argument.position, raw_value: an_plus_b_value)
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

  [token_type, parser_token_value(token_value, token_position)]
end

def parser_token_value(value, position)
  if value.respond_to?(:position)
    value.position ||= position if value.respond_to?(:position=)
    return value
  end

  Parselly::Lexer::TokenValue.new(value: value, raw: value, position: position)
end

def on_error(token_id, val, vstack)
  token_name = token_to_str(token_id) || '?'
  pos = @current_position || { line: '?', column: '?' }
  raise_syntax_error("Parse error: unexpected #{token_name} '#{token_value(val)}' at #{pos[:line]}:#{pos[:column]}", pos)
end
