class Parselly::Parser
  expect 0
  error_on_expect_mismatch

  token COMMA PLUS GREATER TILDE SPACE HASH DOT LBRACKET RBRACKET COLON COLONCOLON IDENT STRING NUM NOT FUNCTION PIPE STAR EQUAL INCLUDES DASHMATCH PREFIXMATCH SUFFIXMATCH SUBSTRINGMATCH LPAREN RPAREN DASH

  precedence left COMMA
  precedence left PLUS GREATER TILDE SPACE
  precedence left HASH DOT LBRACKET COLON COLONCOLON
rule
  selectors_group
    : selector
    | selectors_group COMMA selector
    ;

  selector
    : simple_selector_sequence
    | selector combinator simple_selector_sequence
    ;

  combinator
    : PLUS
    | GREATER
    | TILDE
    | SPACE
    ;

  simple_selector_sequence
    : type_or_universal optional_modifiers
    | required_modifiers
    ;

  type_or_universal
    : type_selector
    | universal
    ;

  optional_modifiers
    : /* empty */
    | optional_modifiers modifier
    ;

  required_modifiers
    : modifier
    | required_modifiers modifier
    ;

  modifier
    : HASH
    | class
    | attrib
    | pseudo
    | negation
    ;

  type_selector
    : IDENT PIPE IDENT
    | STAR PIPE IDENT
    | IDENT
    ;

  universal
    : IDENT PIPE STAR
    | STAR PIPE STAR
    | STAR
    ;

  class
    : DOT IDENT
    ;

  attrib
    : LBRACKET IDENT attrib_operator attrib_value RBRACKET
    | LBRACKET IDENT RBRACKET
    | LBRACKET IDENT PIPE IDENT attrib_operator attrib_value RBRACKET
    | LBRACKET STAR PIPE IDENT RBRACKET
    ;

  attrib_operator
    : EQUAL
    | INCLUDES
    | DASHMATCH
    | PREFIXMATCH
    | SUFFIXMATCH
    | SUBSTRINGMATCH
    ;

  attrib_value
    : IDENT
    | STRING
    ;

  pseudo
    : COLON COLON IDENT
    | COLON IDENT
    | COLON functional_pseudo
    ;

  functional_pseudo
    : FUNCTION expression RPAREN
    ;

  expression
    : term
    | expression SPACE term
    ;

  term
    : PLUS
    | DASH
    | NUM
    | NUM IDENT
    | STRING
    | IDENT
    ;

  negation
    : NOT negation_arg RPAREN
    ;

  negation_arg
    : type_selector
    | universal
    | HASH
    | class
    | attrib
    | pseudo
    ;
end

---- inner

def parse
  @lexer = Parselly::Lexer.new(@grammar_file)
  @ast = Parselly::AST.new
  do_parse
  @ast
end

def next_token
  @lexer.next_token
end
