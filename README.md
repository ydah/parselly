# Parselly [![Gem Version](https://badge.fury.io/rb/parselly.svg)](https://badge.fury.io/rb/parselly) [![CI](https://github.com/ydah/parselly/actions/workflows/test.yml/badge.svg)](https://github.com/ydah/parselly/actions/workflows/test.yml)

Pure Ruby CSS selector parser.

## Installation

```ruby
gem 'parselly'
```

```bash
bundle install
```

Or install it directly:

```bash
gem install parselly
```

Requires Ruby 2.7 or newer.

## Usage

```ruby
require 'parselly'

ast = Parselly.parse('article#main.content[data-state="open"] > a:hover')

ast.ids
#=> ["main"]

ast.attributes
#=> [{ name: "data-state", operator: "=", value: "open" }]

ast.pseudo_class_names
#=> ["hover"]

ast.specificity
#=> [1, 3, 2]
```

Strict parsing raises `Parselly::LexError` or `Parselly::SyntaxError` for invalid selectors:

```ruby
Parselly.parse('div >')
```

Use tolerant mode when you want a `Parselly::ParseResult` instead:

```ruby
result = Parselly.parse('div >', tolerant: true)

result.success?
#=> false

result.errors.first[:message]
#=> "Parse error: unexpected $end '' at 1:6"
```

Use `Parselly.sanitize` to escape text for a CSS identifier:

```ruby
Parselly.sanitize('1st item')
#=> "\\31 st\\ item"
```

## Development

```bash
bin/setup
bundle exec rake
```

## License

MIT
